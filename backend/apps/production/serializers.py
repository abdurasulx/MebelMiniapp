from rest_framework import serializers

from .models import Payslip


class PayslipSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.CharField(source="employee.user.email", read_only=True)
    positions = serializers.ListField(source="employee.positions", read_only=True)

    class Meta:
        model = Payslip
        fields = (
            "id", "employee", "employee_name", "employee_email", "positions",
            "period", "base_salary", "tasks_completed", "bonus_per_task",
            "bonus_amount", "workflow_earnings", "total_amount", "is_paid", "paid_at", "created_at",
        )
        read_only_fields = fields

    def get_employee_name(self, obj):
        return obj.employee.user.first_name or obj.employee.user.email
