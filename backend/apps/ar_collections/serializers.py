from rest_framework import serializers

from apps.products.serializers import ProductSerializer

from .models import ARCollection, ARCollectionItem


class ARCollectionItemSerializer(serializers.ModelSerializer):
    # To'liq mahsulot obyekti (variantlari, model3d va h.k. bilan) qaytariladi —
    # mobil klient AR uchun mos modelni tanlashda mahsulot sahifasida
    # ishlatilgan bir xil "variant.model3d status==ready bo'lsa shuni, aks
    # holda product.model3d" mantig'ini qayta ishlatadi.
    product = ProductSerializer(read_only=True)
    product_id = serializers.UUIDField(write_only=True)
    variant_id = serializers.UUIDField(source="variant.id", read_only=True, default=None)

    class Meta:
        model = ARCollectionItem
        fields = ("id", "product", "product_id", "variant", "variant_id", "created_at")
        read_only_fields = ("id", "product", "variant_id", "created_at")
        extra_kwargs = {"variant": {"write_only": True, "required": False, "allow_null": True}}


class ARCollectionSerializer(serializers.ModelSerializer):
    items = ARCollectionItemSerializer(many=True, read_only=True)
    item_count = serializers.IntegerField(source="items.count", read_only=True)

    class Meta:
        model = ARCollection
        fields = ("id", "name", "items", "item_count", "created_at")
        read_only_fields = ("id", "items", "item_count", "created_at")
