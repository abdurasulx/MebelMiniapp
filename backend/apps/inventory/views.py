from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.views import user_company
from apps.orders.models import Order
from apps.products.models import Product, Variant
from apps.products.views import can_manage
from apps.workflow.models import WorkflowStep

from .models import (
    BillOfMaterial,
    ManufacturedUnit,
    Material,
    MaterialMovement,
    MaterialStock,
    ProductMovement,
    ProductStock,
    Warehouse,
)
from .serializers import (
    BillOfMaterialSerializer,
    ManufacturedUnitSerializer,
    MaterialMovementSerializer,
    MaterialSerializer,
    MaterialStockSerializer,
    ProduceSerializer,
    ProductMovementSerializer,
    ProductStockSerializer,
    SellUnitsSerializer,
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


class ProductNestedMixin:
    """`/products/<product_pk>/...` ostidagi endpointlar uchun umumiy."""

    def _get_product(self):
        try:
            product = Product.objects.select_related("company").get(
                pk=self.kwargs["product_pk"], is_deleted=False
            )
        except Product.DoesNotExist:
            raise NotFound("Mahsulot topilmadi")
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product


class BillOfMaterialViewSet(ProductNestedMixin, viewsets.ModelViewSet):
    """Mahsulotning retsepti — 1 dona ishlab chiqarish uchun qancha xom ashyo
    kerakligi (`/products/<product_pk>/bill-of-materials/`)."""

    serializer_class = BillOfMaterialSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return BillOfMaterial.objects.filter(
            product_id=self.kwargs["product_pk"], is_deleted=False
        ).select_related("material")

    def perform_create(self, serializer):
        product = self._get_product()
        material = serializer.validated_data["material"]
        if material.company_id != product.company_id:
            raise ValidationError("Bu material sizning kompaniyangizga tegishli emas")
        serializer.save(product=product)

    def perform_update(self, serializer):
        self._get_product()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_product()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ManufacturedUnitViewSet(ProductNestedMixin, viewsets.ReadOnlyModelViewSet):
    """Mahsulotning ishlab chiqarilgan har bir donasi — faqat ko'rish; yozuvlar
    faqat `ProduceView`/`SellUnitsView` orqali yaratiladi/o'zgartiriladi."""

    serializer_class = ManufacturedUnitSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        self._get_product()
        qs = ManufacturedUnit.objects.filter(
            product_id=self.kwargs["product_pk"], is_deleted=False
        ).select_related("variant", "warehouse")
        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs


class ProduceView(WarehouseNestedMixin, APIView):
    """`/warehouses/<finished_warehouse_pk>/produce/` — mahsulot retsepti
    (BillOfMaterial) bo'yicha xom ashyoni kamaytirib, N dona yangi
    ManufacturedUnit yaratadi (har birining haqiqiy tannarxi bilan)."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, warehouse_pk):
        finished_warehouse = self._get_warehouse(Warehouse.Kind.FINISHED_GOODS)
        serializer = ProduceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            product = Product.objects.get(
                pk=data["product"], company=finished_warehouse.company, is_deleted=False
            )
        except Product.DoesNotExist:
            raise ValidationError("Bu mahsulot sizning kompaniyangizga tegishli emas")

        variant = None
        if data.get("variant"):
            try:
                variant = Variant.objects.get(pk=data["variant"], product=product, is_deleted=False)
            except Variant.DoesNotExist:
                raise ValidationError("Bu variant tanlangan mahsulotga tegishli emas")

        try:
            material_warehouse = Warehouse.objects.get(
                pk=data["material_warehouse"], company=finished_warehouse.company,
                kind=Warehouse.Kind.RAW_MATERIAL, is_deleted=False,
            )
        except Warehouse.DoesNotExist:
            raise ValidationError("Xom ashyo ombori topilmadi")

        quantity = data["quantity"]
        bom_lines = list(BillOfMaterial.objects.filter(product=product, is_deleted=False).select_related("material"))
        if not bom_lines:
            raise ValidationError(
                "Bu mahsulot uchun retsept (Bill of Materials) hali belgilanmagan"
            )

        labor_cost_per_unit = WorkflowStep.objects.filter(
            product=product, is_deleted=False
        ).aggregate(total=Sum("cost"))["total"] or Decimal("0")

        with transaction.atomic():
            material_cost_per_unit = Decimal("0")
            stocks_to_update = []
            for line in bom_lines:
                needed = line.quantity_per_unit * quantity
                stock, _ = MaterialStock.objects.select_for_update().get_or_create(
                    warehouse=material_warehouse, material=line.material
                )
                if stock.quantity < needed:
                    raise ValidationError(
                        f"'{line.material.name}' yetarli emas (mavjud: {stock.quantity}, "
                        f"kerak: {needed} {line.material.unit})"
                    )
                stock.quantity -= needed
                stocks_to_update.append((stock, line, needed))
                material_cost_per_unit += line.quantity_per_unit * line.material.unit_cost

            for stock, line, needed in stocks_to_update:
                stock.save(update_fields=["quantity"])
                MaterialMovement.objects.create(
                    warehouse=material_warehouse, material=line.material,
                    movement_type=MaterialMovement.Type.OUT, quantity=needed,
                    note=f"Ishlab chiqarish: {product.name_uz} x{quantity}",
                    created_by=request.user,
                )

            # bulk_create Model.save()ni chaqirmaydi, shuning uchun serial_number
            # (odatda save()da avtomatik generatsiya qilinadi) INSERT'dan OLDIN
            # qo'lda to'ldiriladi — aks holda hammasi bo'sh qatorni yozishga
            # urinib, unique cheklovga urilib IntegrityError beradi.
            new_units = []
            for _ in range(quantity):
                new_units.append(ManufacturedUnit(
                    product=product, variant=variant, warehouse=finished_warehouse,
                    material_cost=material_cost_per_unit, labor_cost=labor_cost_per_unit,
                    serial_number=ManufacturedUnit._generate_serial_number(),
                ))
            units = ManufacturedUnit.objects.bulk_create(new_units)

            product_stock, _ = ProductStock.objects.select_for_update().get_or_create(
                warehouse=finished_warehouse, product=product, variant=variant
            )
            product_stock.quantity += quantity
            product_stock.save(update_fields=["quantity"])
            ProductMovement.objects.create(
                warehouse=finished_warehouse, product=product, variant=variant,
                movement_type=ProductMovement.Type.IN, quantity=quantity,
                note=f"Ishlab chiqarildi ({material_warehouse.name}dan xom ashyo sarflandi)",
                created_by=request.user,
            )

        return Response(
            ManufacturedUnitSerializer(units, many=True).data, status=status.HTTP_201_CREATED
        )


class SellUnitsView(ProductNestedMixin, APIView):
    """`/products/<product_pk>/sell-units/` — eng eski (FIFO) N ta omordagi
    donani sotilgan deb belgilaydi, har birining haqiqiy sof foydasi
    (sale_price - shu dona tannarxi) hisoblanadi."""

    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, product_pk):
        product = self._get_product()
        serializer = SellUnitsSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        order = None
        if data.get("order"):
            try:
                order = Order.objects.get(pk=data["order"], company=product.company, is_deleted=False)
            except Order.DoesNotExist:
                raise ValidationError("Bu buyurtma sizning kompaniyangizga tegishli emas")

        with transaction.atomic():
            units = list(
                ManufacturedUnit.objects.select_for_update()
                .filter(product=product, status=ManufacturedUnit.Status.IN_STOCK, is_deleted=False)
                .order_by("created_at")[: data["quantity"]]
            )
            if len(units) < data["quantity"]:
                raise ValidationError(
                    f"Omborda yetarli tayyor mahsulot yo'q (mavjud: {len(units)}, so'ralgan: {data['quantity']})"
                )

            now = timezone.now()
            for unit in units:
                unit.status = ManufacturedUnit.Status.SOLD
                unit.sale_price = data["sale_price_per_unit"]
                unit.sold_at = now
                unit.order = order
                unit.save(update_fields=["status", "sale_price", "sold_at", "order"])

            # Bir nechta ombordan sotilgan bo'lishi mumkin (variant/vaqt farqi bilan
            # kelgan donalar) — har ombor uchun alohida qoldiqni kamaytiramiz.
            by_warehouse = {}
            for unit in units:
                if unit.warehouse_id:
                    by_warehouse.setdefault((unit.warehouse_id, unit.variant_id), []).append(unit)
            for (warehouse_id, variant_id), unit_list in by_warehouse.items():
                stock = ProductStock.objects.select_for_update().filter(
                    warehouse_id=warehouse_id, product=product, variant_id=variant_id
                ).first()
                if stock:
                    stock.quantity = max(Decimal("0"), stock.quantity - len(unit_list))
                    stock.save(update_fields=["quantity"])
                    ProductMovement.objects.create(
                        warehouse_id=warehouse_id, product=product, variant_id=variant_id,
                        movement_type=ProductMovement.Type.OUT, quantity=len(unit_list),
                        note="Sotildi", created_by=request.user,
                    )

        total_profit = sum((u.profit or Decimal("0")) for u in units)
        return Response({
            "units": ManufacturedUnitSerializer(units, many=True).data,
            "total_profit": total_profit,
        })


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
