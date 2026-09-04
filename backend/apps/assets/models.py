import uuid

from django.core.validators import FileExtensionValidator
from django.db import models

from common.models import BaseModel, StoredFileMixin


class Model3D(BaseModel, StoredFileMixin):
    """3D model — AR uchun (docs/43, roadmap Phase 3).

    Odatda bitta mahsulotga bitta geometriya yetarli: oddiy (bitta materialli)
    buyumlarda rang/material variantlar (Variant.color_hex yoki Variant.texture)
    shu bitta model ustiga runtime'da qo'llanadi — har rang uchun alohida fayl
    kerak emas.

    Lekin ko'p materialli mahsulotlarda (masalan eshikli shkaf — eshik, tutqich,
    zarur, oyoq har biri alohida material) runtime tint BARCHA materiallarni bir
    xilda o'zgartirib yuboradi (masalan temir tutqichni ham yog'ochga aylantiradi).
    Shuning uchun `variant` FK ham qo'shildi: firma xohlasa ma'lum bir variant
    uchun to'liq alohida 3D fayl yuklaydi (`product=None, variant=<variant>`) —
    o'sha variant tanlanganda mahsulotning umumiy modeli o'rniga shu ishlatiladi.
    Aynan bittasi to'ldirilishi kerak: yo `product`, yo `variant`.

    MVP'da tayyor GLB (web/Android AR) va USDZ (iOS AR Quick Look) yuklanadi.
    """

    class Status(models.TextChoices):
        UPLOADED = "uploaded", "Yuklandi"
        PROCESSING = "processing", "Qayta ishlanmoqda"
        READY = "ready", "Tayyor"
        FAILED = "failed", "Xatolik"

    class Visibility(models.TextChoices):
        PRIVATE = "private", "Yopiq (faqat firma a'zolari)"
        RESTRICTED = "restricted", "Cheklangan (faqat ro'yxatdagi shaxslar)"
        PUBLIC = "public", "Ochiq (havola bilan hamma)"

    product = models.OneToOneField(
        "products.Product", on_delete=models.CASCADE, related_name="model3d", null=True, blank=True
    )
    variant = models.OneToOneField(
        "products.Variant", on_delete=models.CASCADE, related_name="model3d", null=True, blank=True
    )
    # CUSTOM_PROJECT dizayn versiyasiga biriktirilgan 3D fayl (qarang
    # apps.custom_orders.DesignVersion) — product/variant'dan mustaqil,
    # lekin bir xil share_token/AR-ko'rish mexanizmidan foydalanadi.
    design_version = models.OneToOneField(
        "custom_orders.DesignVersion", on_delete=models.CASCADE, related_name="model3d", null=True, blank=True
    )
    # "glb_file" nomi tarixiy — lekin FBX/OBJ, hatto ZIP/RAR ham qabul
    # qilinadi (masalan marketplace'dan yuklab olingan arxivning o'zi):
    # server avtomatik ichidan model faylini topib GLB'ga aylantirib shu
    # maydonga qayta yozadi (apps/assets/management/commands/process_model3d.py).
    glb_file = models.FileField(
        upload_to="assets/glb/",
        blank=True,
        null=True,
        validators=[FileExtensionValidator(["glb", "gltf", "fbx", "obj", "dae", "zip", "rar"])],
    )
    usdz_file = models.FileField(
        upload_to="assets/usdz/",
        blank=True,
        null=True,
        validators=[FileExtensionValidator(["usdz"])],
    )
    # FBX/OBJ ko'pincha faylning ichida tekstura rasmlariga faqat *havola*
    # saqlaydi (artistning o'z kompyuteridagi yo'l bilan) — haqiqiy rasmlar
    # alohida arxivda bo'ladi. Shu arxiv shu yerga yuklansa, konvertatsiya
    # bosqichida fayl nomlari bo'yicha moslashtirib avtomatik ulanadi.
    texture_archive = models.FileField(
        upload_to="assets/textures/",
        blank=True,
        null=True,
        validators=[FileExtensionValidator(["zip", "rar"])],
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.UPLOADED)
    # standart o'lchamlar (metr) — AR sahnada realistik ko'rsatish uchun
    scale_width = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    scale_height = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    scale_depth = models.DecimalField(max_digits=6, decimal_places=2, default=1)

    # Quyidagilar GLB faylning o'zidan (foydalanuvchi qo'lda kiritgan
    # scale_*dan farqli — bu haqiqiy geometriyadan) hisoblanadi, qarang
    # apps/assets/geometry.py va process_model3d.py. GLB hali tayyor
    # bo'lmasa (FBX/OBJ/arxiv holatida) — bo'sh qoladi.
    bbox_width = models.DecimalField(max_digits=8, decimal_places=4, null=True, blank=True, editable=False)
    bbox_height = models.DecimalField(max_digits=8, decimal_places=4, null=True, blank=True, editable=False)
    bbox_depth = models.DecimalField(max_digits=8, decimal_places=4, null=True, blank=True, editable=False)
    shape_tag = models.CharField(max_length=20, blank=True, editable=False)

    # Mustaqil 3D-viewer havolasi (bazissoft.ru uslubida): /viewer/<share_token>/
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    visibility = models.CharField(
        max_length=20, choices=Visibility.choices, default=Visibility.PRIVATE
    )
    # "restricted" bo'lganda shu emaillar ro'yxatidagilar ko'ra oladi (kirgan holda)
    allowed_emails = models.JSONField(default=list, blank=True)

    @property
    def owning_product(self):
        """Variant-darajasidagi model ham o'z mahsulotiga ega — kompaniya/ruxsat
        tekshiruvlari doim shu orqali o'tadi (product yoki variant.product).
        DIQQAT: `design_version`ga biriktirilgan modelda Product mavjud emas —
        bunday holatda ruxsat tekshiruvi uchun `owning_company`dan foydalaning."""
        return self.product or self.variant.product

    @property
    def owning_company(self):
        """Har uchala biriktirish turi (product/variant/design_version) uchun
        ham ishlaydigan, faqat kompaniyani qaytaradigan umumiy versiya."""
        if self.design_version_id:
            return self.design_version.design.order.company
        return self.owning_product.company

    def can_view(self, user):
        """Viewer havolasiga kirish huquqi (docs — bazissoft.ru uslubidagi ulashish)."""
        if self.visibility == self.Visibility.PUBLIC:
            return True
        if not user.is_authenticated:
            return False
        if user.role == "platform_admin":
            return True
        from apps.companies.views import user_company

        company = user_company(user)
        if company is not None and company.id == self.owning_company.id:
            return True
        if self.visibility == self.Visibility.RESTRICTED:
            return user.email.lower() in [e.lower() for e in self.allowed_emails]
        return False

    def __str__(self):
        if self.variant_id:
            return f"3D: {self.variant.product.name_uz} — {self.variant.name}"
        return f"3D: {self.product.name_uz}"

    def recompute_status(self):
        """GLB bo'lsa web/AR uchun tayyor deb belgilaymiz."""
        self.status = self.Status.READY if self.glb_file else self.Status.UPLOADED

    def apply_bbox(self, bbox):
        """`geometry.extract_bbox()` natijasidan bbox_* va shape_tag'ni
        to'ldiradi. `bbox=None` bo'lsa (hali GLB emas yoki parslab
        bo'lmadi), maydonlarni tozalaydi — eski, endi haqiqiy bo'lmagan
        qiymat qolib ketmasligi uchun."""
        from .geometry import classify_shape

        if bbox:
            self.bbox_width = bbox["width"]
            self.bbox_height = bbox["height"]
            self.bbox_depth = bbox["depth"]
            self.shape_tag = classify_shape(bbox)
        else:
            self.bbox_width = None
            self.bbox_height = None
            self.bbox_depth = None
            self.shape_tag = ""
