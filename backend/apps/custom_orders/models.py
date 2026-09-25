from django.conf import settings
from django.db import models

from common.models import BaseModel


class Design(BaseModel):
    """Har bir CUSTOM_PROJECT buyurtmasi uchun MAJBURIY dizayn yozuvi —
    buyurtma yaratilishi bilan bo'sh holda avtomatik yaratiladi (qarang
    apps.custom_orders.services.create_custom_order_on_site), chunki
    dizayner bosqichi hech qachon o'tkazib yuborilmasligi kerak (docs §5)."""

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
    # Buyurtma yaratilishi bilan (yoki keyinroq, tasdiqlashdan oldin) biriktirilishi
    # mumkin bo'lgan Bazis (mebel CAD) eksporti — usta shu faylni to'g'ridan-to'g'ri
    # buyurtma yaratish oqimida yuklaydi (qarang apps.custom_orders.views.
    # DesignBazisImportView). Biriktirilgan bo'lsa, `bazis_summary` shu yerda
    # keshlanadi va `create_workflow_instances_from_design` `production_sequence`
    # o'rniga shundan DETAL/TESHIK darajasidagi haqiqiy topshiriqlar yaratadi.
    bazis_file = models.FileField(upload_to="custom_orders/bazis/", blank=True, null=True)
    bazis_summary = models.JSONField(default=dict, blank=True)
    # Kesish/Kromkalash — "asosiy bosqich"lar (qarang
    # services.bazis_groups_from_summary) — har biriga KIM bajarishi
    # oldindan belgilanadi: aniq usta (`employee_id`) YOKI ochiq rol
    # (`role`, keyin shu rolga ega har qanday xodim navbatdan oladi).
    # Shakli: {"cutting": {"employee_id": "<uuid>"} yoki {"role": "usta"},
    # "edge_processing": {...}} — qarang apps.custom_orders.views.
    # DesignBazisImportView va services.create_workflow_instances_from_design.
    bazis_assignments = models.JSONField(default=dict, blank=True)
    # Bazis'dagi material nomi ("ДСП бук 16") -> firma omboridagi
    # `inventory.Material.id`. Har buyurtmada boshqacha tanlanishi mumkin
    # (bir mijozga arzonroq, boshqasiga qimmatroq DSP). Faqat tavsif/tannarx
    # uchun ishlatiladi — `WorkflowStepInstance.raw_material` (ombordan
    # avtomatik ayirish) ATAYLAB bog'lanmaydi: u `quantity`ni material
    # birligida ayiradi, bu yerda esa `quantity` detal SONI.
    material_map = models.JSONField(default=dict, blank=True)
    # Usta qo'lda qo'shgan qo'shimcha etaplar:
    # [{"name", "employee_id"|"role", "jobs": [{"name", "quantity", "price"}]}]
    extra_stages = models.JSONField(default=list, blank=True)

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
    # "site_survey" qiymati eski (o'chirilgan) Joy o'rganish yozuvlari
    # tarixi uchun saqlanadi — yangi yozuvlar endi to'g'ridan-to'g'ri
    # ORDER_STATUS ("individual buyurtma joyida yaratildi") sifatida
    # qayd qilinadi (qarang services.create_custom_order_on_site).
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
