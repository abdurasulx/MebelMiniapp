from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Model3D


class Model3DSerializer(StorageStampMixin, serializers.ModelSerializer):
    """Firma tomoni: 3D yuklash/tahrirlash + ulashish sozlamalari."""

    file_fields = ("glb_file", "usdz_file")
    glb_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    usdz_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    glb_url = serializers.SerializerMethodField()
    usdz_url = serializers.SerializerMethodField()
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    visibility_display = serializers.CharField(source="get_visibility_display", read_only=True)
    allowed_emails = serializers.ListField(
        child=serializers.EmailField(), required=False, default=list
    )

    class Meta:
        model = Model3D
        fields = (
            "id",
            "product",
            "glb_file",
            "usdz_file",
            "glb_url",
            "usdz_url",
            "status",
            "status_display",
            "scale_width",
            "scale_height",
            "scale_depth",
            "share_token",
            "visibility",
            "visibility_display",
            "allowed_emails",
            "created_at",
        )
        read_only_fields = ("id", "product", "status", "share_token", "created_at")

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))

    def save(self, **kwargs):
        instance = super().save(**kwargs)
        instance.recompute_status()
        instance.save(update_fields=["status"])
        return instance


class Model3DViewerSerializer(serializers.ModelSerializer):
    """Ochiq/cheklangan viewer sahifasi uchun — faqat ko'rish uchun kerak bo'lgan
    minimal ma'lumot (bazissoft.ru uslubidagi mustaqil 3D-havola)."""

    glb_url = serializers.SerializerMethodField()
    usdz_url = serializers.SerializerMethodField()
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    company_name = serializers.CharField(source="product.company.name", read_only=True)
    variants = serializers.SerializerMethodField()

    class Meta:
        model = Model3D
        fields = (
            "id",
            "product_name",
            "company_name",
            "variants",
            "glb_url",
            "usdz_url",
            "scale_width",
            "scale_height",
            "scale_depth",
            "visibility",
        )

    def get_variants(self, obj):
        return [
            {"id": v.id, "name": v.name, "color_hex": v.color_hex}
            for v in obj.product.variants.filter(is_deleted=False)
        ]

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))
