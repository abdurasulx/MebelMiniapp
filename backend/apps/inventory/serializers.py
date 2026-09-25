from decimal import Decimal

from rest_framework import serializers

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
    PurchaseOrderItem,
    Supplier,
    Warehouse,
)


class WarehouseSerializer(serializers.ModelSerializer):
    kind_display = serializers.CharField(source="get_kind_display", read_only=True)

    class Meta:
        model = Warehouse
        fields = (
            "id", "company", "name", "kind", "kind_display",
            "address", "is_active", "created_at",
        )
        read_only_fields = ("id", "company", "created_at")


class SupplierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Supplier
        fields = ("id", "company", "name", "phone", "address", "note", "is_active", "created_at")
        read_only_fields = ("id", "company", "created_at")


class MaterialSerializer(serializers.ModelSerializer):
    unit_display = serializers.CharField(source="get_unit_display", read_only=True)
    dimension_type_display = serializers.CharField(source="get_dimension_type_display", read_only=True)
    default_supplier_name = serializers.CharField(source="default_supplier.name", read_only=True, default=None)

    class Meta:
        model = Material
        fields = (
            "id", "company", "name", "unit", "unit_display", "unit_cost", "image",
            "dimension_type", "dimension_type_display",
            "stock_unit_length", "min_stock", "default_supplier", "default_supplier_name",
            "is_active", "created_at",
        )
        read_only_fields = ("id", "company", "created_at")

    def validate(self, attrs):
        if self.instance is None and not attrs.get("image"):
            raise serializers.ValidationError({"image": "Xom ashyo rasmi majburiy"})
        return attrs


class MaterialStockSerializer(serializers.ModelSerializer):
    material_name = serializers.CharField(source="material.name", read_only=True)
    material_unit = serializers.CharField(source="material.get_unit_display", read_only=True)
    material_unit_cost = serializers.DecimalField(
        source="material.unit_cost", max_digits=14, decimal_places=2, read_only=True
    )

    class Meta:
        model = MaterialStock
        fields = ("id", "warehouse", "material", "material_name", "material_unit", "material_unit_cost", "quantity")
        read_only_fields = fields


class MaterialMovementSerializer(serializers.ModelSerializer):
    material_name = serializers.CharField(source="material.name", read_only=True)
    movement_type_display = serializers.CharField(source="get_movement_type_display", read_only=True)
    created_by_name = serializers.CharField(source="created_by.first_name", read_only=True, default=None)

    class Meta:
        model = MaterialMovement
        fields = (
            "id", "warehouse", "material", "material_name", "movement_type", "movement_type_display",
            "quantity", "note", "created_by_name", "created_at",
        )
        read_only_fields = ("id", "warehouse", "created_at")


class BillOfMaterialSerializer(serializers.ModelSerializer):
    material_name = serializers.CharField(source="material.name", read_only=True)
    material_unit = serializers.CharField(source="material.get_unit_display", read_only=True)
    material_unit_cost = serializers.DecimalField(
        source="material.unit_cost", max_digits=14, decimal_places=2, read_only=True
    )

    class Meta:
        model = BillOfMaterial
        fields = (
            "id", "product", "material", "material_name", "material_unit",
            "material_unit_cost", "quantity_per_unit", "cut_length", "cut_width",
            "part_name",
        )
        read_only_fields = ("id", "product")

    def validate(self, attrs):
        material = attrs.get("material") or getattr(self.instance, "material", None)
        cut_length = attrs.get("cut_length", getattr(self.instance, "cut_length", None))
        cut_width = attrs.get("cut_width", getattr(self.instance, "cut_width", None))
        if cut_width and not cut_length:
            raise serializers.ValidationError("cut_width faqat cut_length bilan birga beriladi")
        if cut_width:
            if not material or material.dimension_type != Material.DimensionType.SHEET:
                raise serializers.ValidationError(
                    "cut_width faqat 'varaq' turidagi material uchun qo'llaniladi"
                )
        elif cut_length:
            if not material or material.dimension_type != Material.DimensionType.LINEAR or not material.stock_unit_length:
                raise serializers.ValidationError(
                    "cut_length (cut_width'siz) faqat 'chiziqli' turidagi va stock_unit_length "
                    "belgilangan material uchun qo'llaniladi"
                )
        return attrs


class MaterialRemnantSerializer(serializers.ModelSerializer):
    material_name = serializers.CharField(source="material.name", read_only=True)
    material_unit = serializers.CharField(source="material.get_unit_display", read_only=True)

    class Meta:
        model = MaterialRemnant
        fields = (
            "id", "warehouse", "material", "material_name", "material_unit",
            "length", "width", "quantity",
        )
        read_only_fields = fields


class ReceiveRemnantSerializer(serializers.Serializer):
    """`/warehouses/<pk>/material-remnants/receive/` — VARAQ (yoki oldindan
    kesilgan CHIZIQLI) bo'lakni to'g'ridan-to'g'ri omborga kirim qilish
    uchun kirish ma'lumoti. Varaq materiallarda standart o'lcham yo'q,
    shuning uchun har bir partiya o'z eni/bo'yi bilan shu yerda kiritiladi."""

    material = serializers.UUIDField()
    length = serializers.DecimalField(max_digits=10, decimal_places=3, min_value=Decimal("0.001"))
    width = serializers.DecimalField(
        max_digits=10, decimal_places=3, min_value=Decimal("0.001"), required=False, allow_null=True
    )
    quantity = serializers.IntegerField(min_value=1)


class ManufacturedUnitSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    variant_name = serializers.CharField(source="variant.name", read_only=True, default=None)
    warehouse_name = serializers.CharField(source="warehouse.name", read_only=True, default=None)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    total_cost = serializers.DecimalField(max_digits=14, decimal_places=2, read_only=True)
    profit = serializers.SerializerMethodField()

    class Meta:
        model = ManufacturedUnit
        fields = (
            "id", "serial_number", "product", "product_name", "variant", "variant_name",
            "warehouse", "warehouse_name", "material_cost", "labor_cost", "total_cost",
            "status", "status_display", "sale_price", "profit", "order", "sold_at", "created_at",
        )
        read_only_fields = fields

    def get_profit(self, obj):
        return obj.profit


class ProduceSerializer(serializers.Serializer):
    """`/warehouses/<finished_warehouse>/produce/` uchun kirish ma'lumoti."""

    product = serializers.UUIDField()
    variant = serializers.UUIDField(required=False, allow_null=True)
    quantity = serializers.IntegerField(min_value=1)
    material_warehouse = serializers.UUIDField()


class SellUnitsSerializer(serializers.Serializer):
    """`/products/<product_pk>/sell-units/` uchun kirish ma'lumoti."""

    quantity = serializers.IntegerField(min_value=1)
    sale_price_per_unit = serializers.DecimalField(max_digits=14, decimal_places=2, min_value=0)
    order = serializers.UUIDField(required=False, allow_null=True)


class ProductStockSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    variant_name = serializers.CharField(source="variant.name", read_only=True, default=None)

    class Meta:
        model = ProductStock
        fields = ("id", "warehouse", "product", "product_name", "variant", "variant_name", "quantity")
        read_only_fields = fields


class ProductMovementSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    variant_name = serializers.CharField(source="variant.name", read_only=True, default=None)
    movement_type_display = serializers.CharField(source="get_movement_type_display", read_only=True)
    created_by_name = serializers.CharField(source="created_by.first_name", read_only=True, default=None)

    class Meta:
        model = ProductMovement
        fields = (
            "id", "warehouse", "product", "product_name", "variant", "variant_name",
            "movement_type", "movement_type_display", "quantity", "note", "created_by_name", "created_at",
        )
        read_only_fields = ("id", "warehouse", "created_at")


class PurchaseOrderItemSerializer(serializers.ModelSerializer):
    material_name = serializers.CharField(source="material.name", read_only=True)
    material_unit = serializers.CharField(source="material.get_unit_display", read_only=True)

    class Meta:
        model = PurchaseOrderItem
        fields = ("id", "material", "material_name", "material_unit", "quantity", "unit_cost")
        read_only_fields = ("id",)


class PurchaseOrderSerializer(serializers.ModelSerializer):
    supplier_name = serializers.CharField(source="supplier.name", read_only=True)
    warehouse_name = serializers.CharField(source="warehouse.name", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    created_by_name = serializers.CharField(source="created_by.first_name", read_only=True, default=None)
    total_cost = serializers.DecimalField(max_digits=16, decimal_places=2, read_only=True)
    items = PurchaseOrderItemSerializer(many=True)

    class Meta:
        model = PurchaseOrder
        fields = (
            "id", "company", "supplier", "supplier_name", "warehouse", "warehouse_name",
            "status", "status_display", "note", "items", "total_cost",
            "created_by_name", "received_at", "created_at",
        )
        read_only_fields = ("id", "company", "status", "received_at", "created_at")

    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("Kamida bitta band bo'lishi kerak")
        return value

    def create(self, validated_data):
        items_data = validated_data.pop("items")
        order = PurchaseOrder.objects.create(**validated_data)
        for item in items_data:
            PurchaseOrderItem.objects.create(purchase_order=order, **item)
        return order
