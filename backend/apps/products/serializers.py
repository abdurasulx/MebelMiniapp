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
    model3d = serializers.SerializerMethodField()
    discount_active = serializers.BooleanField(read_only=True)
    effective_base_price = serializers.DecimalField(max_digits=12, decimal_places=2, read_only=True)
    available_quantity = serializers.SerializerMethodField()

    class Meta:
        model = Variant
        fields = (
            "id", "name", "base_price", "width", "height", "depth",
            "color_hex", "texture", "texture_url", "model3d",
            "cost_price", "discount_percent", "discount_ends_at",
            "discount_active", "effective_base_price", "available_quantity",
        )
        read_only_fields = ("id",)

    def get_texture_url(self, obj):
        return visible_file_url(obj, "texture", self.context.get("request"))

    def get_available_quantity(self, obj):
        # Omborda tayyor turgan dona soni — buyurtma berish bunga bog'liq
        # emas (buyurtma faqat talab), shunchaki mijozga ko'rsatish uchun
        # (qarang "Market buyurtmasi va ombor prinsipi" §1). Bu yerda
        # import qilinishi apps.inventory'ning apps.products'ga bog'liq
        # bo'lib qolmasligi uchun funksiya ichida.
        from apps.inventory.models import ManufacturedUnit

        return ManufacturedUnit.objects.filter(
            variant=obj, status=ManufacturedUnit.Status.IN_STOCK, is_deleted=False
        ).count()

    def validate(self, attrs):
        discount_percent = attrs.get(
            "discount_percent", getattr(self.instance, "discount_percent", 0)
        )
        discount_ends_at = attrs.get(
            "discount_ends_at", getattr(self.instance, "discount_ends_at", None)
        )
        cost_price = attrs.get("cost_price", getattr(self.instance, "cost_price", None))
        base_price = attrs.get("base_price", getattr(self.instance, "base_price", None))
        if discount_percent:
            if not (0 < discount_percent <= 100):
                raise serializers.ValidationError("Chegirma foizi 0 dan 100 gacha bo'lishi kerak")
            if not discount_ends_at:
                raise serializers.ValidationError("Chegirma tugash sanasi/vaqti ko'rsatilishi kerak")
            if cost_price is not None and base_price is not None:
                from decimal import Decimal

                effective = base_price * (Decimal("1") - discount_percent / Decimal("100"))
                if effective < cost_price:
                    raise serializers.ValidationError("Chegirma narxi tannarxdan pastga tushirilmasin")
        return attrs

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # XAVFSIZLIK: tannarx — faqat kompaniya egasi/platforma admini
        # ko'rishi kerak, mijozga bu moliyaviy tafsilot ko'rinmasligi kerak
        # (qarang apps.orders.serializers'dagi bir xil naqsh).
        request = self.context.get("request")
        user = getattr(request, "user", None)
        is_owner = False
        if user is not None and user.is_authenticated:
            if user.role == "platform_admin":
                is_owner = True
            else:
                from apps.companies.views import is_company_owner, user_company

                company = user_company(user)
                is_owner = (
                    company is not None
                    and company.id == instance.product.company_id
                    and is_company_owner(user, company)
                )
        if not is_owner:
            data.pop("cost_price", None)
        return data

    def get_model3d(self, obj):
        # Ko'p materialli mahsulotlar uchun: variant o'zining alohida 3D
        # faylini olishi mumkin (mahsulotning umumiy modeli o'rniga runtime
        # rang/tekstura tint qo'llash yetarli bo'lmaganda). Yo'q bo'lsa
        # frontend mahsulotning umumiy model3d'iga qaytadi.
        model = getattr(obj, "model3d", None)
        if model is None or model.is_deleted:
            return None
        from apps.assets.serializers import Model3DSerializer

        return Model3DSerializer(model, context=self.context).data


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
    variants = serializers.SerializerMethodField()
    images = serializers.SerializerMethodField()
    image = serializers.ImageField(write_only=True, required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()
    company_name = serializers.CharField(source="company.name", read_only=True)
    company_slug = serializers.CharField(source="company.slug", read_only=True)
    company_viloyat = serializers.CharField(source="company.viloyat", read_only=True, default=None)
    company_viloyat_display = serializers.CharField(
        source="company.get_viloyat_display", read_only=True, default=None
    )
    company_address = serializers.CharField(source="company.address", read_only=True, default=None)
    category_slug = serializers.CharField(source="category.slug", read_only=True)
    category_name = serializers.CharField(source="category.name_uz", read_only=True)
    is_liked = serializers.SerializerMethodField()
    model3d = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = (
            "id",
            "company",
            "company_name",
            "company_slug",
            "company_viloyat",
            "company_viloyat_display",
            "company_address",
            "category",
            "category_slug",
            "category_name",
            "name_uz",
            "slug",
            "description",
            "image",
            "image_url",
            "color_tag",
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

    def get_variants(self, obj):
        # `obj.variants` — filtrlanmagan teskari FK manager (BaseModel'da
        # soft-delete'ni avtomatik chiqarib tashlaydigan custom manager yo'q),
        # shuning uchun o'chirilgan variantlar filtrlamasak abadiy ko'rinib
        # qolar edi (masalan variant o'chirilgandan keyin ham ro'yxatda turadi).
        visible = [v for v in obj.variants.all() if not v.is_deleted]
        return VariantSerializer(visible, many=True, context=self.context).data


class ImageSearchSerializer(serializers.Serializer):
    """`/products/search-by-image/` uchun kirish ma'lumoti."""

    image = serializers.ImageField()
