from rest_framework import serializers

from .models import Payslip


class PayslipSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.CharField(source="employee.user.email", read_only=True)
    positions = serializers.ListField(source="employee.positions", read_only=True)
    pay_type_display = serializers.CharField(source="get_pay_type_display", read_only=True)

    class Meta:
        model = Payslip
        fields = (
            "id", "employee", "employee_name", "employee_email", "positions",
            "period", "pay_type", "pay_type_display", "base_salary", "tasks_completed", "bonus_per_task",
            "bonus_amount", "commission_sales", "commission_amount", "manual_hours", "hourly_amount",
            "workflow_earnings", "kpi_met", "kpi_bonus_amount", "total_amount", "is_paid", "paid_at",
            "created_at",
        )
        read_only_fields = fields

    def get_employee_name(self, obj):
        return obj.employee.user.first_name or obj.employee.user.email
