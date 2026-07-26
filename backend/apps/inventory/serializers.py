from rest_framework import serializers

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


class WarehouseSerializer(serializers.ModelSerializer):
    kind_display = serializers.CharField(source="get_kind_display", read_only=True)
    branch_viloyat = serializers.CharField(source="branch.get_viloyat_display", read_only=True, default=None)

    class Meta:
        model = Warehouse
        fields = (
            "id", "company", "branch", "branch_viloyat", "name", "kind", "kind_display",
            "address", "is_active", "created_at",
        )
        read_only_fields = ("id", "company", "created_at")


class MaterialSerializer(serializers.ModelSerializer):
    unit_display = serializers.CharField(source="get_unit_display", read_only=True)

    class Meta:
        model = Material
        fields = ("id", "company", "name", "unit", "unit_display", "unit_cost", "is_active", "created_at")
        read_only_fields = ("id", "company", "created_at")


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
            "material_unit_cost", "quantity_per_unit",
        )
        read_only_fields = ("id", "product")


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
