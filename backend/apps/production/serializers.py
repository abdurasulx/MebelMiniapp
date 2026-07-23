from rest_framework import serializers

from .models import Payslip, ProductionTask


class ProductionTaskSerializer(serializers.ModelSerializer):
    stage_display = serializers.CharField(source="get_stage_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    assigned_to_name = serializers.SerializerMethodField()
    order_display = serializers.SerializerMethodField()
    suggested_position = serializers.SerializerMethodField()

    class Meta:
        model = ProductionTask
        fields = (
            "id", "company", "order", "order_display", "title", "description",
            "stage", "stage_display", "suggested_position",
            "status", "status_display", "assigned_to", "assigned_to_name",
            "deadline", "completed_at", "created_at",
        )
        read_only_fields = ("id", "company", "completed_at", "created_at")

    def get_assigned_to_name(self, obj):
        if obj.assigned_to is None:
            return None
        return obj.assigned_to.first_name or obj.assigned_to.email

    def get_order_display(self, obj):
        if obj.order is None:
            return None
        return f"#{str(obj.order.id)[:8]}"

    def get_suggested_position(self, obj):
        return ProductionTask.STAGE_POSITION.get(obj.stage)


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
