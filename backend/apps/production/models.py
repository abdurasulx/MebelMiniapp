from django.db import models
from django.db.models import Sum

from common.models import BaseModel


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

        from apps.workflow.models import StepStatus, WorkflowStepInstance

        completed = WorkflowStepInstance.objects.filter(
            is_deleted=False,
            employee_id=self.employee_id,
            status=StepStatus.COMPLETED,
            completed_at__gte=start,
            completed_at__lt=end,
        )

        # Qo'lda yaratilgan (retseptga bog'liq bo'lmagan, template_step=None)
        # vazifalar donasiga qarab flat bonus beriladi — avtomatik retsept
        # bosqichlari esa `cost` orqali (pastda) hisoblanadi, aks holda ikkalasi
        # bir xil bosqich uchun ikki marta haq to'lagan bo'lardi.
        self.tasks_completed = completed.filter(template_step__isnull=True).count()
        self.base_salary = self.employee.base_salary
        self.bonus_per_task = self.employee.bonus_per_task
        self.bonus_amount = self.bonus_per_task * self.tasks_completed

        self.workflow_earnings = completed.aggregate(total=Sum("cost"))["total"] or 0

        self.total_amount = self.base_salary + self.bonus_amount + self.workflow_earnings
