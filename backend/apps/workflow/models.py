from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.companies.models import Employee
from apps.inventory.models import UNIT_CHOICES
from common.models import BaseModel, StoredFileMixin


class PhotoRequirement(models.TextChoices):
    REQUIRED = "required", "Majburiy"
    OPTIONAL = "optional", "Ixtiyoriy"
    DISABLED = "disabled", "Kerak emas"


class StepStatus(models.TextChoices):
    PENDING = "pending", "Navbatda"
    IN_PROGRESS = "in_progress", "Bajarilmoqda"
    COMPLETED = "completed", "Bajarildi"


class Stage(models.TextChoices):
    """Qo'lda yaratiladigan (buyurtma retseptiga bog'liq bo'lmagan) vazifalar
    uchun ixtiyoriy toifa — avvalgi `apps.production.ProductionTask.Stage`dan
    ko'chirildi (ProductionTask va WorkflowStepInstance bitta tizimga
    birlashtirildi)."""

    CUTTING = "cutting", "Kesish"
    EDGE_PROCESSING = "edge_processing", "Qirra ishlov"
    ASSEMBLY = "assembly", "Yig'ish"
    PAINTING = "painting", "Bo'yash"
    QUALITY_CONTROL = "quality_control", "Sifat nazorati"
    INSTALLATION = "installation", "O'rnatish"
    DELIVERY = "delivery", "Yetkazib berish"
    OTHER = "other", "Boshqa"


# qaysi kasb bu bosqichga mos (positions bilan moslashtirish uchun tavsiya)
STAGE_POSITION = {
    Stage.CUTTING: "usta",
    Stage.EDGE_PROCESSING: "usta",
    Stage.ASSEMBLY: "usta",
    Stage.PAINTING: "usta",
    Stage.QUALITY_CONTROL: "usta",
    Stage.INSTALLATION: "ornatuvchi",
    Stage.DELIVERY: "haydovchi",
    Stage.OTHER: None,
}


class WorkType(BaseModel):
    """Ish turlari katalogi — firma miqyosida markazlashgan: bir marta narx
    (birlik boshiga) va kerakli lavozim belgilanadi, keyin bu yozuv istalgan
    mahsulotning istalgan ish bosqichida (`WorkflowStep.work_type`) qayta
    ishlatiladi. Masalan "Kesish" bosqichida "Rekani kesish" (m, narxi X) va
    alohida "Konfirmat Ø8 teshish" (dona, narxi Y) — turli teshiklar/ishlar
    turlicha narxlanishi shu orqali ta'minlanadi, narx har safar qo'lda
    qayta kiritilmaydi."""

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="work_types"
    )
    stage = models.CharField(max_length=20, choices=Stage.choices, blank=True)
    name = models.CharField(max_length=150)
    unit = models.CharField(max_length=10, choices=UNIT_CHOICES, default="dona")
    price_per_unit = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    required_role = models.CharField(max_length=20, choices=Employee.Position.choices, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("stage", "name")

    def __str__(self):
        return f"{self.name} ({self.company.name})"


class WorkflowStep(BaseModel):
    """Mahsulotning ishlab chiqarish jarayoni shabloni (bosqichlar grafigi).

    `depends_on` — DAG uchun tayyor (bir bosqich bir nechta oldingi bosqichga
    bog'liq bo'lishi mumkin, kelajakda parallel tarmoqlar uchun). MVP'da UI
    odatda chiziqli zanjir yaratadi (har bosqich faqat oldingisiga bog'liq),
    lekin backend allaqachon umumiy grafikni qo'llab-quvvatlaydi.
    """

    product = models.ForeignKey(
        "products.Product", on_delete=models.CASCADE, related_name="workflow_steps"
    )
    order_index = models.PositiveIntegerField(default=0)
    name = models.CharField(max_length=150)
    role = models.CharField(max_length=20, choices=Employee.Position.choices, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True, blank=True, related_name="workflow_steps"
    )
    estimated_hours = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    # `work_type` belgilansa, `cost` QO'LDA emas — `quantity x
    # work_type.price_per_unit` orqali AVTOMATIK hisoblanadi (qarang save()).
    # `work_type` bo'sh qoldirilsa (eski xatti-harakat), `cost` oddiy qo'lda
    # kiritiladigan qattiq summa bo'lib qoladi — orqaga moslik uchun.
    work_type = models.ForeignKey(
        WorkType, on_delete=models.SET_NULL, null=True, blank=True, related_name="workflow_steps"
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=1)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # `raw_material` belgilansa, usta "Bajardim" bosganda `quantity` (xuddi
    # yuqoridagi ish narxi hisobida ishlatilgan miqdor) shu materialning
    # o'lchov birligida ombordan AVTOMATIK ayiriladi (qarang
    # apps.workflow.services.consume_material_and_credit_payroll). Bitta
    # bosqich — bitta material (spetsifikatsiyaga ko'ra); `required_materials`
    # (pastda, erkin matn) eski/qo'shimcha izoh sifatida qolaveradi.
    raw_material = models.ForeignKey(
        "inventory.Material", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    required_materials = models.TextField(blank=True)
    photo_requirement = models.CharField(
        max_length=10, choices=PhotoRequirement.choices, default=PhotoRequirement.OPTIONAL
    )
    depends_on = models.ManyToManyField(
        "self", symmetrical=False, blank=True, related_name="required_by"
    )

    class Meta:
        ordering = ("order_index", "created_at")

    def save(self, *args, **kwargs):
        if self.work_type_id:
            self.cost = self.quantity * self.work_type.price_per_unit
            if not self.role:
                self.role = self.work_type.required_role
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.product} — {self.name}"


class WorkflowStepInstance(BaseModel):
    """Ishlab chiqarish vazifasi — ikki xil yo'l bilan yaratiladi:

    1. **Avtomatik**: buyurtma yaratilganda mahsulot workflow shablonidan
       nusxa olinadi (`template_step` to'ldirilgan, `order` majburiy) —
       DAG bog'liqlik bilan, docs: Order Workflow.
    2. **Qo'lda**: firma egasi retseptga bog'liq bo'lmagan vazifa yaratadi
       (`template_step` bo'sh, `order` ixtiyoriy) — masalan yetkazib berish
       yoki maxsus topshiriq (avvalgi `ProductionTask`, endi shu yerga
       birlashtirilgan).

    Ikkalasi ham bitta joyda kuzatiladi va bitta ish haqi hisobiga (`Payslip`)
    qo'shiladi — farqi: avtomatik bosqichlar odatda `cost`ga (retseptda
    belgilangan) ega, qo'lda vazifalar esa `bonus_per_task`ga hisoblanadi
    (qarang `Payslip.recompute`, `template_step__isnull` bo'yicha ajratiladi).
    """

    # DB darajasida null=True (eski qatorlar uchun migratsiya osonroq bo'lishi
    # uchun), lekin amalda har doim to'ldiriladi (serializer/service orqali) —
    # `order`dan hosil bo'lganda order.company, qo'lda yaratilganda so'rovchi
    # kompaniyasi.
    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, null=True, blank=True,
        related_name="workflow_instances",
    )
    order = models.ForeignKey(
        "orders.Order", on_delete=models.SET_NULL, null=True, blank=True, related_name="workflow_steps"
    )
    template_step = models.ForeignKey(
        WorkflowStep, on_delete=models.SET_NULL, null=True, blank=True, related_name="instances"
    )
    order_index = models.PositiveIntegerField(default=0)
    # quyidagi maydonlar shablon o'zgarganda ham buyurtma tarixi buzilmasligi
    # uchun yaratilish paytida muhrlanadi (OrderItem snapshot patterni bilan bir xil)
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    stage = models.CharField(max_length=20, choices=Stage.choices, blank=True)
    role = models.CharField(max_length=20, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="workflow_step_instances",
    )
    estimated_hours = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    # `work_type`/`quantity` ham boshqa maydonlar kabi yaratilish paytida
    # muhrlanadi (snapshot) — keyinchalik WorkType.price_per_unit
    # o'zgartirilsa ham, bu buyurtma tarixidagi `cost`ga ta'sir qilmaydi.
    work_type = models.ForeignKey(
        WorkType, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    quantity = models.DecimalField(max_digits=10, decimal_places=3, default=1)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    raw_material = models.ForeignKey(
        "inventory.Material", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    # Bosqich "Bajardim" bosilib yakunlanganda ombordan ayirish AMALGA
    # OSHIRILGANMI — qayta bosilsa yoki bosqich qandaydir yo'l bilan qayta
    # yakunlansa ham material IKKI MARTA ayirilmasligi uchun soqchi bayroq.
    material_consumed = models.BooleanField(default=False)
    required_materials = models.TextField(blank=True)
    photo_requirement = models.CharField(
        max_length=10, choices=PhotoRequirement.choices, default=PhotoRequirement.OPTIONAL
    )
    depends_on = models.ManyToManyField(
        "self", symmetrical=False, blank=True, related_name="required_by"
    )
    status = models.CharField(max_length=15, choices=StepStatus.choices, default=StepStatus.PENDING)
    deadline = models.DateField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    completed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        ordering = ("order_index", "created_at")

    def __str__(self):
        return f"{self.name} ({self.status})"

    @property
    def is_available(self):
        """Barcha bog'liq bosqichlar tugagan bo'lsa, bu bosqich boshlanishi mumkin."""
        if self.status != StepStatus.PENDING:
            return False
        deps = list(self.depends_on.all())
        return not deps or all(d.status == StepStatus.COMPLETED for d in deps)

    def activate_if_ready(self):
        # Xodimi hali biriktirilmagan ("erkin") bosqichni avtomatik
        # IN_PROGRESS qilib qo'yish noto'g'ri — hech kim ish boshlamagan
        # bo'lsa ham "bajarilmoqda" ko'rinib qolar edi. Bunday bosqich
        # PENDING holida qoladi, lekin `is_available=True` bo'lgani uchun
        # mos lavozimdagi ustalarga "erkin topshiriqlar" hovuzida ko'rinadi
        # (qarang StepApplication, views.py::open/apply/approve_application).
        if self.status == StepStatus.PENDING and self.is_available and self.employee_id:
            self.status = StepStatus.IN_PROGRESS
            self.started_at = timezone.now()
            self.save(update_fields=["status", "started_at", "updated_at"])

    def activate_dependents(self):
        """`required_by` orasida shu bosqich tugashi bilan boshlanishga tayyor
        bo'lgan bosqichlarni faollashtiradi va ularni qaytaradi — chaqiruvchi
        (`views.py::complete`) shu ro'yxat orqali tegishli xodimlarga
        xabarnoma yuboradi (qarang apps.notifications.services.notify_task_available).
        Xodimi biriktirilmagan ("erkin") bog'liq bosqichlar `newly_open`da
        qaytariladi — ular status o'zgarmasa ham (PENDING qoladi) endi mos
        lavozimdagi ustalar hovuzida ko'rinadi va e'lon qilinishi kerak."""
        activated = []
        newly_open = []
        for dependent in self.required_by.filter(is_deleted=False):
            was_pending = dependent.status == StepStatus.PENDING
            dependent.activate_if_ready()
            if was_pending and dependent.status == StepStatus.IN_PROGRESS:
                activated.append(dependent)
            elif was_pending and not dependent.employee_id and dependent.is_available:
                newly_open.append(dependent)
        return activated, newly_open


class ApplicationStatus(models.TextChoices):
    PENDING = "pending", "Kutilmoqda"
    APPROVED = "approved", "Tasdiqlangan"
    REJECTED = "rejected", "Rad etilgan"


class StepApplication(BaseModel):
    """Xodimi biriktirilmagan ("erkin") bosqichga usta yuborgan zayavka —
    bitta bosqichga bir nechta usta murojaat qilishi mumkin, lekin firma
    egasi/menejer bittasini tasdiqlaganda qolganlari avtomatik rad etiladi
    (qarang views.py::approve_application). Bosqich boshqa usta tomonidan
    allaqachon (employee biriktirilgan) egallangan bo'lsa, yangi zayavka
    qabul qilinmaydi."""

    step = models.ForeignKey(WorkflowStepInstance, on_delete=models.CASCADE, related_name="applications")
    employee = models.ForeignKey(Employee, on_delete=models.CASCADE, related_name="step_applications")
    status = models.CharField(max_length=10, choices=ApplicationStatus.choices, default=ApplicationStatus.PENDING)
    decided_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("created_at",)
        unique_together = ("step", "employee")

    def __str__(self):
        return f"{self.step} <- {self.employee} ({self.status})"


class ProgressUpdate(BaseModel, StoredFileMixin):
    """Ishchi tomonidan bosqich davomida qoldirilgan yangilanish (rasm/izoh) —
    cheksiz sonda qo'shilishi mumkin, ishlab chiqarish tarixi sifatida saqlanadi."""

    step = models.ForeignKey(WorkflowStepInstance, on_delete=models.CASCADE, related_name="updates")
    image = models.ImageField(upload_to="workflow/updates/", blank=True, null=True)
    comment = models.TextField(blank=True)
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    is_completion = models.BooleanField(default=False)

    class Meta:
        ordering = ("created_at",)

    def __str__(self):
        return f"{self.step} @ {self.created_at:%Y-%m-%d %H:%M}"
