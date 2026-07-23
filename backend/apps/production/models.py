from django.conf import settings
from django.db import models
from django.db.models import Sum

from common.models import BaseModel


class ProductionTask(BaseModel):
    """Ishlab chiqarish vazifasi — xodim rol(lar)iga bog'langan (docs/38 §7-8).

    Har vazifa bitta bosqichga (stage) tegishli va ixtiyoriy ravishda
    buyurtmaga bog'lanadi. Xodim faqat o'ziga tayinlangan vazifalarni ko'radi
    va statusini o'zgartiradi; firma (ega) barchasini yaratadi/tayinlaydi.
    """

    class Stage(models.TextChoices):
        CUTTING = "cutting", "Kesish"
        EDGE_PROCESSING = "edge_processing", "Qirra ishlov"
        ASSEMBLY = "assembly", "Yig'ish"
        PAINTING = "painting", "Bo'yash"
        QUALITY_CONTROL = "quality_control", "Sifat nazorati"
        INSTALLATION = "installation", "O'rnatish"
        DELIVERY = "delivery", "Yetkazib berish"
        OTHER = "other", "Boshqa"

    class Status(models.TextChoices):
        TODO = "todo", "Navbatda"
        IN_PROGRESS = "in_progress", "Bajarilmoqda"
        DONE = "done", "Bajarildi"

    # qaysi kasb bu bosqichga mos (positions bilan moslashtirish uchun)
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

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="production_tasks"
    )
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.SET_NULL,
        related_name="production_tasks",
        null=True,
        blank=True,
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    stage = models.CharField(max_length=20, choices=Stage.choices, default=Stage.OTHER)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.TODO)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="production_tasks",
        null=True,
        blank=True,
    )
    deadline = models.DateField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("status", "deadline", "-created_at")

    def __str__(self):
        return f"{self.title} ({self.get_status_display()})"


class Payslip(BaseModel):
    """Xodimning bir oylik ish haqi hisob-kitobi (docs/41 §20, §9 Employee Productivity).

    Jami = bazaviy oylik (hisoblash paytidagi maosh muhrlanadi) +
    (shu oyda bajarilgan vazifalar soni × bonus_per_task).
    "Hisoblash" tugmasi bosilganda yaratiladi/qayta hisoblanadi (to'lanmagan bo'lsa),
    to'langandan keyin o'zgarmas hisoblanadi.
    """

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="payslips"
    )
    employee = models.ForeignKey(
        "companies.Employee", on_delete=models.CASCADE, related_name="payslips"
    )
    period = models.DateField(help_text="Oyning 1-kuni, masalan 2026-07-01")
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tasks_completed = models.PositiveIntegerField(default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    bonus_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # Mahsulot workflow bosqichlarini yakunlagani uchun avtomatik hisoblangan haq
    # (docs: Payroll — "Every completed workflow step automatically generates earnings").
    workflow_earnings = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("employee", "period")
        ordering = ("-period", "employee")

    def __str__(self):
        return f"{self.employee} — {self.period:%Y-%m}"

    def recompute(self):
        """Berilgan oy uchun bajarilgan vazifalar sonidan bonusni qayta hisoblaydi."""
        start = self.period.replace(day=1)
        if start.month == 12:
            end = start.replace(year=start.year + 1, month=1)
        else:
            end = start.replace(month=start.month + 1)

        self.tasks_completed = ProductionTask.objects.filter(
            is_deleted=False,
            assigned_to_id=self.employee.user_id,
            status=ProductionTask.Status.DONE,
            completed_at__gte=start,
            completed_at__lt=end,
        ).count()
        self.base_salary = self.employee.base_salary
        self.bonus_per_task = self.employee.bonus_per_task
        self.bonus_amount = self.bonus_per_task * self.tasks_completed

        from apps.workflow.models import StepStatus, WorkflowStepInstance

        self.workflow_earnings = WorkflowStepInstance.objects.filter(
            is_deleted=False,
            employee_id=self.employee_id,
            status=StepStatus.COMPLETED,
            completed_at__gte=start,
            completed_at__lt=end,
        ).aggregate(total=Sum("cost"))["total"] or 0

        self.total_amount = self.base_salary + self.bonus_amount + self.workflow_earnings
