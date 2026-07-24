import uuid

from django.conf import settings
from django.core.validators import FileExtensionValidator
from django.db import models

from common.models import BaseModel, StoredFileMixin


def _default_position():
    return [0.0, 0.0, 0.0]


def _default_scale():
    return [1.0, 1.0, 1.0]


class DetailAsset(BaseModel, StoredFileMixin):
    """AR/loyiha sahnasini to'ldirish uchun umumiy dekorativ element (kafel,
    oboy, muzlatgich va h.k.) — sotiladigan Product emas, faqat vizual
    to'ldiruvchi (xonani "to'ldirib chiqish" uchun).

    `company=None` — platforma standart (ommaviy) kutubxonasi, har qanday
    mijoz o'z loyihasida ishlatishi mumkin. `company` ko'rsatilgan bo'lsa —
    o'sha firma qo'shgan xususiy element, faqat o'zida (docs: "ba'zi
    birlari — defaultlari — ommaviy tursin, o'zinikilar faqat o'zida").
    """

    class Category(models.TextChoices):
        KAFEL = "kafel", "Kafel"
        OBOY = "oboy", "Oboy"
        TEXNIKA = "texnika", "Maishiy texnika"
        MEBEL_DETAL = "mebel_detal", "Mebel detali"
        BOSHQA = "boshqa", "Boshqa"

    company = models.ForeignKey(
        "companies.Company",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="detail_assets",
    )
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=20, choices=Category.choices, default=Category.BOSHQA)
    glb_file = models.FileField(
        upload_to="projects/detail-assets/",
        validators=[FileExtensionValidator(["glb", "gltf"])],
    )
    thumbnail = models.ImageField(upload_to="projects/detail-thumbs/", blank=True, null=True)

    class Meta:
        ordering = ("category", "name")

    def __str__(self):
        return self.name


class Project(BaseModel):
    """Mijozning "xonamni bezash" loyihasi — bir nechta firmadan mahsulot va
    umumiy detal elementlarni to'plab, to'lovdan keyin 3D fazoda o'zi
    joylashtirib ko'radi (Bazis uslubidagi mustaqil viewer — butun xona
    ko'rinishi, AR emas).
    """

    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="projects"
    )
    name = models.CharField(max_length=200, default="Yangi loyiha")
    # Hozircha haqiqiy to'lov integratsiyasi yo'q (Payme/Click — keyingi bosqich).
    # Dev rejimida `pay` action shu bayroqni to'g'ridan-to'g'ri True qiladi.
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    # Mustaqil ulashish havolasi (Model3D bilan bir xil naqsh, bazissoft.ru uslubi).
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    is_public = models.BooleanField(default=False)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.name} ({self.customer})"


class ProjectItem(BaseModel):
    """Loyiha ichiga joylashtirilgan bitta obyekt — yo sotiladigan
    mahsulot+variant (haqiqiy AR modelidan, variant rangi/naqshi bilan
    foydalaniladi), yoki umumiy DetailAsset. Fazodagi joylashuvi shu yerda
    saqlanadi — front (Three.js) qiymatlarni to'g'ridan-to'g'ri qo'llaydi.
    """

    class SourceType(models.TextChoices):
        PRODUCT = "product", "Mahsulot"
        DETAIL = "detail", "Detal element"

    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="items")
    source_type = models.CharField(max_length=10, choices=SourceType.choices)
    product = models.ForeignKey(
        "products.Product", on_delete=models.CASCADE, null=True, blank=True, related_name="+"
    )
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    detail_asset = models.ForeignKey(
        DetailAsset, on_delete=models.CASCADE, null=True, blank=True, related_name="+"
    )
    position = models.JSONField(default=_default_position)  # [x, y, z] metr
    rotation = models.JSONField(default=_default_position)  # [x, y, z] radian (Euler)
    scale = models.JSONField(default=_default_scale)

    class Meta:
        ordering = ("created_at",)

    def __str__(self):
        return f"{self.project} — {self.source_type}"
