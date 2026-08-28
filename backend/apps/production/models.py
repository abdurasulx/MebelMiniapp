from django.db import models
from django.db.models import Sum

from apps.companies.models import PayType
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
    pay_type = models.CharField(max_length=20, choices=PayType.choices, blank=True)
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tasks_completed = models.PositiveIntegerField(default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    bonus_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # Komissiyali xodim uchun — shu oyda `sold_by`si shu xodim bo'lgan
    # yakunlangan buyurtmalar summasi va undan hisoblangan komissiya.
    commission_sales = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    commission_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # Soatbay xodim uchun — firma "Hisoblash"dan oldin qo'lda kiritadi (avtomatik
    # vaqt hisoblagich hozircha yo'q), keyingi recompute() bu qiymatni saqlab qoladi.
    manual_hours = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    hourly_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # Mahsulot workflow bosqichlarini yakunlagani uchun avtomatik hisoblangan haq
    # (docs: Payroll — "Every completed workflow step automatically generates earnings").
    workflow_earnings = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    # KPI maqsadiga erishilgan bo'lsa (qarang PositionPayStandard), shu
    # multiplikator asosidagi qo'shimcha bonus.
    kpi_met = models.BooleanField(default=False)
    kpi_bonus_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("employee", "period")
        ordering = ("-period", "employee")

    def __str__(self):
        return f"{self.employee} — {self.period:%Y-%m}"

    def recompute(self):
        """Berilgan oy uchun xodimning `pay_type`iga mos summani va KPI
        bonusini qayta hisoblaydi. To'rtta to'lov turi qo'llab-quvvatlanadi:
        faqat oylik, oylik+vazifa bonusi, komissiya (% sotuvdan) va soatbay
        (`manual_hours` — bu maydon shu funksiya tomonidan o'zgartirilmaydi,
        firma tomonidan alohida kiritiladi/PATCH qilinadi)."""
        start = self.period.replace(day=1)
        if start.month == 12:
            end = start.replace(year=start.year + 1, month=1)
        else:
            end = start.replace(month=start.month + 1)

        from apps.orders.models import Order
        from apps.workflow.models import StepStatus, WorkflowStepInstance

        employee = self.employee
        self.pay_type = employee.pay_type

        completed = WorkflowStepInstance.objects.filter(
            is_deleted=False,
            employee_id=self.employee_id,
            status__in=(StepStatus.COMPLETED, StepStatus.APPROVED),
            completed_at__gte=start,
            completed_at__lt=end,
        )

        # Qo'lda yaratilgan (retseptga bog'liq bo'lmagan, template_step=None)
        # vazifalar donasiga qarab flat bonus beriladi — avtomatik retsept
        # bosqichlari esa `cost` orqali (pastda) hisoblanadi, aks holda ikkalasi
        # bir xil bosqich uchun ikki marta haq to'lagan bo'lardi.
        self.tasks_completed = completed.filter(template_step__isnull=True).count()
        self.workflow_earnings = completed.aggregate(total=Sum("cost"))["total"] or 0

        self.base_salary = employee.base_salary if self.pay_type in (PayType.FIXED, PayType.FIXED_BONUS) else 0
        self.bonus_per_task = employee.bonus_per_task
        self.bonus_amount = (
            self.bonus_per_task * self.tasks_completed if self.pay_type == PayType.FIXED_BONUS else 0
        )

        if self.pay_type == PayType.COMMISSION:
            sold = Order.objects.filter(
                is_deleted=False,
                sold_by_id=self.employee_id,
                status=Order.Status.COMPLETED,
                updated_at__gte=start,
                updated_at__lt=end,
            )
            self.commission_sales = sold.aggregate(total=Sum("total_price"))["total"] or 0
            self.commission_amount = self.commission_sales * employee.commission_percent / 100
        else:
            self.commission_sales = 0
            self.commission_amount = 0

        self.hourly_amount = (
            employee.hourly_rate * self.manual_hours if self.pay_type == PayType.HOURLY else 0
        )

        pay_component = self.base_salary + self.bonus_amount + self.commission_amount + self.hourly_amount

        self.kpi_met, self.kpi_bonus_amount = self._compute_kpi_bonus(
            start, end, completed, pay_component + self.workflow_earnings
        )

        self.total_amount = pay_component + self.workflow_earnings + self.kpi_bonus_amount

    def _compute_kpi_bonus(self, start, end, completed_qs, base_for_bonus):
        """Xodimning (kompaniya standarti bo'lmasa — platforma standarti)
        birinchi lavozimiga mos `PositionPayStandard`dan KPI maqsadini oladi.
        Ikkala maqsad ham (agar berilgan bo'lsa) bajarilgan bo'lsagina bonus
        qo'llanadi; hech qaysi maqsad berilmagan bo'lsa, multiplikator
        qo'llanmaydi (faqat kuzatuv uchun standart mavjud bo'lishi mumkin)."""
        from apps.companies.models import PositionPayStandard

        employee = self.employee
        if not employee.positions:
            return False, 0
        position = employee.positions[0]
        standard = (
            PositionPayStandard.objects.filter(company_id=employee.company_id, position=position).first()
            or PositionPayStandard.objects.filter(company__isnull=True, position=position).first()
        )
        if standard is None:
            return False, 0

        targets_set = False
        met = True
        if standard.kpi_target_tasks_per_month is not None:
            targets_set = True
            if self.tasks_completed < standard.kpi_target_tasks_per_month:
                met = False
        if standard.kpi_target_on_time_percent is not None:
            targets_set = True
            with_deadline = completed_qs.exclude(deadline__isnull=True)
            total = with_deadline.count()
            if total == 0:
                on_time_percent = 100
            else:
                on_time = sum(1 for step in with_deadline if step.completed_at.date() <= step.deadline)
                on_time_percent = (on_time / total) * 100
            if on_time_percent < standard.kpi_target_on_time_percent:
                met = False

        if not targets_set or not met or standard.kpi_bonus_multiplier <= 1:
            return (targets_set and met), 0

        bonus = base_for_bonus * (standard.kpi_bonus_multiplier - 1)
        return True, bonus
