import uuid

from django.core.validators import FileExtensionValidator
from django.db import models

from common.models import BaseModel, StoredFileMixin


class Model3D(BaseModel, StoredFileMixin):
    """Mahsulotning 3D modeli — AR uchun (docs/43, roadmap Phase 3).

    Bitta mahsulotga bitta geometriya: barcha rang/material variantlar (Variant.color_hex
    yoki Variant.texture) shu bitta model ustiga runtime'da qo'llanadi — har rang uchun
    alohida fayl yuklash/qayta render qilish shart emas (masalan jiyda va yong'oq rangini
    bitta stul modeliga qo'llash mumkin).

    MVP'da tayyor GLB (web/Android AR) va USDZ (iOS AR Quick Look) yuklanadi.
    Kelajakda FBX/OBJ → avtomatik konvertatsiya qo'shiladi (processing status shu uchun).
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
        "products.Product", on_delete=models.CASCADE, related_name="model3d"
    )
    # "glb_file" nomi tarixiy — lekin FBX/OBJ ham qabul qilinadi: agar manba
    # shu formatlarda bo'lsa, server avtomatik GLB'ga aylantirib shu maydonga
    # qayta yozadi (apps/assets/management/commands/process_model3d.py).
    glb_file = models.FileField(
        upload_to="assets/glb/",
        blank=True,
        null=True,
        validators=[FileExtensionValidator(["glb", "gltf", "fbx", "obj"])],
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

    # Mustaqil 3D-viewer havolasi (bazissoft.ru uslubida): /viewer/<share_token>/
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    visibility = models.CharField(
        max_length=20, choices=Visibility.choices, default=Visibility.PRIVATE
    )
    # "restricted" bo'lganda shu emaillar ro'yxatidagilar ko'ra oladi (kirgan holda)
    allowed_emails = models.JSONField(default=list, blank=True)

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
        if company is not None and company.id == self.product.company_id:
            return True
        if self.visibility == self.Visibility.RESTRICTED:
            return user.email.lower() in [e.lower() for e in self.allowed_emails]
        return False

    def __str__(self):
        return f"3D: {self.product.name_uz}"

    def recompute_status(self):
        """GLB bo'lsa web/AR uchun tayyor deb belgilaymiz."""
        self.status = self.Status.READY if self.glb_file else self.Status.UPLOADED
