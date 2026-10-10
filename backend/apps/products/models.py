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

    # 3D modeldan avtomatik rasm (apps/products/rendering) holati.
    class RenderStatus(models.TextChoices):
        NONE = "none", "Render yo'q"
        PENDING = "pending", "Navbatda"
        PROCESSING = "processing", "Render qilinmoqda"
        READY = "ready", "Tayyor"
        FAILED = "failed", "Xatolik"

    render_status = models.CharField(
        max_length=12, choices=RenderStatus.choices, default=RenderStatus.NONE, db_index=True
    )
    render_error = models.TextField(blank=True)
    # Modelning haqiqiy o'lchami (sm): {"w":..,"h":..,"d":..}
    model_dims_cm = models.JSONField(null=True, blank=True)
    # Sotuvchi kiritgan o'lcham modeldan >10% farq qilsa — moderator ko'rib chiqadi.
    needs_moderation = models.BooleanField(default=False)
    moderation_note = models.CharField(max_length=300, blank=True)
    # `image` render'dan avtomatik qo'yilgan bo'lsa True (sotuvchi o'z rasmini
    # yuklasa render uni almashtirmaydi).
    image_from_render = models.BooleanField(default=False, editable=False)

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
    # Vaqtinchalik chegirma. Bir variantda bir vaqtning o'zida faqat BITTA chegirma
    # (tur + qiymat + oraliq) — shuning uchun bir nechta faol chegirma to'qnashuvi
    # mumkin emas. Faol/faolmasligi va narx hisobi FAQAT `apps.products.pricing`
    # xizmatida (qarang `pricing`/`discount_active`/`effective_base_price`).
    # `discount_percent` + `discount_ends_at` mavjud maydonlar — orqaga moslik
    # uchun saqlangan (foizli chegirma avvalgidek ishlaydi).
    DISCOUNT_PERCENT = "percent"
    DISCOUNT_FIXED = "fixed"
    DISCOUNT_TYPE_CHOICES = (
        (DISCOUNT_PERCENT, "Foiz"),
        (DISCOUNT_FIXED, "Qat'iy summa"),
    )
    discount_type = models.CharField(
        max_length=10, choices=DISCOUNT_TYPE_CHOICES, default=DISCOUNT_PERCENT
    )
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    discount_fixed_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount_starts_at = models.DateTimeField(null=True, blank=True)
    discount_ends_at = models.DateTimeField(null=True, blank=True)
    # Qo'lda o'chirib qo'yish (chegirmani o'chirmasdan vaqtincha to'xtatish).
    discount_enabled = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)

    def clean(self):
        from django.core.exceptions import ValidationError

        from .pricing import validate_discount

        errors = validate_discount(
            base_price=self.base_price,
            discount_type=self.discount_type,
            percent=self.discount_percent,
            fixed_amount=self.discount_fixed_amount,
            starts_at=self.discount_starts_at,
            ends_at=self.discount_ends_at,
            cost_price=self.cost_price,
        )
        if errors:
            raise ValidationError(errors)

    @property
    def pricing(self):
        """`PriceBreakdown` — asl narx, chegirma foizi/summasi va yakuniy narx."""
        from .pricing import compute_pricing

        return compute_pricing(
            self.base_price,
            enabled=self.discount_enabled,
            discount_type=self.discount_type,
            percent=self.discount_percent,
            fixed_amount=self.discount_fixed_amount,
            starts_at=self.discount_starts_at,
            ends_at=self.discount_ends_at,
        )

    @property
    def discount_active(self):
        return self.pricing.active

    @property
    def effective_base_price(self):
        """Chegirma faol bo'lsa chegirmali, aks holda oddiy 1 m³ narxi."""
        return self.pricing.final_price

    def price_for(self, width, height, depth):
        """Berilgan o'lcham (m) uchun narx (chegirmasiz) — hajmga proporsional."""
        return self.base_price * width * height * depth

    def discounted_price_for(self, width, height, depth):
        """Berilgan o'lcham (m) uchun HAQIQIY (chegirma inobatga olingan) narx —
        buyurtma/savat summasi shu asosda hisoblanishi kerak."""
        return self.effective_base_price * width * height * depth

    def __str__(self):
        return f"{self.product} — {self.name}"


# Platforma qo'llab-quvvatlaydigan tillar (ilova/web bilan bir xil kodlar).
SHOWCASE_LANGUAGES = ("uz", "en", "ru", "tg", "tr", "ky", "kk", "de", "az")


def _validate_translations(value):
    from django.core.exceptions import ValidationError

    if not isinstance(value, dict):
        raise ValidationError("Tarjimalar {til: matn} ko'rinishida bo'lishi kerak.")
    for lang, text in value.items():
        if lang not in SHOWCASE_LANGUAGES:
            raise ValidationError(f"Noma'lum til kodi: {lang}")
        if not isinstance(text, str):
            raise ValidationError("Tarjima matn bo'lishi kerak.")


class ShowcaseProduct(BaseModel, StoredFileMixin):
    """Vitrina (demo) mahsuloti — firmaga tegishli EMAS, faqat platforma admini
    boshqaradi. Faol firma yo'q hududdagi foydalanuvchiga ilova imkoniyatlarini
    ko'rsatish uchun ishlatiladi; buyurtma berib bo'lmaydi (Variant/Cart/Order'ga
    umuman bog'lanmagan — shuning uchun buyurtma yo'li yo'q).

    `name`/`description` — {"uz": "...", "ru": "...", ...}; til bo'lmasa o'zbekcha.
    """

    category = models.ForeignKey(
        Category, on_delete=models.SET_NULL, null=True, blank=True, related_name="showcase_products"
    )
    name = models.JSONField(default=dict, validators=[_validate_translations])
    description = models.JSONField(default=dict, blank=True, validators=[_validate_translations])
    image = models.ImageField(upload_to="showcase/", blank=True, null=True)
    price_from = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    sort_order = models.PositiveIntegerField(default=0)
    is_published = models.BooleanField(default=True)

    class Meta:
        ordering = ("sort_order", "-created_at")
        verbose_name = "showcase product"

    def text(self, field, lang):
        data = getattr(self, field) or {}
        return data.get(lang) or data.get("uz") or next((v for v in data.values() if v), "")

    def __str__(self):
        return self.text("name", "uz") or str(self.pk)


class ShowcaseImage(BaseModel, StoredFileMixin):
    product = models.ForeignKey(ShowcaseProduct, on_delete=models.CASCADE, related_name="images")
    image = models.ImageField(upload_to="showcase/gallery/")
    sort_order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ("sort_order",)


class RenderJob(BaseModel):
    """3D modeldan rasm render qilish navbati (apps/products/rendering/worker).
    Bir vaqtda bitta job (concurrency 1) — `render_worker` buyrug'i."""

    class Status(models.TextChoices):
        PENDING = "pending", "Navbatda"
        PROCESSING = "processing", "Jarayonda"
        DONE = "done", "Tayyor"
        FAILED = "failed", "Xatolik"

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="render_jobs")
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.PENDING, db_index=True)
    attempts = models.PositiveSmallIntegerField(default=0)
    # Render qilingan GLB fayl nomi — o'zgarmagan fayl qayta render qilinmasin.
    source_name = models.CharField(max_length=300, blank=True)
    error = models.TextField(blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    duration_s = models.FloatField(null=True, blank=True)

    class Meta:
        ordering = ("created_at",)


class RenderedImage(BaseModel):
    """Server render qilgan yakuniy rasm (bir shot uchun barcha o'lcham/formatlar).
    `urls` = {"400": {"webp": url, "avif": url}, "800": {...}, "1600": {...}}"""

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name="renders")
    variant = models.ForeignKey(
        Variant, on_delete=models.SET_NULL, null=True, blank=True, related_name="renders"
    )
    variant_name = models.CharField(max_length=100, blank=True)
    variant_slug = models.SlugField(max_length=120, blank=True)
    shot = models.CharField(max_length=10)  # hero|front|side|back|top
    sort_order = models.PositiveSmallIntegerField(default=0)
    urls = models.JSONField(default=dict)

    class Meta:
        ordering = ("variant_slug", "sort_order")
