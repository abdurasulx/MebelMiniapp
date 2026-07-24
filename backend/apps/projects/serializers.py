from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import DetailAsset, Project, ProjectItem


class DetailAssetSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("glb_file", "thumbnail")
    glb_file = serializers.FileField(write_only=True)
    thumbnail = serializers.ImageField(write_only=True, required=False, allow_null=True)
    glb_url = serializers.SerializerMethodField()
    thumbnail_url = serializers.SerializerMethodField()
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    is_public = serializers.SerializerMethodField()

    class Meta:
        model = DetailAsset
        fields = (
            "id", "company", "name", "category", "category_display",
            "glb_file", "glb_url", "thumbnail", "thumbnail_url", "is_public", "created_at",
        )
        read_only_fields = ("id", "company", "created_at")

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_thumbnail_url(self, obj):
        return visible_file_url(obj, "thumbnail", self.context.get("request"))

    def get_is_public(self, obj):
        return obj.company_id is None


class ProjectItemSerializer(serializers.ModelSerializer):
    """`glb_url`/`color_hex`/`texture_url` manba turidan (mahsulot yoki
    detal) qat'iy nazar bitta joydan olinadi — front qo'shimcha so'rov
    yubormasdan sahnani to'g'ridan-to'g'ri qura oladi."""

    product_name = serializers.SerializerMethodField()
    glb_url = serializers.SerializerMethodField()
    color_hex = serializers.SerializerMethodField()
    texture_url = serializers.SerializerMethodField()

    class Meta:
        model = ProjectItem
        fields = (
            "id", "source_type", "product", "variant", "detail_asset",
            "product_name", "glb_url", "color_hex", "texture_url",
            "position", "rotation", "scale", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def get_product_name(self, obj):
        if obj.source_type == ProjectItem.SourceType.PRODUCT and obj.product:
            return obj.product.name_uz
        if obj.source_type == ProjectItem.SourceType.DETAIL and obj.detail_asset:
            return obj.detail_asset.name
        return ""

    def get_glb_url(self, obj):
        request = self.context.get("request")
        if obj.source_type == ProjectItem.SourceType.PRODUCT and obj.product:
            model3d = getattr(obj.product, "model3d", None)
            if model3d:
                return visible_file_url(model3d, "glb_file", request)
            return None
        if obj.source_type == ProjectItem.SourceType.DETAIL and obj.detail_asset:
            return visible_file_url(obj.detail_asset, "glb_file", request)
        return None

    def get_color_hex(self, obj):
        return obj.variant.color_hex if obj.variant else None

    def get_texture_url(self, obj):
        if obj.variant and obj.variant.texture:
            return visible_file_url(obj.variant, "texture", self.context.get("request"))
        return None

    def validate(self, data):
        source_type = data.get("source_type", getattr(self.instance, "source_type", None))
        product = data.get("product", getattr(self.instance, "product", None))
        detail_asset = data.get("detail_asset", getattr(self.instance, "detail_asset", None))
        if source_type == ProjectItem.SourceType.PRODUCT and not product:
            raise serializers.ValidationError("source_type=product uchun 'product' majburiy")
        if source_type == ProjectItem.SourceType.DETAIL and not detail_asset:
            raise serializers.ValidationError("source_type=detail uchun 'detail_asset' majburiy")
        return data


class ProjectSerializer(serializers.ModelSerializer):
    items = ProjectItemSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source="customer.first_name", read_only=True)

    class Meta:
        model = Project
        fields = (
            "id", "customer", "customer_name", "name", "is_paid", "paid_at",
            "share_token", "is_public", "items", "created_at",
        )
        read_only_fields = ("id", "customer", "is_paid", "paid_at", "share_token", "created_at")
