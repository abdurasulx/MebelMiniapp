import json
import uuid
from decimal import Decimal, InvalidOperation

from django.contrib.auth import get_user_model
from django.db.models import Max
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company, user_has_position
from apps.inventory.models import Material
from apps.orders.models import Order, OrderItem
from apps.products.models import Product, Variant
from apps.workflow.bazis_import import parse_bazis_project
from apps.workflow.models import Stage, WorkType

from .models import Design, DesignVersion
from .serializers import (
    CreateCustomOrderOnSiteSerializer,
    DesignSerializer,
    DesignVersionSerializer,
)
from .services import (
    approve_design_version,
    bazis_groups_from_summary,
    create_custom_order_on_site,
    GUEST_EMAIL_DOMAIN,
    extra_job_work_type_name,
    get_or_create_custom_item_placeholder,
    get_or_create_guest_customer,
    normalize_uz_phone,
    set_item_cost,
)


class CustomOrderCreateView(APIView):
    """Usta mijoz uyida turib to'g'ridan-to'g'ri individual (CUSTOM_PROJECT)
    buyurtma yaratadi — alohida "joy o'rganish" tayinlash bosqichi endi
    yo'q (qarang services.create_custom_order_on_site). Faqat usta yoki
    firma egasi chaqira oladi."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        company = user_company(request.user)
        if company is None:
            raise PermissionDenied("Siz hech qanday firmaga tegishli emassiz")
        if not (is_company_owner(request.user, company) or user_has_position(request.user, company, "usta")):
            raise PermissionDenied("Faqat usta yoki firma egasi individual loyiha buyurtmasini yarata oladi")

        serializer = CreateCustomOrderOnSiteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        resolved_items = []
        for raw in data["items"]:
            variant = None
            if raw.get("product"):
                product = Product.objects.filter(id=raw["product"], company=company, is_deleted=False).first()
                if product is None:
                    raise ValidationError("Mahsulot topilmadi")
                if raw.get("variant"):
                    variant = Variant.objects.filter(id=raw["variant"], product=product, is_deleted=False).first()
                    if variant is None:
                        raise ValidationError("Variant topilmadi")
            else:
                # Katalogga mos kelmaydigan, usta erkin nom kiritgan band —
                # qarang get_or_create_custom_item_placeholder.
                product = get_or_create_custom_item_placeholder(company)
            resolved_items.append({**raw, "product": product, "variant": variant})

        order = create_custom_order_on_site(
            company=company,
            customer=serializer._customer or get_or_create_guest_customer(
                serializer._guest_phone, data.get("customer_name", "")
            ),
            items=resolved_items,
            created_by=request.user,
            address=data.get("address", ""),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
            is_mock=data.get("is_mock", False),
        )
        from apps.orders.serializers import OrderSerializer

        return Response(OrderSerializer(order, context={"request": request}).data, status=201)


def _require_order_creator(request):
    """`CustomOrderCreateView` bilan bir xil ruxsat tekshiruvi (usta yoki
    firma egasi) — Bazis fayl bilan bog'liq ikkala view ham shu."""
    company = user_company(request.user)
    if company is None:
        raise PermissionDenied("Siz hech qanday firmaga tegishli emassiz")
    if not (is_company_owner(request.user, company) or user_has_position(request.user, company, "usta")):
        raise PermissionDenied("Faqat usta yoki firma egasi Bazis faylini ishlata oladi")
    return company


class LinkCustomerView(APIView):
    """Vaqtincha (topilmagan telefon bo'yicha ochilgan) mijozga tegishli
    individual buyurtmani haqiqiy foydalanuvchi profiliga bog'laydi —
    `POST /custom-orders/<order_id>/link-customer/` {customer_worker_id}
    (qidiruvchi ID yoki telefon). Faqat hali vaqtincha hisobda turgan
    buyurtma bog'lanadi: haqiqiy mijozning buyurtmasi adashib boshqaga
    o'tib ketmasligi uchun."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, order_id):
        company = _require_order_creator(request)
        order = Order.objects.filter(
            id=order_id, company=company, order_type=Order.OrderType.CUSTOM_PROJECT, is_deleted=False
        ).select_related("customer").first()
        if order is None:
            raise ValidationError("Buyurtma topilmadi")
        if not order.customer.email.endswith(f"@{GUEST_EMAIL_DOMAIN}"):
            raise ValidationError("Bu buyurtma allaqachon haqiqiy mijozga bog'langan")

        value = str(request.data.get("customer_worker_id") or "").strip()
        phone = normalize_uz_phone(value)
        User = get_user_model()
        user = (
            User.objects.filter(worker_id=value).first()
            or User.objects.filter(phone__in=[value, phone or value]).exclude(phone="").first()
        )
        if user is None or user.id == order.customer_id:
            raise ValidationError("Bu qidiruvchi ID yoki telefon raqami bo'yicha boshqa foydalanuvchi topilmadi")
        if user.email.endswith(f"@{GUEST_EMAIL_DOMAIN}"):
            raise ValidationError("Bu ham hali ro'yxatdan o'tmagan vaqtincha mijoz")
        order.customer = user
        order.save(update_fields=["customer"])
        return Response({"customer_name": user.display_name})


def _parse_bazis_upload(upload):
    raw = upload.read()
    try:
        parsed = parse_bazis_project(raw)
    except Exception:
        raise ValidationError(
            "Faylni o'qib bo'lmadi — bu Bazis'dan eksport qilingan to'g'ri .project fayli ekanini tekshiring"
        )
    upload.seek(0)
    summary = {
        "product_name": parsed.product_name,
        "parts_count": len(parsed.parts),
        "sheet_usage": dict(parsed.sheet_usage),
        "band_usage": dict(parsed.band_usage),
        "hole_groups": dict(parsed.hole_groups),
    }
    return parsed, summary


def _load_json(raw):
    if not raw:
        return None
    try:
        return json.loads(raw)
    except (TypeError, ValueError):
        return None


def _parse_person(entry, company):
    """`{"employee_id": ...}` YOKI `{"role": ...}` — mas'ul shaxs (aniq
    xodim yoki ochiq rol). Noto'g'ri qiymat -> None (jim tashlanadi)."""
    if not isinstance(entry, dict):
        return None
    employee_id = entry.get("employee_id")
    role = entry.get("role")
    if employee_id:
        if _is_uuid(employee_id) and Employee.objects.filter(
            id=employee_id, company=company, is_active=True
        ).exists():
            return {"employee_id": str(employee_id)}
        return None
    if role in {c[0] for c in Employee.Position.choices}:
        return {"role": role}
    return None


def _parse_assignments(raw_assignments, company):
    """`assignments` (JSON matn, `{"cutting": {"employee_id": "<uuid>"} yoki
    {"role": "usta"}, "edge_processing": {...}, "other": {...}}`) — Bazis
    etaplariga (Kesish/Kromkalash/Teshish) KIM bajarishini oldindan
    belgilaydi. Noto'g'ri/bo'sh qiymatlar jim tashlab yuboriladi — bu
    ixtiyoriy maydon, kiritilmasa bosqichlar oddiy ochiq (rolsiz) qoladi va
    keyin "Ishlab chiqarish" sahifasida qo'lda biriktiriladi."""
    raw = _load_json(raw_assignments)
    if not isinstance(raw, dict):
        return {}
    result = {}
    for stage_key in (str(Stage.CUTTING), str(Stage.EDGE_PROCESSING), str(Stage.OTHER)):
        person = _parse_person(raw.get(stage_key), company)
        if person:
            result[stage_key] = person
    return result


def _parse_material_map(raw_map, company):
    """`{"Bazis material nomi": "<Material uuid>"}` — faqat shu firmaning
    o'chirilmagan materiallari qabul qilinadi."""
    raw = _load_json(raw_map)
    if not isinstance(raw, dict):
        return {}
    wanted = {str(v) for v in raw.values() if v}
    valid = {
        str(pk)
        for pk in Material.objects.filter(
            company=company, is_deleted=False, id__in=[v for v in wanted if _is_uuid(v)]
        ).values_list("id", flat=True)
    }
    return {str(name): str(mid) for name, mid in raw.items() if str(mid) in valid}


def _is_uuid(value):
    try:
        uuid.UUID(str(value))
        return True
    except ValueError:
        return False


def _decimal_or(value, default):
    try:
        d = Decimal(str(value))
    except (InvalidOperation, TypeError):
        return default
    return d if d >= 0 else default


def _parse_extra_stages(raw_stages, company):
    """Usta qo'lda qo'shgan qo'shimcha etaplar — har biri nom, mas'ul shaxs
    va ishlar ro'yxati (`name`, `quantity`, `price`). Nomsiz etap/ish jim
    tashlanadi."""
    raw = _load_json(raw_stages)
    if not isinstance(raw, list):
        return []
    result = []
    for stage in raw[:30]:
        if not isinstance(stage, dict):
            continue
        name = str(stage.get("name") or "").strip()[:100]
        if not name:
            continue
        jobs = []
        for job in (stage.get("jobs") or [])[:50]:
            if not isinstance(job, dict):
                continue
            job_name = str(job.get("name") or "").strip()[:100]
            if not job_name:
                continue
            quantity = _decimal_or(job.get("quantity"), Decimal("1"))
            if quantity <= 0:
                quantity = Decimal("1")
            jobs.append(
                {
                    "name": job_name,
                    "quantity": str(quantity),
                    "price": str(_decimal_or(job.get("price"), Decimal("0"))),
                }
            )
        entry = {"name": name, "jobs": jobs}
        entry.update(_parse_person(stage, company) or {})
        result.append(entry)
    return result


class BazisPreviewView(APIView):
    """Buyurtma HALI yaratilmasdan oldin (yaratish formasining o'zida)
    Bazis faylini ko'rib chiqish uchun — `POST /custom-orders/parse-bazis/`.
    Hech narsa saqlamaydi, faqat kesish/kromkalash/teshish guruhlarini va
    ularning joriy narxini (agar "Ish turlari" katalogida allaqachon
    mavjud bo'lsa) qaytaradi — admin shu yerning o'zida narx ko'rib/
    belgilab, keyin buyurtma bilan birga yuboradi (qarang
    DesignBazisImportView'ning `prices` parametri)."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        company = _require_order_creator(request)
        upload = request.FILES.get("file")
        if not upload:
            raise ValidationError("Fayl yuborilmadi")
        parsed, summary = _parse_bazis_upload(upload)

        groups = []
        for name, stage, work_type_name, unit, quantity in bazis_groups_from_summary(summary):
            work_type = WorkType.objects.filter(company=company, name=work_type_name).first()
            groups.append(
                {
                    "name": name,
                    "stage": stage,
                    "quantity": quantity,
                    "unit": unit,
                    "price_per_unit": str(work_type.price_per_unit) if work_type else "0",
                }
            )

        # Xom ashyo: Bazis'dagi varaq (DSP/DVP) va kromka nomlari — har biri
        # uchun firma omboridagi materialni tanlash mumkin. Nomi aynan mos
        # kelgan mavjud material (katta-kichik harfga bog'liq emas) taklif
        # sifatida qaytariladi.
        materials = []
        for kind, usage in (("sheet", summary["sheet_usage"]), ("band", summary["band_usage"])):
            for name, quantity in usage.items():
                match = Material.objects.filter(company=company, is_deleted=False, name__iexact=name).first()
                materials.append(
                    {
                        "name": name,
                        "kind": kind,
                        "quantity": quantity,
                        "suggested_material_id": str(match.id) if match else None,
                    }
                )

        return Response(
            {
                "product_name": parsed.product_name,
                "parts_count": len(parsed.parts),
                "holes_total": sum(parsed.hole_groups.values()),
                "groups": groups,
                "materials": materials,
            },
            status=200,
        )


class DesignBazisImportView(APIView):
    """Individual loyiha buyurtmasi yaratilgach (odatda darhol, xuddi shu
    ekranda) Bazis (mebel CAD) eksport faylini shu buyurtmaning dizayniga
    biriktiradi — `POST /custom-orders/<order_id>/import-bazis/`.

    Ixtiyoriy `prices` maydoni (JSON matn, `{"guruh nomi": "narx", ...}`) —
    `BazisPreviewView`da ko'rsatilgan guruhlarga admin shu yerda belgilagan
    narxlarni darhol `WorkType` katalogiga yozadi (guruh `prices`da yo'q
    yoki narxi bo'sh bo'lsa — WorkType baribir yaratiladi, lekin narxi 0
    holida qoladi, ya'ni "pulsiz" — keyinroq ham "Ish turlari" bo'limidan
    belgilash mumkin).

    Fayl darhol topshiriq yaratmaydi (buyurtma hali DESIGNING holatida,
    dizayn versiyasi tasdiqlanishi kerak) — faqat parslangan natija
    `Design.bazis_summary`ga keshlanadi. Buyurtma `IN_PRODUCTION`ga
    o'tganda, `create_workflow_instances_from_design` shu ma'lumotdan
    detal/teshik darajasidagi haqiqiy topshiriqlarni yaratadi (qarang
    apps.orders.views — set_status)."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, order_id):
        company = _require_order_creator(request)

        order = Order.objects.filter(id=order_id, company=company, is_deleted=False).select_related(
            "custom_design"
        ).first()
        if order is None:
            raise ValidationError("Buyurtma topilmadi")
        design = getattr(order, "custom_design", None)
        if design is None:
            raise ValidationError("Bu buyurtma individual loyiha emas")

        upload = request.FILES.get("file")
        if not upload:
            raise ValidationError("Fayl yuborilmadi")
        parsed, summary = _parse_bazis_upload(upload)

        design.bazis_file = upload
        design.bazis_summary = summary
        design.bazis_assignments = _parse_assignments(request.data.get("assignments"), company)
        design.material_map = _parse_material_map(request.data.get("material_map"), company)
        design.extra_stages = _parse_extra_stages(request.data.get("extra_stages"), company)
        design.save(
            update_fields=[
                "bazis_file", "bazis_summary", "bazis_assignments", "material_map", "extra_stages",
            ]
        )

        raw_prices = request.data.get("prices")
        prices = {}
        if raw_prices:
            try:
                prices = json.loads(raw_prices)
            except (TypeError, ValueError):
                prices = {}
        for name, stage, work_type_name, unit, _quantity in bazis_groups_from_summary(summary):
            work_type, _created = WorkType.objects.get_or_create(
                company=company, name=work_type_name, defaults={"unit": unit, "stage": stage, "is_auto": True}
            )
            price = prices.get(name)
            if price not in (None, ""):
                try:
                    work_type.price_per_unit = Decimal(str(price))
                    work_type.save(update_fields=["price_per_unit"])
                except (InvalidOperation, TypeError):
                    pass

        # Qo'shimcha etaplardagi ishlar ham xuddi Bazis guruhlari kabi WorkType
        # katalogiga tushadi (narxi shu yerda belgilanadi) — ish haqi shundan
        # hisoblanadi.
        for stage in design.extra_stages:
            for job in stage["jobs"]:
                work_type, _created = WorkType.objects.get_or_create(
                    company=company, name=extra_job_work_type_name(stage["name"], job["name"]),
                    defaults={"unit": "dona", "stage": Stage.OTHER, "is_auto": True},
                )
                work_type.price_per_unit = Decimal(job["price"])
                work_type.save(update_fields=["price_per_unit"])

        return Response(
            {
                "product_name": parsed.product_name,
                "parts_count": len(parsed.parts),
                "holes_total": sum(parsed.hole_groups.values()),
            },
            status=201,
        )


class DesignViewSet(viewsets.ReadOnlyModelViewSet):
    """CUSTOM_PROJECT buyurtmaning dizayn holati — versiyalar, tasdiqlangan
    versiya. Yaratish yo'q (buyurtma yaratilganda avtomatik hosil bo'ladi,
    qarang services.create_custom_order_on_site)."""

    serializer_class = DesignSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Design.objects.none()
        qs = Design.objects.filter(order__company=company, is_deleted=False).prefetch_related("versions")
        order_id = self.request.query_params.get("order")
        if order_id:
            qs = qs.filter(order_id=order_id)
        return qs

    def _check_designer_or_owner(self, company):
        user = self.request.user
        if is_company_owner(user, company):
            return
        if not user_has_position(user, company, "dizayner"):
            raise PermissionDenied("Faqat dizayner yoki firma egasi loyiha versiyasi yuklay oladi")

    @action(detail=True, methods=["post"])
    def versions(self, request, pk=None):
        """Yangi dizayn versiyasi qo'shadi (eski versiya o'chirilmaydi,
        docs §5.1). 3D fayl alohida `/models3d/` emas, shu yerda to'g'ridan-
        to'g'ri biriktiriladi (`glb_file`/`usdz_file`)."""
        design = self.get_object()
        company = design.order.company
        self._check_designer_or_owner(company)

        employee = Employee.objects.filter(company=company, user=request.user, is_deleted=False).first()
        next_number = (design.versions.aggregate(m=Max("version_number"))["m"] or 0) + 1
        version = DesignVersion.objects.create(
            design=design, version_number=next_number,
            notes=request.data.get("notes", ""), created_by=employee,
        )

        glb_file = request.FILES.get("glb_file")
        usdz_file = request.FILES.get("usdz_file")
        if glb_file or usdz_file:
            from apps.assets.models import Model3D

            Model3D.objects.create(
                design_version=version, glb_file=glb_file, usdz_file=usdz_file,
            ).recompute_status()

        return Response(DesignVersionSerializer(version, context={"request": request}).data, status=201)

    @action(detail=True, methods=["patch"], url_path="production-sequence")
    def production_sequence(self, request, pk=None):
        design = self.get_object()
        company = design.order.company
        self._check_designer_or_owner(company)
        sequence = request.data.get("production_sequence")
        if not isinstance(sequence, list):
            raise ValidationError("production_sequence ro'yxat bo'lishi kerak")
        design.production_sequence = sequence
        design.save(update_fields=["production_sequence"])
        return Response(DesignSerializer(design, context={"request": request}).data)


class DesignVersionViewSet(viewsets.GenericViewSet):
    """Faqat `approve` amali uchun — versiyalar o'zi `DesignViewSet.versions`
    orqali yaratiladi/ko'riladi."""

    serializer_class = DesignVersionSerializer
    permission_classes = (permissions.IsAuthenticated,)
    queryset = DesignVersion.objects.all()

    @action(detail=True, methods=["post"])
    def approve(self, request, pk=None):
        version = self.get_object()
        company = version.design.order.company
        user = request.user
        if not is_company_owner(user, company) and user.role != "platform_admin":
            raise PermissionDenied("Faqat firma egasi/menejer loyihani tasdiqlaydi")
        approve_design_version(design_version=version, approved_by=user)
        return Response(DesignSerializer(version.design, context={"request": request}).data)


class OrderItemCostViewSet(viewsets.GenericViewSet):
    """Custom-size buyurtma bandi uchun tannarxni qo'lda kiritish."""

    permission_classes = (permissions.IsAuthenticated,)
    queryset = OrderItem.objects.all()

    @action(detail=True, methods=["post"], url_path="set-cost")
    def set_cost(self, request, pk=None):
        item = self.get_object()
        company = user_company(request.user)
        if company is None or company.id != item.order.company_id or not is_company_owner(request.user, company):
            raise PermissionDenied("Faqat firma egasi tannarxni kiritadi")
        if not item.is_custom_size:
            raise ValidationError("Bu band custom-size emas")
        try:
            cost_amount = float(request.data.get("cost_amount"))
        except (TypeError, ValueError):
            raise ValidationError("cost_amount raqam bo'lishi kerak")
        if cost_amount < 0:
            raise ValidationError("cost_amount manfiy bo'lishi mumkin emas")
        set_item_cost(
            item=item, cost_amount=cost_amount, changed_by=request.user,
            reason=request.data.get("reason", ""),
        )
        from apps.orders.serializers import OrderItemSerializer

        return Response(OrderItemSerializer(item, context={"request": request}).data)
