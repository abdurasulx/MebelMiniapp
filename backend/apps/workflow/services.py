from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.notifications.services import notify_order_status, notify_pool_open, notify_task_assigned

from .models import StepStatus, WorkflowStepInstance


def sync_order_status_on_step_completion(order):
    """Buyurtmaning barcha workflow bosqichlari tugagach, buyurtma statusini
    qo'lda "Tayyor" deb belgilashni kutmasdan avtomatik READY holatiga
    o'tkazadi — ishlab chiqarish avtomatlashtirishning bir qismi (ombor va
    boshqa keyingi bosqichlar buyurtma real vaqtda qayerdaligini bilishi uchun)."""
    from apps.orders.models import Order

    if order.status != Order.Status.IN_PRODUCTION:
        return
    steps = order.workflow_steps.filter(is_deleted=False)
    if not steps.exists():
        return
    if steps.exclude(status=StepStatus.COMPLETED).exists():
        return
    order.status = Order.Status.READY
    order.save(update_fields=["status", "updated_at"])
    notify_order_status(order)


def consume_material_and_credit_payroll(instance, user):
    """Usta "Bajardim" bosganda BIR TRANZAKSIYADA ikkalasi ham sodir bo'ladi:
    1) agar bosqichga xom ashyo biriktirilgan bo'lsa — `quantity` miqdorda
       ombordan avtomatik ayiriladi (`MaterialMovement`, turi "chiqim"),
    2) agar bosqichga xodim biriktirilgan bo'lsa — shu oyning ish haqi
       (`Payslip`) darhol qayta hisoblanadi (avval faqat "Hisoblash"
       tugmasi bilan qo'lda qilinar edi).

    Chaqiruvchi (`views.py::complete`) buni status COMPLETED qilib
    saqlangandan KEYIN, bitta `transaction.atomic()` bloki ichida
    chaqirishi kerak — ombordan ayirish muvaffaqiyatsiz bo'lsa (masalan
    yetarli qoldiq yo'q), butun "Bajardim" amali bekor qilinadi."""
    with transaction.atomic():
        if instance.raw_material_id and not instance.material_consumed:
            _consume_material(instance, user)
            instance.material_consumed = True
            instance.save(update_fields=["material_consumed", "updated_at"])
        if instance.employee_id:
            _credit_payroll(instance)


def _consume_material(instance, user):
    from django.db.models import Sum
    from rest_framework.exceptions import ValidationError

    from apps.inventory.models import MaterialMovement, MaterialStock, Warehouse

    needed = instance.quantity
    if needed <= 0:
        return

    warehouses = list(
        Warehouse.objects.filter(
            company_id=instance.company_id, kind=Warehouse.Kind.RAW_MATERIAL,
            is_active=True, is_deleted=False,
        )
    )
    if not warehouses:
        raise ValidationError(
            f"'{instance.raw_material.name}'ni ombordan ayirib bo'lmadi — "
            "firmada xom ashyo ombori yo'q"
        )

    # Yetarli qoldig'i bor birinchi omborni tanlaymiz (odatda bittagina bo'ladi).
    stock = (
        MaterialStock.objects.filter(warehouse__in=warehouses, material=instance.raw_material)
        .select_for_update()
        .filter(quantity__gte=needed)
        .order_by("-quantity")
        .first()
    )
    if stock is None:
        total = MaterialStock.objects.filter(
            warehouse__in=warehouses, material=instance.raw_material
        ).aggregate(total=Sum("quantity"))["total"] or Decimal("0")
        raise ValidationError(
            f"'{instance.raw_material.name}' yetarli emas (mavjud: {total}, "
            f"kerak: {needed} {instance.raw_material.unit})"
        )

    stock.quantity -= needed
    stock.save(update_fields=["quantity"])
    MaterialMovement.objects.create(
        warehouse=stock.warehouse, material=instance.raw_material,
        movement_type=MaterialMovement.Type.OUT, quantity=needed,
        note=f"Ishlab chiqarish bosqichi: {instance.name}",
        workflow_instance=instance, created_by=user,
    )


def _credit_payroll(instance):
    from apps.production.models import Payslip

    period = (instance.completed_at or timezone.now()).date().replace(day=1)
    payslip, _ = Payslip.objects.get_or_create(
        company_id=instance.company_id, employee_id=instance.employee_id, period=period,
    )
    if payslip.is_paid:
        # To'langan oylikka orqaga qarab ta'sir qilinmaydi — keyingi oyning
        # payslip'i o'z vaqtida yaratiladi/hisoblanadi.
        return
    payslip.recompute()
    payslip.save()


def create_workflow_instances(order, product):
    """Mahsulotning workflow shablonini buyurtmaga nusxalaydi (Order Workflow).

    Bitta buyurtmada bir nechta mahsulot bo'lishi mumkin bo'lsa-da, MVP'da
    ishlab chiqarish jarayoni birinchi banddagi mahsulotning shabloniga
    asoslanadi (odatiy holat — buyurtma bitta mebelga tegishli).
    Bog'liqliksiz (depends_on bo'sh) bosqichlar darhol "Bajarilmoqda"
    holatida boshlanadi — qolganlari ular tugagach avtomatik ochiladi.
    """
    template_steps = list(product.workflow_steps.filter(is_deleted=False).order_by("order_index"))
    if not template_steps:
        return []

    now = timezone.now()
    instance_by_template_id = {}
    instances = []
    for step in template_steps:
        instance = WorkflowStepInstance.objects.create(
            company=order.company,
            order=order,
            template_step=step,
            order_index=step.order_index,
            name=step.name,
            role=step.role,
            employee=step.employee,
            estimated_hours=step.estimated_hours,
            work_type=step.work_type,
            quantity=step.quantity,
            cost=step.cost,
            raw_material=step.raw_material,
            required_materials=step.required_materials,
            photo_requirement=step.photo_requirement,
        )
        instance_by_template_id[step.id] = instance
        instances.append(instance)

    for step in template_steps:
        instance = instance_by_template_id[step.id]
        dep_ids = list(step.depends_on.values_list("id", flat=True))
        deps = [instance_by_template_id[d] for d in dep_ids if d in instance_by_template_id]
        if deps:
            instance.depends_on.set(deps)

    for instance in instances:
        if instance.is_available and instance.employee_id:
            # Faqat xodimi aniq biriktirilgan bosqich darhol boshlanadi —
            # xodimsiz ("erkin") bosqich PENDING qoladi va mos lavozimdagi
            # ustalar hovuzida ko'rinadi (qarang activate_if_ready izohi).
            instance.status = StepStatus.IN_PROGRESS
            instance.started_at = now
            instance.save(update_fields=["status", "started_at"])
        if instance.employee_id:
            notify_task_assigned(instance)
        elif instance.is_available:
            notify_pool_open(instance)

    return instances
