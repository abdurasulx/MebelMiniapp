from rest_framework import serializers

from apps.products.serializers import ProductSerializer

from .models import Like


class LikeSerializer(serializers.ModelSerializer):
    product_detail = serializers.SerializerMethodField()

    class Meta:
        model = Like
        fields = ("id", "product", "product_detail", "created_at")
        read_only_fields = ("id", "created_at")

    def get_product_detail(self, obj):
        return ProductSerializer(obj.product, context=self.context).data
