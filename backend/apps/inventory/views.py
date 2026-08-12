from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company, user_has_position
from apps.orders.models import Order
from apps.products.models import Product, Variant
from apps.products.views import can_manage
from apps.workflow.models import WorkflowStep

from .models import (
    BillOfMaterial,
    ManufacturedUnit,
    Material,
    MaterialMovement,
    MaterialRemnant,
    MaterialStock,
    ProductMovement,
    ProductStock,
    PurchaseOrder,
    Supplier,
    Warehouse,
)
from .serializers import (
    BillOfMaterialSerializer,
    ManufacturedUnitSerializer,
    MaterialMovementSerializer,
    MaterialRemnantSerializer,
    MaterialSerializer,
    MaterialStockSerializer,
    ProduceSerializer,
    ProductMovementSerializer,
    ProductStockSerializer,
    PurchaseOrderSerializer,
    SellUnitsSerializer,
    SupplierSerializer,
    WarehouseSerializer,
)


def _consume_cut_pieces(warehouse, material, cut_length, total_pieces):
    """`total_pieces` dona `cut_length` uzunlikdagi bo'lak kerak bo'lganda:
    avval mos keladigan mavjud qoldiqlardan (eng kichik yetarli — best-fit)
    foydalanadi, ular tugagach yangi yaxlit birlikdan (`stock_unit_length`)
    kesadi. Har safar kesishdan qolgan musbat qoldiq alohida saqlanadi.
    Qaytaradi: yangi yaxlit birlikdan kesilgan donalar soni (audit/xarajat uchun)."""

    fresh_units_used = 0
    for _ in range(total_pieces):
        remnant = (
            MaterialRemnant.objects.select_for_update()
            .filter(warehouse=warehouse, material=material, length__gte=cut_length, quantity__gt=0)
            .order_by("length")
            .first()
        )
        if remnant is not None:
            leftover = remnant.length - cut_length
            remnant.quantity -= 1
            if remnant.quantity == 0:
                remnant.delete()
            else:
                remnant.save(update_fields=["quantity"])
        else:
            stock, _ = MaterialStock.objects.select_for_update().get_or_create(
                warehouse=warehouse, material=material
            )
            if stock.quantity < material.stock_unit_length:
                raise ValidationError(
                    f"'{material.name}' yetarli emas (mavjud: {stock.quantity}{material.unit}, "
                    f"kerak yana kamida {material.stock_unit_length}{material.unit} yaxlit birlik)"
                )
            stock.quantity -= material.stock_unit_length
            stock.save(update_fields=["quantity"])
            fresh_units_used += 1
            leftover = material.stock_unit_length - cut_length

        if leftover > 0:
            new_remnant, created = MaterialRemnant.objects.select_for_update().get_or_create(
                warehouse=warehouse, material=material, length=leftover, defaults={"quantity": 0}
            )
            new_remnant.quantity += 1
            new_remnant.save(update_fields=["quantity"])

    return fresh_units_used


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
        return Warehouse.objects.filter(company=company, is_deleted=False)

    def perform_create(self, serializer):
        company = self._own_company()
        if not is_company_owner(self.request.user, company):
            raise PermissionDenied("Faqat firma egasi yangi ombor yarata oladi")
        serializer.save(company=company)

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.is_active = False
        instance.save(update_fields=["is_deleted", "is_active"])


class SupplierViewSet(CompanyScopedViewSet):
    serializer_class = SupplierSerializer

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Supplier.objects.none()
        return Supplier.objects.filter(company=company, is_deleted=False)

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

    @action(detail=False, methods=["get"], url_path="low-stock")
    def low_stock(self, request):
        """Ta'minot: `min_stock`dan pastga tushgan materiallar — barcha
        omborlardagi joriy qoldiq yig'indisi solishtiriladi."""
        company = self._own_company()
        materials = Material.objects.filter(
            company=company, is_deleted=False, is_active=True, min_stock__gt=0
        ).select_related("default_supplier")

        results = []
        for material in materials:
            total = MaterialStock.objects.filter(material=material).aggregate(
                total=Sum("quantity")
            )["total"] or Decimal("0")
            if total < material.min_stock:
                data = MaterialSerializer(material, context={"request": request}).data
                data["current_stock"] = total
                results.append(data)
        return Response(results)


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


class MaterialRemnantViewSet(WarehouseNestedMixin, viewsets.ReadOnlyModelViewSet):
    """Qayta ishlatsa bo'ladigan kesish qoldiqlari (offcut) — faqat ko'rish,
    yozuvlar avtomatik `ProduceView` orqali yaratiladi/sarflanadi."""

    serializer_class = MaterialRemnantSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        warehouse = self._get_warehouse(Warehouse.Kind.RAW_MATERIAL)
        return MaterialRemnant.objects.filter(warehouse=warehouse, quantity__gt=0).select_related("material")


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
        if not user_has_position(self.request.user, warehouse.company, Employee.Position.OMBORCHI):
            raise PermissionDenied("Ombordagi kirim/chiqimni faqat omborchi (yoki firma egasi) boshqaradi")
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
            for line in bom_lines:
                material = line.material
                if line.cut_length:
                    # Kesish-qoldiq (offcut) rejimi: quantity_per_unit bu yerda
                    # bo'laklar SONI, uzluksiz miqdor emas.
                    raw_total_pieces = line.quantity_per_unit * quantity
                    total_pieces = int(raw_total_pieces)
                    if raw_total_pieces != total_pieces:
                        raise ValidationError(
                            f"'{material.name}' uchun kesiladigan bo'laklar soni butun son "
                            f"bo'lishi kerak (hisoblandi: {raw_total_pieces})"
                        )
                    fresh_units_used = _consume_cut_pieces(
                        material_warehouse, material, line.cut_length, total_pieces
                    )
                    if fresh_units_used:
                        MaterialMovement.objects.create(
                            warehouse=material_warehouse, material=material,
                            movement_type=MaterialMovement.Type.OUT,
                            quantity=fresh_units_used * material.stock_unit_length,
                            note=(
                                f"Ishlab chiqarish: {product.name_uz} x{quantity} — "
                                f"{total_pieces} ta {line.cut_length}{material.unit} bo'lak kesildi "
                                f"({fresh_units_used} ta yangi yaxlit birlikdan)"
                            ),
                            created_by=request.user,
                        )
                    material_cost_per_unit += line.quantity_per_unit * line.cut_length * material.unit_cost
                else:
                    needed = line.quantity_per_unit * quantity
                    stock, _ = MaterialStock.objects.select_for_update().get_or_create(
                        warehouse=material_warehouse, material=material
                    )
                    if stock.quantity < needed:
                        raise ValidationError(
                            f"'{material.name}' yetarli emas (mavjud: {stock.quantity}, "
                            f"kerak: {needed} {material.unit})"
                        )
                    stock.quantity -= needed
                    stock.save(update_fields=["quantity"])
                    MaterialMovement.objects.create(
                        warehouse=material_warehouse, material=material,
                        movement_type=MaterialMovement.Type.OUT, quantity=needed,
                        note=f"Ishlab chiqarish: {product.name_uz} x{quantity}",
                        created_by=request.user,
                    )
                    material_cost_per_unit += line.quantity_per_unit * material.unit_cost

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
        if not user_has_position(self.request.user, warehouse.company, Employee.Position.OMBORCHI):
            raise PermissionDenied("Ombordagi kirim/chiqimni faqat omborchi (yoki firma egasi) boshqaradi")
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


class PurchaseOrderViewSet(CompanyScopedViewSet):
    """Xom ashyo ta'minoti: yetkazib beruvchidan xarid buyurtmasi. Faqat
    omborchi (yoki firma egasi) yaratadi/qabul qiladi — kirim/chiqim bilan
    bir xil ruxsat qoidasi (qarang MaterialMovementViewSet)."""

    serializer_class = PurchaseOrderSerializer
    http_method_names = ("get", "post", "head", "options")

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return PurchaseOrder.objects.none()
        return PurchaseOrder.objects.filter(company=company, is_deleted=False).select_related(
            "supplier", "warehouse", "created_by"
        ).prefetch_related("items__material")

    def perform_create(self, serializer):
        company = self._own_company()
        if not user_has_position(self.request.user, company, Employee.Position.OMBORCHI):
            raise PermissionDenied("Xarid buyurtmasini faqat omborchi (yoki firma egasi) yaratadi")
        supplier = serializer.validated_data["supplier"]
        warehouse = serializer.validated_data["warehouse"]
        if supplier.company_id != company.id or warehouse.company_id != company.id:
            raise ValidationError("Yetkazib beruvchi yoki ombor sizning kompaniyangizga tegishli emas")
        if warehouse.kind != Warehouse.Kind.RAW_MATERIAL:
            raise ValidationError("Xarid buyurtmasi faqat xom ashyo omboriga qilinadi")
        serializer.save(company=company, created_by=self.request.user)

    @action(detail=True, methods=["post"])
    def receive(self, request, pk=None):
        """Buyurtmani "qabul qilindi" deb belgilaydi — har bir band tegishli
        ombor qoldig'iga avtomatik kirim qilinadi (MaterialMovement IN)."""
        order = self.get_object()
        company = self._own_company()
        if not user_has_position(request.user, company, Employee.Position.OMBORCHI):
            raise PermissionDenied("Faqat omborchi (yoki firma egasi) qabul qila oladi")
        if order.status != PurchaseOrder.Status.PENDING:
            raise ValidationError("Bu buyurtma allaqachon yakunlangan")

        with transaction.atomic():
            for item in order.items.select_related("material"):
                stock, _ = MaterialStock.objects.select_for_update().get_or_create(
                    warehouse=order.warehouse, material=item.material
                )
                stock.quantity += item.quantity
                stock.save(update_fields=["quantity"])
                MaterialMovement.objects.create(
                    warehouse=order.warehouse, material=item.material,
                    movement_type=MaterialMovement.Type.IN, quantity=item.quantity,
                    note=f"Xarid: {order.supplier.name} (buyurtma #{str(order.id)[:8]})",
                    created_by=request.user,
                )
            order.status = PurchaseOrder.Status.RECEIVED
            order.received_at = timezone.now()
            order.save(update_fields=["status", "received_at"])

        return Response(PurchaseOrderSerializer(order, context={"request": request}).data)
