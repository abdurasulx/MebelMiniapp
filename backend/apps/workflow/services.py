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
