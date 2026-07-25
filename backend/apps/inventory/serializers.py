from rest_framework import serializers

from .models import Material, MaterialMovement, MaterialStock, ProductMovement, ProductStock, Warehouse


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
