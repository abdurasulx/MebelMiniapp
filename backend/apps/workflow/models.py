from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.companies.models import Employee
from common.models import BaseModel, StoredFileMixin


class PhotoRequirement(models.TextChoices):
    REQUIRED = "required", "Majburiy"
    OPTIONAL = "optional", "Ixtiyoriy"
    DISABLED = "disabled", "Kerak emas"


class StepStatus(models.TextChoices):
    PENDING = "pending", "Navbatda"
    IN_PROGRESS = "in_progress", "Bajarilmoqda"
    COMPLETED = "completed", "Bajarildi"


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
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    required_materials = models.TextField(blank=True)
    photo_requirement = models.CharField(
        max_length=10, choices=PhotoRequirement.choices, default=PhotoRequirement.OPTIONAL
    )
    depends_on = models.ManyToManyField(
        "self", symmetrical=False, blank=True, related_name="required_by"
    )

    class Meta:
        ordering = ("order_index", "created_at")

    def __str__(self):
        return f"{self.product} — {self.name}"


class WorkflowStepInstance(BaseModel):
    """Buyurtma yaratilganda mahsulot workflow shablonidan nusxa olinadi —
    har bosqich mustaqil kuzatiladi (docs: Order Workflow)."""

    order = models.ForeignKey(
        "orders.Order", on_delete=models.CASCADE, related_name="workflow_steps"
    )
    template_step = models.ForeignKey(
        WorkflowStep, on_delete=models.SET_NULL, null=True, blank=True, related_name="instances"
    )
    order_index = models.PositiveIntegerField(default=0)
    # quyidagi maydonlar shablon o'zgarganda ham buyurtma tarixi buzilmasligi
    # uchun yaratilish paytida muhrlanadi (OrderItem snapshot patterni bilan bir xil)
    name = models.CharField(max_length=150)
    role = models.CharField(max_length=20, blank=True)
    employee = models.ForeignKey(
        Employee, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="workflow_step_instances",
    )
    estimated_hours = models.DecimalField(max_digits=6, decimal_places=2, default=1)
    cost = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    required_materials = models.TextField(blank=True)
    photo_requirement = models.CharField(
        max_length=10, choices=PhotoRequirement.choices, default=PhotoRequirement.OPTIONAL
    )
    depends_on = models.ManyToManyField(
        "self", symmetrical=False, blank=True, related_name="required_by"
    )
    status = models.CharField(max_length=15, choices=StepStatus.choices, default=StepStatus.PENDING)
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    completed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        ordering = ("order_index", "created_at")

    def __str__(self):
        return f"{self.order_id} — {self.name} ({self.status})"

    @property
    def is_available(self):
        """Barcha bog'liq bosqichlar tugagan bo'lsa, bu bosqich boshlanishi mumkin."""
        if self.status != StepStatus.PENDING:
            return False
        deps = list(self.depends_on.all())
        return not deps or all(d.status == StepStatus.COMPLETED for d in deps)

    def activate_if_ready(self):
        if self.status == StepStatus.PENDING and self.is_available:
            self.status = StepStatus.IN_PROGRESS
            self.started_at = timezone.now()
            self.save(update_fields=["status", "started_at", "updated_at"])

    def activate_dependents(self):
        for dependent in self.required_by.filter(is_deleted=False):
            dependent.activate_if_ready()


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
