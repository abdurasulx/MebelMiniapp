from django.db import transaction
from rest_framework import permissions, viewsets
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError

from apps.companies.views import user_company
from apps.products.models import Product, Variant

from .models import Material, MaterialMovement, MaterialStock, ProductMovement, ProductStock, Warehouse
from .serializers import (
    MaterialMovementSerializer,
    MaterialSerializer,
    MaterialStockSerializer,
    ProductMovementSerializer,
    ProductStockSerializer,
    WarehouseSerializer,
)


class CompanyScopedViewSet(viewsets.ModelViewSet):
    """Faqat o'z kompaniyasi doirasida — egasi yoki faol xodim."""

    permission_classes = (permissions.IsAuthenticated,)

    def _own_company(self):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Faqat firma a'zolari ombor bilan ishlaydi")
        return company

    def perform_create(self, serializer):
        serializer.save(company=self._own_company())


class WarehouseViewSet(CompanyScopedViewSet):
    serializer_class = WarehouseSerializer

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Warehouse.objects.none()
        return Warehouse.objects.filter(company=company, is_deleted=False).select_related("branch")

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.is_active = False
        instance.save(update_fields=["is_deleted", "is_active"])


class MaterialViewSet(CompanyScopedViewSet):
    serializer_class = MaterialSerializer

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Material.objects.none()
        return Material.objects.filter(company=company, is_deleted=False)

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.is_active = False
        instance.save(update_fields=["is_deleted", "is_active"])


class WarehouseNestedMixin:
    """`/warehouses/<warehouse_pk>/...` ostidagi endpointlar uchun umumiy."""

    def _get_warehouse(self, expected_kind=None):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Faqat firma a'zolari ombor bilan ishlaydi")
        try:
            warehouse = Warehouse.objects.get(
                pk=self.kwargs["warehouse_pk"], company=company, is_deleted=False
            )
        except Warehouse.DoesNotExist:
            raise NotFound("Ombor topilmadi")
        if expected_kind and warehouse.kind != expected_kind:
            raise ValidationError(f"Bu amal faqat '{expected_kind}' turidagi omborlarda mumkin")
        return warehouse


class MaterialStockViewSet(WarehouseNestedMixin, viewsets.ReadOnlyModelViewSet):
    """Joriy qoldiqlar — faqat ko'rish, o'zgartirish MaterialMovement orqali."""

    serializer_class = MaterialStockSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        warehouse = self._get_warehouse(Warehouse.Kind.RAW_MATERIAL)
        return MaterialStock.objects.filter(warehouse=warehouse).select_related("material")


class MaterialMovementViewSet(WarehouseNestedMixin, viewsets.ModelViewSet):
    """Xom ashyo kirim/chiqimi — yaratilganda qoldiq (`MaterialStock`) ham
    shu bilan birga avtomatik yangilanadi."""

    serializer_class = MaterialMovementSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "head", "options")

    def get_queryset(self):
        warehouse = self._get_warehouse(Warehouse.Kind.RAW_MATERIAL)
        return MaterialMovement.objects.filter(warehouse=warehouse).select_related("material", "created_by")

    def perform_create(self, serializer):
        warehouse = self._get_warehouse(Warehouse.Kind.RAW_MATERIAL)
        material = serializer.validated_data["material"]
        if material.company_id != warehouse.company_id:
            raise ValidationError("Bu material sizning kompaniyangizga tegishli emas")

        with transaction.atomic():
            stock, _ = MaterialStock.objects.select_for_update().get_or_create(
                warehouse=warehouse, material=material
            )
            delta = serializer.validated_data["quantity"]
            if serializer.validated_data["movement_type"] == MaterialMovement.Type.OUT:
                if stock.quantity < delta:
                    raise ValidationError(
                        f"Omborda yetarli qoldiq yo'q (mavjud: {stock.quantity}, so'ralgan: {delta})"
                    )
                stock.quantity -= delta
            else:
                stock.quantity += delta
            stock.save(update_fields=["quantity"])
            serializer.save(warehouse=warehouse, created_by=self.request.user)


class ProductStockViewSet(WarehouseNestedMixin, viewsets.ReadOnlyModelViewSet):
    serializer_class = ProductStockSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        warehouse = self._get_warehouse(Warehouse.Kind.FINISHED_GOODS)
        return ProductStock.objects.filter(warehouse=warehouse).select_related("product", "variant")


class ProductMovementViewSet(WarehouseNestedMixin, viewsets.ModelViewSet):
    serializer_class = ProductMovementSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "head", "options")

    def get_queryset(self):
        warehouse = self._get_warehouse(Warehouse.Kind.FINISHED_GOODS)
        return ProductMovement.objects.filter(warehouse=warehouse).select_related("product", "variant", "created_by")

    def perform_create(self, serializer):
        warehouse = self._get_warehouse(Warehouse.Kind.FINISHED_GOODS)
        product = serializer.validated_data["product"]
        variant = serializer.validated_data.get("variant")
        if product.company_id != warehouse.company_id:
            raise ValidationError("Bu mahsulot sizning kompaniyangizga tegishli emas")
        if variant and variant.product_id != product.id:
            raise ValidationError("Bu variant tanlangan mahsulotga tegishli emas")

        with transaction.atomic():
            stock, _ = ProductStock.objects.select_for_update().get_or_create(
                warehouse=warehouse, product=product, variant=variant
            )
            delta = serializer.validated_data["quantity"]
            if serializer.validated_data["movement_type"] == ProductMovement.Type.OUT:
                if stock.quantity < delta:
                    raise ValidationError(
                        f"Omborda yetarli qoldiq yo'q (mavjud: {stock.quantity}, so'ralgan: {delta})"
                    )
                stock.quantity -= delta
            else:
                stock.quantity += delta
            stock.save(update_fields=["quantity"])
            serializer.save(warehouse=warehouse, created_by=self.request.user)
