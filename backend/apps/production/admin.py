from django.contrib import admin

from .models import Payslip, PayslipPayment


@admin.register(Payslip)
class PayslipAdmin(admin.ModelAdmin):
    list_display = (
        "employee", "period", "base_salary", "tasks_completed",
        "bonus_amount", "total_amount", "is_paid",
    )
    list_filter = ("is_paid", "period")


@admin.register(PayslipPayment)
class PayslipPaymentAdmin(admin.ModelAdmin):
    list_display = ("payslip", "kind", "amount", "paid_at", "recorded_by")
    list_filter = ("kind",)
