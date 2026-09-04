from django.db.models import Max
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company, user_has_position
from apps.orders.models import OrderItem
from apps.products.models import Product, Variant

from .models import Design, DesignVersion, SiteSurvey, SiteSurveyMedia
from .serializers import (
    CreateCustomOrderSerializer,
    DesignSerializer,
    DesignVersionSerializer,
    SiteSurveyMediaSerializer,
    SiteSurveySerializer,
)
from .services import approve_design_version, create_custom_order, set_item_cost


class SiteSurveyViewSet(viewsets.ModelViewSet):
    """Admin ustani mijoz uyiga tayinlaydi; usta o'z tayinlangan
    joylarini ko'radi, tashrif ma'lumotlarini kiritadi, buyurtma yaratadi."""

    serializer_class = SiteSurveySerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "patch", "head", "options")

    def get_queryset(self):
        user = self.request.user
        company = user_company(user)
        if company is None:
            return SiteSurvey.objects.none()
        qs = SiteSurvey.objects.filter(company=company, is_deleted=False).select_related(
            "assigned_master__user", "customer"
        ).prefetch_related("media")
        if is_company_owner(user, company):
            return qs
        return qs.filter(assigned_master__user=user)

    def _own_company(self):
        company = user_company(self.request.user)
        if company is None or not is_company_owner(self.request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi joy o'rganishga tayinlaydi")
        return company

    def perform_create(self, serializer):
        company = self._own_company()
        master_id = self.request.data.get("assigned_master")
        master = Employee.objects.filter(id=master_id, company=company, is_deleted=False).first()
        if master is None:
            raise ValidationError("Usta topilmadi")
        serializer.save(company=company, assigned_master=master, assigned_by=self.request.user)

    def perform_update(self, serializer):
        # Usta o'zining tayinlangan surveyini tahrirlashi mumkin (izoh/o'lcham/
        # geolokatsiya), ega esa hammasini — `get_queryset` bu ikkalasini
        # allaqachon cheklaydi.
        serializer.save()

    def _own_survey_or_owner(self, survey):
        user = self.request.user
        company = user_company(user)
        if company is None or company.id != survey.company_id:
            raise PermissionDenied("Bu joy o'rganish sizga tegishli emas")
        if is_company_owner(user, company):
            return
        if survey.assigned_master.user_id != user.id:
            raise PermissionDenied("Bu joy o'rganish sizga tayinlanmagan")

    @action(detail=True, methods=["post"])
    def media(self, request, pk=None):
        survey = self.get_object()
        self._own_survey_or_owner(survey)
        serializer = SiteSurveyMediaSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        media = SiteSurveyMedia.objects.create(survey=survey, **serializer.validated_data)
        return Response(SiteSurveyMediaSerializer(media, context={"request": request}).data, status=201)

    @action(detail=True, methods=["post"], url_path="create-order")
    def create_order(self, request, pk=None):
        survey = self.get_object()
        self._own_survey_or_owner(survey)
        if survey.order_id is not None:
            raise ValidationError("Bu joy o'rganish uchun buyurtma allaqachon yaratilgan")

        serializer = CreateCustomOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        company = survey.company
        resolved_items = []
        for raw in serializer.validated_data["items"]:
            product = Product.objects.filter(id=raw["product"], company=company, is_deleted=False).first()
            if product is None:
                raise ValidationError("Mahsulot topilmadi")
            variant = None
            if raw.get("variant"):
                variant = Variant.objects.filter(id=raw["variant"], product=product, is_deleted=False).first()
                if variant is None:
                    raise ValidationError("Variant topilmadi")
            resolved_items.append({**raw, "product": product, "variant": variant})

        order = create_custom_order(survey=survey, items=resolved_items, created_by=request.user)
        from apps.orders.serializers import OrderSerializer

        return Response(OrderSerializer(order, context={"request": request}).data, status=201)


class DesignViewSet(viewsets.ReadOnlyModelViewSet):
    """CUSTOM_PROJECT buyurtmaning dizayn holati — versiyalar, tasdiqlangan
    versiya. Yaratish yo'q (buyurtma yaratilganda avtomatik hosil bo'ladi,
    qarang services.create_custom_order)."""

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
