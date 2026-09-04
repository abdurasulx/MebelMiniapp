from rest_framework import serializers

from common.serializers import visible_file_url

from .models import CartItem


class CartItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    product_image_url = serializers.SerializerMethodField()
    company = serializers.CharField(source="product.company_id", read_only=True)
    company_name = serializers.CharField(source="product.company.name", read_only=True)
    variant_name = serializers.CharField(source="variant.name", read_only=True)
    m3_price = serializers.DecimalField(
        source="variant.effective_base_price", max_digits=12, decimal_places=2, read_only=True
    )
    m3_original_price = serializers.DecimalField(
        source="variant.base_price", max_digits=12, decimal_places=2, read_only=True
    )
    discount_active = serializers.BooleanField(source="variant.discount_active", read_only=True)

    class Meta:
        model = CartItem
        fields = (
            "id",
            "product",
            "product_name",
            "product_image_url",
            "company",
            "company_name",
            "variant",
            "variant_name",
            "m3_price",
            "m3_original_price",
            "discount_active",
            "width",
            "height",
            "depth",
            "quantity",
            "created_at",
        )
        read_only_fields = ("id", "created_at")

    def get_product_image_url(self, obj):
        return visible_file_url(obj.product, "image", self.context.get("request"))
