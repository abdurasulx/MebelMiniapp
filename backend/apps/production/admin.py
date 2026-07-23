from django.contrib import admin

from .models import Payslip, ProductionTask


@admin.register(ProductionTask)
class ProductionTaskAdmin(admin.ModelAdmin):
    list_display = ("title", "company", "stage", "status", "assigned_to", "deadline")
    list_filter = ("stage", "status")


@admin.register(Payslip)
class PayslipAdmin(admin.ModelAdmin):
    list_display = (
        "employee", "period", "base_salary", "tasks_completed",
        "bonus_amount", "total_amount", "is_paid",
    )
    list_filter = ("is_paid", "period")
