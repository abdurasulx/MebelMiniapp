from django.db.models import Max
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company, user_has_position
from apps.orders.models import OrderItem
from apps.products.models import Product, Variant

from .models import Design, DesignVersion
from .serializers import (
    CreateCustomOrderOnSiteSerializer,
    DesignSerializer,
    DesignVersionSerializer,
)
from .services import approve_design_version, create_custom_order_on_site, set_item_cost


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
            product = Product.objects.filter(id=raw["product"], company=company, is_deleted=False).first()
            if product is None:
                raise ValidationError("Mahsulot topilmadi")
            variant = None
            if raw.get("variant"):
                variant = Variant.objects.filter(id=raw["variant"], product=product, is_deleted=False).first()
                if variant is None:
                    raise ValidationError("Variant topilmadi")
            resolved_items.append({**raw, "product": product, "variant": variant})

        order = create_custom_order_on_site(
            company=company,
            customer=serializer._customer,
            items=resolved_items,
            created_by=request.user,
            address=data.get("address", ""),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
            is_mock=data.get("is_mock", False),
        )
        from apps.orders.serializers import OrderSerializer

        return Response(OrderSerializer(order, context={"request": request}).data, status=201)


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
