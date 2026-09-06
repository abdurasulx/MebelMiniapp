"""CUSTOM_PROJECT oqimining backend-tomon qarorlari — usta buyurtma
yaratishi, dizayn versiyasi tasdiqlanishi, ishlab chiqarish bosqichlarining
dizayner belgilagan ketma-ketlik asosida yaratilishi. READY_PRODUCT oqimi
(`apps.orders`/`apps.workflow`) bu modul tomonidan hech qanday o'zgartirilmaydi."""

from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.notifications.services import (
    notify_custom_order_location_suspicious,
    notify_pool_open,
    notify_task_assigned,
)
from apps.orders.models import Order, OrderItem
from apps.workflow.models import STAGE_POSITION, StepStatus, WorkflowStepInstance

from .models import AuditEntityType, AuditLogEntry, Design


def _log(entity_type, entity_id, action, changed_by, old_value=None, new_value=None, reason=""):
    AuditLogEntry.objects.create(
        entity_type=entity_type, entity_id=entity_id, action=action, changed_by=changed_by,
        old_value=old_value, new_value=new_value, reason=reason,
    )


@transaction.atomic
def create_custom_order_on_site(
    *, company, customer, items, created_by, address="", latitude=None, longitude=None,
    is_mock=False,
):
    """Usta mijoz uyida turib to'g'ridan-to'g'ri CUSTOM_PROJECT buyurtma
    yaratadi — oldindan alohida "joy o'rganish" (site survey) bosqichi
    endi yo'q. `items` — har biri {product, variant (ixtiyoriy), width,
    height, depth, quantity, is_custom_size} lug'ati. Bo'sh `Design`
    yozuvi ham AVTOMATIK yaratiladi — dizayner bosqichi hech qachon
    o'tkazib yuborilmaydi (docs §5).

    `is_mock` — qurilma GPS'i soxta (mock-location) deb aniqlangan bo'lsa
    `True` (qarang apps.attendance.services'dagi bir xil naqsh). Bunday
    holda ham buyurtma savdoni bloklamaslik uchun BARIBIR yaratiladi —
    faqat `Order.location_flagged` belgilanadi va firma egasiga xabar
    yuboriladi, admin har birini qo'lda tekshirishi shart emas."""
    order = Order.objects.create(
        company=company,
        customer=customer,
        order_type=Order.OrderType.CUSTOM_PROJECT,
        status=Order.Status.NEW,
        latitude=latitude,
        longitude=longitude,
        address=address,
        location_flagged=is_mock,
        location_flag_reason="Mock location aniqlangan" if is_mock else "",
    )
    total = Decimal("0")
    for item in items:
        is_custom = bool(item.get("is_custom_size"))
        variant = item.get("variant")
        unit_price = None
        subtotal = Decimal("0")
        if not is_custom and variant is not None:
            volume = item["width"] * item["height"] * item["depth"]
            unit_price = variant.effective_base_price
            subtotal = (unit_price * volume * item["quantity"]).quantize(Decimal("0.01"))
        OrderItem.objects.create(
            order=order,
            product=item["product"],
            variant=variant,
            product_name=item["product"].name_uz,
            variant_name=variant.name if variant else "",
            width=item["width"],
            height=item["height"],
            depth=item["depth"],
            quantity=item["quantity"],
            is_custom_size=is_custom,
            unit_m3_price=unit_price,
            subtotal=subtotal,
            created_by=created_by,
        )
        total += subtotal
    order.total_price = total
    order.save(update_fields=["total_price"])

    Design.objects.create(order=order)

    _log(
        AuditEntityType.ORDER_STATUS, order.id, "custom_order_created_on_site", created_by,
        new_value={"location_flagged": is_mock},
    )
    if is_mock:
        notify_custom_order_location_suspicious(order)
    return order


def set_item_cost(*, item, cost_amount, changed_by, reason=""):
    """Admin custom-size buyurtma bandi uchun tannarxni qo'lda kiritadi
    (docs §4 — avtomatik hisoblanmaydigan qatorlar)."""
    old = {"cost_amount": str(item.cost_amount) if item.cost_amount is not None else None}
    item.cost_amount = cost_amount
    item.subtotal = cost_amount * item.quantity
    item.save(update_fields=["cost_amount", "subtotal"])

    order = item.order
    visible = order.items.filter(is_deleted=False)
    order.total_price = sum((i.subtotal for i in visible), Decimal("0"))
    order.save(update_fields=["total_price"])

    _log(
        AuditEntityType.ORDER_ITEM_COST, item.id, "cost_set", changed_by,
        old_value=old, new_value={"cost_amount": str(cost_amount)}, reason=reason,
    )


def approve_design_version(*, design_version, approved_by):
    """Admin/menejer dizayn versiyasini tasdiqlaydi — shundan keyingina
    buyurtma DESIGNING'dan IN_PRODUCTION'ga o'tishi mumkin bo'ladi (docs §5.2,
    qarang apps.orders.views.OrderViewSet.set_status)."""
    design = design_version.design
    old = {"approved_version_id": str(design.approved_version_id) if design.approved_version_id else None}
    design.approved_version = design_version
    design.approved_by = approved_by
    design.approved_at = timezone.now()
    design.save(update_fields=["approved_version", "approved_by", "approved_at"])
    _log(
        AuditEntityType.DESIGN, design.id, "version_approved", approved_by,
        old_value=old, new_value={"approved_version_id": str(design_version.id)},
    )
    return design


def create_workflow_instances_from_design(order, design):
    """CUSTOM_PROJECT buyurtma IN_PRODUCTION'ga o'tganda, dizayner belgilagan
    `production_sequence` (Stage qiymatlari ro'yxati) asosida ketma-ket
    bog'langan ad-hoc `WorkflowStepInstance`lar yaratadi — mavjud
    `apps.workflow.services.create_workflow_instances`dagi shablon-nusxalash
    o'rniga (READY_PRODUCT'da ishlatiladigan yo'l, bu yerda tegilmaydi)."""
    sequence = design.production_sequence or []
    if not sequence:
        return []

    now = timezone.now()
    instances = []
    previous = None
    for index, stage in enumerate(sequence):
        instance = WorkflowStepInstance.objects.create(
            company=order.company,
            order=order,
            template_step=None,
            order_index=index,
            name=f"{order} — {stage}",
            stage=stage,
            role=STAGE_POSITION.get(stage) or "",
        )
        if previous is not None:
            instance.depends_on.set([previous])
        instances.append(instance)
        previous = instance

    first = instances[0]
    if first.is_available:
        first.status = StepStatus.IN_PROGRESS
        first.started_at = now
        first.save(update_fields=["status", "started_at"])
    if first.employee_id:
        notify_task_assigned(first)
    elif first.role:
        notify_pool_open(first)

    return instances
