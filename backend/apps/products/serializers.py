from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Category, Product, ProductImage, Variant


class CategorySerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("image",)
    image = serializers.ImageField(write_only=True, required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Category
        fields = ("id", "parent", "name_uz", "name_ru", "slug", "image", "image_url")
        read_only_fields = ("id", "slug")

    def get_image_url(self, obj):
        return visible_file_url(obj, "image", self.context.get("request"))


class VariantSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("texture",)
    texture = serializers.ImageField(write_only=True, required=False, allow_null=True)
    texture_url = serializers.SerializerMethodField()

    class Meta:
        model = Variant
        fields = (
            "id", "name", "base_price", "width", "height", "depth",
            "color_hex", "texture", "texture_url",
        )
        read_only_fields = ("id",)

    def get_texture_url(self, obj):
        return visible_file_url(obj, "texture", self.context.get("request"))


class ProductImageSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("image",)
    image = serializers.ImageField(write_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ProductImage
        fields = ("id", "image", "image_url", "sort_order")
        read_only_fields = ("id",)

    def get_image_url(self, obj):
        return visible_file_url(obj, "image", self.context.get("request"))


class ProductSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("image",)
    variants = VariantSerializer(many=True, read_only=True)
    images = serializers.SerializerMethodField()
    image = serializers.ImageField(write_only=True, required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()
    company_name = serializers.CharField(source="company.name", read_only=True)
    company_slug = serializers.CharField(source="company.slug", read_only=True)
    is_liked = serializers.SerializerMethodField()
    model3d = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = (
            "id",
            "company",
            "company_name",
            "company_slug",
            "category",
            "name_uz",
            "name_ru",
            "slug",
            "description",
            "image",
            "image_url",
            "video_url",
            "is_published",
            "variants",
            "images",
            "is_liked",
            "model3d",
            "created_at",
        )
        read_only_fields = ("id", "company", "slug", "created_at")

    def get_image_url(self, obj):
        return visible_file_url(obj, "image", self.context.get("request"))

    def get_model3d(self, obj):
        from apps.assets.serializers import Model3DSerializer

        m = getattr(obj, "model3d", None)
        if m is None or m.is_deleted:
            return None
        return Model3DSerializer(m, context=self.context).data

    def get_is_liked(self, obj):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user is None or not user.is_authenticated:
            return False
        from apps.likes.models import Like

        return Like.objects.filter(user=user, product=obj, is_deleted=False).exists()

    def get_images(self, obj):
        # joriy storage rejimiga mos bo'lmagan galereya rasmlari chiqarilmaydi
        visible = [img for img in obj.images.all() if not img.is_deleted and img.file_visible()]
        return ProductImageSerializer(visible, many=True, context=self.context).data
