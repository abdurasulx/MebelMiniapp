from django.db import models
from django.utils.text import slugify

from apps.companies.models import Company
from common.models import BaseModel, StoredFileMixin

from .embedding import upsert_product_embedding
from .imaging import compute_signature, dominant_color_tag


class Category(BaseModel, StoredFileMixin):
    """Global katalog kategoriyasi (techdocs/06 §8). Nomlar uz/ru — eski loyihadan."""

    parent = models.ForeignKey(
        "self", on_delete=models.SET_NULL, null=True, blank=True, related_name="children"
    )
    name_uz = models.CharField(max_length=100)
    name_ru = models.CharField(max_length=100, blank=True)
    slug = models.SlugField(max_length=120, unique=True)
    image = models.ImageField(upload_to="categories/", blank=True, null=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ("name_uz",)

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name_uz)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name_uz


class Product(BaseModel, StoredFileMixin):
    """Kompaniyaga tegishli mahsulot (techdocs/06 §9)."""

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="products")
    category = models.ForeignKey(Category, on_delete=models.PROTECT, related_name="products")
    name_uz = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to="products/", blank=True, null=True)
    is_published = models.BooleanField(default=False)
    # Rasm bo'yicha qidiruv uchun — qarang apps/products/imaging.py. Rasm
    # o'zgarganda avtomatik qayta hisoblanadi (pastdagi save()).
    image_signature = models.JSONField(blank=True, null=True, editable=False)
    # Rasmdan avtomatik aniqlangan asosiy rang (masalan "jigarrang") — nom
    # qidiruviga ham qo'shiladi (apps/products/views.py), firma qo'lda hech
    # narsa yozmasa ham "oq stul" kabi so'rovlar ishlashi uchun.
    color_tag = models.CharField(max_length=20, blank=True, editable=False)

    class Meta:
        ordering = ("-created_at",)
        unique_together = ("company", "slug")

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name_uz)
        if self.image:
            self.image_signature = compute_signature(self.image)
            self.color_tag = dominant_color_tag(self.image)
        else:
            self.image_signature = None
            self.color_tag = ""
        super().save(*args, **kwargs)
        # CLIP embedding'ni Qdrant'ga yozish — bu Postgres'dan mustaqil,
        # shuning uchun pk saqlangandan keyin, alohida qadam sifatida.
        upsert_product_embedding(self)

    def __str__(self):
        return self.name_uz


class ProductImage(BaseModel, StoredFileMixin):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="images")
    image = models.ImageField(upload_to="products/gallery/")
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("sort_order",)

    def __str__(self):
        return f"Image for {self.product}"


class Variant(BaseModel, StoredFileMixin):
    """Material/rang varianti. Narx 1 m³ uchun, o'lcham metrda (eski loyiha domeni,
    techdocs/06 §10).

    3D model geometriyasi mahsulot darajasida bitta marta yuklanadi (Product.model3d) —
    har rang uchun alohida render/eksport shart emas. Variant faqat shu bitta modelga
    runtime'da qo'llanadigan material ma'lumotini olib yuradi: `color_hex` (oddiy rang
    tint — bo'yalgan mebel uchun) yoki `texture` (yog'och naqshi surati — tabiiy tusli
    materiallar uchun, masalan jiyda/yong'oq). Ikkalasi ham web (`model-viewer` material
    API) va iOS (RealityKit material) tomonida bir xil tarzda qo'llanadi.
    """

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="variants")
    name = models.CharField(max_length=100)  # masalan: "Yong'oq", "MDF", "Tolda"
    base_price = models.DecimalField(max_digits=12, decimal_places=2)  # 1 m³ narxi
    width = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    height = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    depth = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    color_hex = models.CharField(max_length=7, blank=True)  # masalan "#8B5A2B"
    texture = models.ImageField(upload_to="variants/textures/", blank=True, null=True)
    # Tannarx (1 m³) — ixtiyoriy; berilgan bo'lsa, chegirma shu qiymatdan
    # pastga tushirilishi taqiqlanadi (qarang clean()/discount_percent).
    cost_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    # Vaqtinchalik chegirma — foiz va tugash vaqti. `discount_ends_at`
    # o'tib ketsa chegirma avtomatik faolsiz hisoblanadi (qarang
    # `discount_active`), maydonlarni qo'lda tozalash shart emas.
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    discount_ends_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("name",)

    def clean(self):
        from django.core.exceptions import ValidationError

        if self.discount_percent:
            if not (0 < self.discount_percent <= 100):
                raise ValidationError("Chegirma foizi 0 dan 100 gacha bo'lishi kerak")
            if not self.discount_ends_at:
                raise ValidationError("Chegirma tugash sanasi/vaqti ko'rsatilishi kerak")
            if self.cost_price is not None and self.effective_base_price < self.cost_price:
                raise ValidationError("Chegirma narxi tannarxdan pastga tushirilmasin")

    @property
    def discount_active(self):
        from django.utils import timezone

        return bool(
            self.discount_percent and self.discount_ends_at and self.discount_ends_at > timezone.now()
        )

    @property
    def effective_base_price(self):
        """Chegirma faol bo'lsa chegirmali, aks holda oddiy 1 m³ narxi."""
        from decimal import Decimal

        if self.discount_active:
            return self.base_price * (Decimal("1") - self.discount_percent / Decimal("100"))
        return self.base_price

    def price_for(self, width, height, depth):
        """Berilgan o'lcham (m) uchun narx (chegirmasiz) — hajmga proporsional."""
        return self.base_price * width * height * depth

    def discounted_price_for(self, width, height, depth):
        """Berilgan o'lcham (m) uchun HAQIQIY (chegirma inobatga olingan) narx —
        buyurtma/savat summasi shu asosda hisoblanishi kerak."""
        return self.effective_base_price * width * height * depth

    def __str__(self):
        return f"{self.product} — {self.name}"
