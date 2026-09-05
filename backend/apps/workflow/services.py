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
    if steps.exclude(status__in=(StepStatus.COMPLETED, StepStatus.APPROVED)).exists():
        return
    order.status = Order.Status.READY
    order.save(update_fields=["status", "updated_at"])
    notify_order_status(order)


def consume_material_on_completion(instance, user):
    """Usta "Bajardim" bosganda — agar bosqichga xom ashyo biriktirilgan
    bo'lsa, `quantity` miqdorda ombordan AVTOMATIK ayiriladi
    (`MaterialMovement`, turi "chiqim"). Material jismonan shu daqiqada
    sarflangani uchun bu tasdiqni (`approve`) kutmaydi — ish haqi ham
    endi kutmaydi (qarang `credit_payroll`, `views.py::complete`da
    darhol chaqiriladi).

    Chaqiruvchi (`views.py::complete`) buni status COMPLETED qilib
    saqlangandan KEYIN, bitta `transaction.atomic()` bloki ichida
    chaqirishi kerak — ombordan ayirish muvaffaqiyatsiz bo'lsa (masalan
    yetarli qoldiq yo'q), butun "Bajardim" amali bekor qilinadi."""
    if not instance.raw_material_id or instance.material_consumed:
        return
    with transaction.atomic():
        _consume_material(instance, user)
        instance.material_consumed = True
        instance.save(update_fields=["material_consumed", "updated_at"])


def approve_step_and_credit_payroll(instance, approved_by):
    """Firma egasi/menejer yakunlangan bosqichni tekshirib tasdiqlaganda
    chaqiriladi — status APPROVED ga o'tadi. Ish haqi ESA endi yangilik
    emas — u allaqachon `complete()`da kreditlangan (qarang
    `credit_payroll`); shu yerdagi qayta chaqiruv shunchaki hisobni
    yangilaydi (xavfsiz takroriy chaqiruv — `recompute()` har doim
    noldan qayta hisoblaydi). Ombordan ayirish esa allaqachon "Bajardim"
    bosilganda sodir bo'lgan (qarang `consume_material_on_completion`) —
    bu yerda takrorlanmaydi."""
    with transaction.atomic():
        instance.status = StepStatus.APPROVED
        instance.approved_at = timezone.now()
        instance.approved_by = approved_by
        instance.save(update_fields=["status", "approved_at", "approved_by", "updated_at"])
        if instance.employee_id:
            credit_payroll(instance)


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


def credit_payroll(instance):
    """Xodimning shu oyidagi ish haqini (`Payslip`) qayta hisoblaydi va
    saqlaydi. Avval faqat `approve()` (firma egasi tasdiqlagach) chaqirar
    edi — endi `complete()`da HAM chaqiriladi, ya'ni usta "Bajardim"
    bosishi bilanoq bonus/vazifa haqi "kutilmoqda" summasiga qo'shiladi,
    egasi tasdiqlashini kutmaydi (`Payslip.recompute()` COMPLETED va
    APPROVED bosqichlarni bir xil hisoblaydi, qarang production/models.py)."""
    from apps.production.models import Payslip

    period = (instance.completed_at or timezone.now()).date().replace(day=1)
    payslip, _ = Payslip.objects.get_or_create(
        company_id=instance.company_id, employee_id=instance.employee_id, period=period,
    )
    _recompute_and_save(payslip)


def _recompute_and_save(payslip):
    if payslip.is_paid:
        # To'langan oylikka orqaga qarab ta'sir qilinmaydi — keyingi oyning
        # payslip'i o'z vaqtida yaratiladi/hisoblanadi.
        return
    payslip.recompute()
    payslip.save()


def cancel_step(instance, cancelled_by):
    """Firma egasi/menejer bosqichni bekor qiladi (xato tayinlash, buyurtma
    bekor bo'lishi va h.k.):
    1) agar material allaqachon ombordan ayirilgan bo'lsa (`material_consumed`)
       — teskari "qaytarish" harakati bilan ombor holatiga tiklanadi,
    2) agar bosqich tasdiqlangan (APPROVED) bo'lib, ish haqi allaqachon
       kreditlangan bo'lsa — `Payslip` qayta hisoblanib, shu bosqichning
       ulushi olib tashlanadi (chunki qayta hisoblash endi bu bosqichni
       COMPLETED/APPROVED emas, CANCELLED deb ko'radi va e'tiborga olmaydi)."""
    from rest_framework.exceptions import ValidationError

    if instance.status == StepStatus.CANCELLED:
        raise ValidationError("Bu bosqich allaqachon bekor qilingan")

    with transaction.atomic():
        if instance.material_consumed:
            _return_material(instance, cancelled_by)
        instance.status = StepStatus.CANCELLED
        instance.cancelled_at = timezone.now()
        instance.cancelled_by = cancelled_by
        instance.save(update_fields=["status", "cancelled_at", "cancelled_by", "updated_at"])
        if instance.employee_id:
            _reverse_payroll_if_credited(instance)


def _return_material(instance, user):
    from apps.inventory.models import MaterialMovement, MaterialStock

    movement = (
        MaterialMovement.objects.filter(workflow_instance=instance, movement_type=MaterialMovement.Type.OUT)
        .order_by("-created_at")
        .first()
    )
    if movement is None:
        return

    stock, _ = MaterialStock.objects.select_for_update().get_or_create(
        warehouse=movement.warehouse, material=instance.raw_material, defaults={"quantity": 0}
    )
    stock.quantity += movement.quantity
    stock.save(update_fields=["quantity"])
    MaterialMovement.objects.create(
        warehouse=movement.warehouse, material=instance.raw_material,
        movement_type=MaterialMovement.Type.RETURN, quantity=movement.quantity,
        note=f"Bekor qilindi: {instance.name}", workflow_instance=instance, created_by=user,
    )


def _reverse_payroll_if_credited(instance):
    """`credit_payroll`dan farqi — bo'sh `Payslip` yo'q joyda yangisini
    yaratmaydi (bekor qilinayotgan bosqich hech qachon yakunlanmagan
    bo'lishi mumkin, bunday holda hisoblanadigan hech narsa yo'q)."""
    from apps.production.models import Payslip

    period = (instance.completed_at or timezone.now()).date().replace(day=1)
    payslip = Payslip.objects.filter(
        company_id=instance.company_id, employee_id=instance.employee_id, period=period,
    ).first()
    if payslip is not None:
        _recompute_and_save(payslip)


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
            cut_piece_length=step.cut_piece_length,
            cut_piece_width=step.cut_piece_width,
            cut_piece_count=step.cut_piece_count,
            cut_note=step.cut_note,
            required_materials=step.required_materials,
            photo_requirement=step.photo_requirement,
            comment_requirement=step.comment_requirement,
            requires_approval=step.requires_approval,
            product=product,
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
