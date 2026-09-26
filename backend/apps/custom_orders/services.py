"""CUSTOM_PROJECT oqimining backend-tomon qarorlari — usta buyurtma
yaratishi, dizayn versiyasi tasdiqlanishi, ishlab chiqarish bosqichlarining
dizayner belgilagan ketma-ketlik asosida yaratilishi. READY_PRODUCT oqimi
(`apps.orders`/`apps.workflow`) bu modul tomonidan hech qanday o'zgartirilmaydi."""

import re
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from apps.companies.models import Employee
from apps.inventory.models import Material
from apps.notifications.services import (
    notify_custom_order_location_suspicious,
    notify_pool_open,
    notify_task_assigned,
)
from apps.orders.models import Order, OrderItem
from apps.products.models import Category, Product
from apps.workflow.models import STAGE_POSITION, Stage, StepStatus, WorkflowStepInstance, WorkType

from .models import AuditEntityType, AuditLogEntry, Design


def _log(entity_type, entity_id, action, changed_by, old_value=None, new_value=None, reason=""):
    AuditLogEntry.objects.create(
        entity_type=entity_type, entity_id=entity_id, action=action, changed_by=changed_by,
        old_value=old_value, new_value=new_value, reason=reason,
    )


GUEST_EMAIL_DOMAIN = "guest.local"


def normalize_uz_phone(value):
    """"+998901234567" / "998901234567" / "901234567" -> "+998901234567";
    telefon raqamiga o'xshamasa (masalan noma'lum qidiruvchi ID) — None."""
    digits = re.sub(r"\D", "", value or "")
    if len(digits) == 9:
        return f"+998{digits}"
    if len(digits) == 12 and digits.startswith("998"):
        return f"+{digits}"
    return None


def get_or_create_guest_customer(phone, name=""):
    """Tizimda hali yo'q mijoz uchun vaqtincha (parolsiz) hisob. `phone`
    OTP-kirishdagi (`OTPVerifyView`) bilan bir xil formatda saqlanadi —
    mijoz keyin shu raqam bilan SMS orqali kirsa, aynan shu hisob topiladi
    va buyurtma avtomatik o'ziga tegishli bo'lib qoladi (qo'shimcha
    bog'lash shart emas). Boshqa yo'l bilan (Google/email) ro'yxatdan
    o'tsa — `LinkCustomerView` orqali qo'lda bog'lanadi."""
    User = get_user_model()
    user = User.objects.filter(phone=phone).first()
    if user is not None:
        return user
    user = User(
        phone=phone, email=f"{phone}@{GUEST_EMAIL_DOMAIN}", role=User.Role.CUSTOMER,
        phone_verified=True, first_name=(name or "").strip()[:150],
    )
    user.set_unusable_password()
    user.save()
    return user


def get_or_create_custom_item_placeholder(company):
    """Katalogga mos kelmaydigan (usta qo'lda nom kiritgan) individual
    buyum uchun — `OrderItem.product` FK majburiy (`on_delete=PROTECT`)
    bo'lgani sabab, haqiqiy `Product` yozuvi kerak. Har firma uchun bitta
    yashirin (sotuvga chiqarilmagan) "placeholder" mahsulot bir marta
    yaratiladi va qayta ishlatiladi — ko'rinadigan nom baribir
    `OrderItem.product_name`dan olinadi (qarang create_custom_order_on_site),
    bu yozuvning o'zi hech qayerda ko'rsatilmaydi."""
    category, _ = Category.objects.get_or_create(
        slug="individual-boshqa", defaults={"name_uz": "Individual / Boshqa"}
    )
    product, _ = Product.objects.get_or_create(
        company=company, category=category, name_uz="Individual buyum (erkin nom)",
        defaults={"is_published": False, "description": "Katalogga mos kelmaydigan individual buyurtma bandlari uchun avtomatik yaratilgan yozuv."},
    )
    return product


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
            product_name=item.get("custom_name") or item["product"].name_uz,
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


def bazis_groups_from_summary(summary):
    """Parslangan Bazis xulosasidan (`sheet_usage`/`band_usage`/`hole_groups`
    — qarang `apps.workflow.bazis_import.parse_bazis_project`) kesish/
    kromkalash/teshish guruhlarini `(nomi, stage, work_type_nomi, birlik,
    miqdor)` ro'yxatiga aylantiradi — aynan `apps.workflow.views.
    WorkflowStepBazisImportView` bilan bir xil guruhlash mantig'i. Ikkala
    joyda ham (buyurtma yaratishdan oldingi ko'rib chiqish va haqiqiy
    `WorkflowStepInstance` yaratish) shu bitta funksiya ishlatiladi —
    guruh nomlari (demak, ularga bog'lanadigan `WorkType`lar ham) hech
    qachon ikki joyda farqlanib qolmasligi uchun."""
    specs = []
    for sheet_name, count in (summary.get("sheet_usage") or {}).items():
        specs.append((f"Kesish: {sheet_name}", Stage.CUTTING, f"Kesish: {sheet_name}", "dona", count))
    for band_name, count in (summary.get("band_usage") or {}).items():
        specs.append(
            (f"Kromkalash: {band_name}", Stage.EDGE_PROCESSING, f"Kromkalash: {band_name}", "dona", count)
        )
    for hole_label, count in (summary.get("hole_groups") or {}).items():
        specs.append((f"Teshish {hole_label}", Stage.OTHER, f"Teshish {hole_label}", "dona", count))
    return specs


def extra_job_work_type_name(stage_name, job_name):
    """Qo'lda qo'shilgan etap ichidagi ish uchun `WorkType` nomi."""
    return f"{stage_name}: {job_name}"


def _bazis_instance_specs(design):
    return bazis_groups_from_summary(design.bazis_summary or {})


def create_workflow_instances_from_design(order, design):
    """CUSTOM_PROJECT buyurtma IN_PRODUCTION'ga o'tganda topshiriqlar
    yaratadi — ikki manbadan biridan:

    1. **Bazis fayli biriktirilgan bo'lsa** (`design.bazis_summary`, qarang
       DesignBazisImportView): kesish/kromkalash/teshish bo'yicha DETAL
       darajasidagi aniq topshiriqlar, har biri o'z `WorkType`iga (demak,
       narx belgilansa — ish haqiga) bog'langan holda.
    2. **Aks holda** (eski xatti-harakat): dizayner qo'lda tanlagan
       `production_sequence` (Stage qiymatlari ro'yxati) asosida oddiy
       ketma-ket bosqichlar.

    Ikkalasida ham natija bir xil naqsh bilan ishlanadi — ketma-ket
    bog'langan (`depends_on`) ad-hoc `WorkflowStepInstance`lar, mavjud
    `apps.workflow.services.create_workflow_instances`dagi shablon-nusxalash
    o'rniga (READY_PRODUCT'da ishlatiladigan yo'l, bu yerda tegilmaydi)."""
    bazis_specs = _bazis_instance_specs(design) if design.bazis_summary else []

    if bazis_specs:
        # Har etap (Kesish/Kromkalash/Teshish) uchun buyurtma yaratishda (yoki
        # keyinroq "Ishlab chiqarish" sahifasida) aniq xodim YOKI ochiq rol
        # belgilangan bo'lishi mumkin (qarang views._parse_assignments); qo'lda
        # qo'shilgan etaplar o'z mas'ulini o'zida saqlaydi.
        assignments = design.bazis_assignments or {}
        extra_stages = design.extra_stages or []
        person_entries = list(assignments.values()) + [st for st in extra_stages]
        employee_ids = {e["employee_id"] for e in person_entries if e.get("employee_id")}
        employees_by_id = {
            str(e.id): e for e in Employee.objects.filter(id__in=employee_ids, company=order.company)
        } if employee_ids else {}

        # Bazis material nomi -> tanlangan ombor materiali (faqat tavsif uchun).
        materials_by_id = {
            str(m.id): m
            for m in Material.objects.filter(
                id__in=list((design.material_map or {}).values()), company=order.company
            )
        }
        summary = design.bazis_summary or {}
        group_material = {}
        for sheet_name in summary.get("sheet_usage") or {}:
            group_material[f"Kesish: {sheet_name}"] = (design.material_map or {}).get(sheet_name)
        for band_name in summary.get("band_usage") or {}:
            group_material[f"Kromkalash: {band_name}"] = (design.material_map or {}).get(band_name)

        def resolve_person(entry, default_role=""):
            employee = None
            role = default_role
            if entry.get("employee_id"):
                employee = employees_by_id.get(entry["employee_id"])
            elif entry.get("role"):
                role = entry["role"]
            return employee, role

        instances = []
        for index, (name, stage, work_type_name, unit, quantity) in enumerate(bazis_specs):
            work_type, _ = WorkType.objects.get_or_create(
                company=order.company, name=work_type_name,
                defaults={"unit": unit, "stage": stage, "is_auto": True},
            )
            employee, role = resolve_person(assignments.get(str(stage)) or {}, work_type.required_role)
            description = ""
            material = materials_by_id.get(group_material.get(name) or "")
            if material is not None:
                description = f"Xom ashyo: {material.name} ({material.unit_cost:g} so'm/{material.unit})"
            instances.append(
                WorkflowStepInstance(
                    company=order.company,
                    order=order,
                    template_step=None,
                    order_index=index,
                    name=name,
                    description=description,
                    stage=stage,
                    role=role,
                    employee=employee,
                    work_type=work_type,
                    quantity=quantity,
                    # `WorkflowStep`dan farqli, `WorkflowStepInstance.save()` cost'ni
                    # avtomatik hisoblamaydi (u boshqa maydonlar kabi YARATISH
                    # paytida muhrlanadigan snapshot) — shuning uchun bu yerda
                    # qo'lda hisoblanadi.
                    cost=Decimal(quantity) * work_type.price_per_unit,
                )
            )

        # Usta qo'lda qo'shgan qo'shimcha etaplar — Bazis bosqichlaridan keyin.
        for stage_entry in extra_stages:
            employee, role = resolve_person(stage_entry)
            for job in stage_entry["jobs"]:
                work_type, _ = WorkType.objects.get_or_create(
                    company=order.company,
                    name=extra_job_work_type_name(stage_entry["name"], job["name"]),
                    defaults={"unit": "dona", "stage": Stage.OTHER, "is_auto": True},
                )
                job_quantity = Decimal(job["quantity"])
                instances.append(
                    WorkflowStepInstance(
                        company=order.company,
                        order=order,
                        template_step=None,
                        order_index=len(instances),
                        name=f"{stage_entry['name']}: {job['name']}",
                        stage=Stage.OTHER,
                        role=role,
                        employee=employee,
                        work_type=work_type,
                        quantity=job_quantity,
                        cost=job_quantity * work_type.price_per_unit,
                    )
                )
        WorkflowStepInstance.objects.bulk_create(instances)
    else:
        sequence = design.production_sequence or []
        if not sequence:
            return []
        instances = [
            WorkflowStepInstance(
                company=order.company,
                order=order,
                template_step=None,
                order_index=index,
                name=f"{order} — {stage}",
                stage=stage,
                role=STAGE_POSITION.get(stage) or "",
            )
            for index, stage in enumerate(sequence)
        ]
        WorkflowStepInstance.objects.bulk_create(instances)

    previous = None
    for instance in instances:
        if previous is not None:
            instance.depends_on.set([previous])
        previous = instance

    now = timezone.now()
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
