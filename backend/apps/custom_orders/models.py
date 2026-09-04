from django.conf import settings
from django.db import models

from common.models import BaseModel, StoredFileMixin


class SiteSurveyStatus(models.TextChoices):
    ASSIGNED = "assigned", "Tayinlangan"
    VISITED = "visited", "Tashrif qilindi"
    ORDER_CREATED = "order_created", "Buyurtma yaratildi"
    CANCELLED = "cancelled", "Bekor qilindi"


class SiteSurvey(BaseModel):
    """Admin ustani mijoz uyiga joy o'rganishga tayinlaydi — usta tashrif
    buyurib rasm/video/o'lcham/izoh kiritadi, so'ng shu asosda individual
    buyurtma (CUSTOM_PROJECT) yaratadi (docs "Buyurtma va ishlab chiqarish
    tizimi" §3-4). Bitta survey ko'pi bilan bitta buyurtmaga olib keladi."""

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="site_surveys"
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="site_surveys"
    )
    assigned_master = models.ForeignKey(
        "companies.Employee", on_delete=models.PROTECT, related_name="assigned_surveys"
    )
    assigned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    address = models.CharField(max_length=500, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    notes = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=SiteSurveyStatus.choices, default=SiteSurveyStatus.ASSIGNED)
    order = models.OneToOneField(
        "orders.Order", on_delete=models.SET_NULL, null=True, blank=True, related_name="site_survey"
    )

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"Survey {str(self.id)[:8]} — {self.assigned_master}"


class SiteSurveyMediaType(models.TextChoices):
    PHOTO = "photo", "Rasm"
    VIDEO = "video", "Video"


class SiteSurveyMedia(BaseModel, StoredFileMixin):
    survey = models.ForeignKey(SiteSurvey, on_delete=models.CASCADE, related_name="media")
    file = models.FileField(upload_to="site_surveys/")
    media_type = models.CharField(max_length=10, choices=SiteSurveyMediaType.choices)
    caption = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ("created_at",)

    def __str__(self):
        return f"{self.get_media_type_display()} — {self.survey_id}"


class Design(BaseModel):
    """Har bir CUSTOM_PROJECT buyurtmasi uchun MAJBURIY dizayn yozuvi —
    buyurtma yaratilishi bilan bo'sh holda avtomatik yaratiladi (qarang
    apps.custom_orders.services.create_custom_order), chunki dizayner
    bosqichi hech qachon o'tkazib yuborilmasligi kerak (docs §5)."""

    order = models.OneToOneField("orders.Order", on_delete=models.CASCADE, related_name="custom_design")
    approved_version = models.ForeignKey(
        "DesignVersion", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    # Ishlab chiqarish ketma-ketligi — dizayner tanlagan bosqichlar
    # (`apps.workflow.Stage` qiymatlari), tasdiqlangach shu tartibda ad-hoc
    # `WorkflowStepInstance` yaratiladi (qarang services.create_workflow_instances_from_design).
    production_sequence = models.JSONField(default=list, blank=True)
    # Qaysi katalog mahsulot(lar)idan ilhomlanganini izlash uchun — spec'dagi
    # "ProductInstance" tugunining soddalashtirilgan, faqat ma'lumot uchun
    # versiyasi (alohida model kerak emas, custom loyihaning o'ziga xos
    # o'lchamlari/tarkibi baribir OrderItem'larda saqlanadi).
    source_products = models.ManyToManyField("products.Product", blank=True, related_name="+")

    def __str__(self):
        return f"Design — {self.order_id}"


class DesignVersion(BaseModel):
    """Dizaynerning har bir yuklagan 3D loyihasi — eski versiya HECH QACHON
    o'chirilmaydi, faqat yangisi qo'shiladi (docs §5.1). 3D fayl o'zi
    `apps.assets.Model3D` orqali (`design_version` OneToOne) biriktiriladi —
    mavjud AR/ko'rish infratuzilmasi (share_token) shu bilan o'zgarishsiz
    ishlayveradi."""

    design = models.ForeignKey(Design, on_delete=models.CASCADE, related_name="versions")
    version_number = models.PositiveIntegerField()
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        "companies.Employee", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        ordering = ("version_number",)
        unique_together = ("design", "version_number")

    def __str__(self):
        return f"{self.design} V{self.version_number}"


class AuditEntityType(models.TextChoices):
    SITE_SURVEY = "site_survey", "Joy o'rganish"
    DESIGN = "design", "Dizayn"
    ORDER_ITEM_COST = "order_item_cost", "Buyurtma bandi tannarxi"
    ORDER_STATUS = "order_status", "Buyurtma holati"


class AuditLogEntry(BaseModel):
    """CUSTOM_PROJECT oqimidagi muhim o'zgarishlar (tayinlash, tasdiqlash,
    tannarx kiritish, status o'zgarishi) — kim, qachon, qanday o'zgarish
    (docs §9/§11 audit talabi)."""

    entity_type = models.CharField(max_length=30, choices=AuditEntityType.choices)
    entity_id = models.UUIDField()
    action = models.CharField(max_length=100)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    old_value = models.JSONField(null=True, blank=True)
    new_value = models.JSONField(null=True, blank=True)
    reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.entity_type}:{self.entity_id} — {self.action}"
