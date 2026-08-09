from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import ProgressUpdate, WorkflowStep, WorkflowStepInstance


class WorkflowStepSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source="get_role_display", read_only=True)
    employee_name = serializers.CharField(source="employee.user.first_name", read_only=True)
    photo_requirement_display = serializers.CharField(
        source="get_photo_requirement_display", read_only=True
    )
    depends_on = serializers.PrimaryKeyRelatedField(
        many=True, queryset=WorkflowStep.objects.filter(is_deleted=False), required=False
    )

    class Meta:
        model = WorkflowStep
        fields = (
            "id", "product", "order_index", "name", "role", "role_display",
            "employee", "employee_name", "estimated_hours", "cost",
            "required_materials", "photo_requirement", "photo_requirement_display",
            "depends_on", "created_at",
        )
        read_only_fields = ("id", "product", "created_at")


class ProgressUpdateSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("image",)
    image = serializers.ImageField(write_only=True, required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()
    employee_name = serializers.CharField(source="employee.first_name", read_only=True)

    class Meta:
        model = ProgressUpdate
        fields = (
            "id", "step", "image", "image_url", "comment", "employee",
            "employee_name", "is_completion", "created_at",
        )
        read_only_fields = ("id", "step", "employee", "employee_name", "is_completion", "created_at")

    def get_image_url(self, obj):
        return visible_file_url(obj, "image", self.context.get("request"))


class WorkflowStepInstanceSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source="get_role_display", read_only=True)
    employee_name = serializers.CharField(source="employee.user.first_name", read_only=True)
    photo_requirement_display = serializers.CharField(
        source="get_photo_requirement_display", read_only=True
    )
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    completed_by_name = serializers.CharField(source="completed_by.first_name", read_only=True)
    depends_on = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    is_available = serializers.BooleanField(read_only=True)
    updates = serializers.SerializerMethodField()
    order_display = serializers.SerializerMethodField()
    order_status = serializers.CharField(source="order.status", read_only=True)

    def get_updates(self, obj):
        # `obj.updates` — filtrlanmagan teskari FK manager, is_deleted=False
        # bilan filtrlamasak o'chirilgan yangilanishlar abadiy ko'rinib
        # qolar edi (xuddi variant/lead-note/filial o'chirish xatolaridagi kabi).
        visible = [u for u in obj.updates.all() if not u.is_deleted]
        return ProgressUpdateSerializer(visible, many=True, context=self.context).data

    def get_order_display(self, obj):
        return f"#{str(obj.order_id)[:8]}"

    class Meta:
        model = WorkflowStepInstance
        fields = (
            "id", "order", "order_display", "order_status", "template_step", "order_index",
            "name", "role", "role_display",
            "employee", "employee_name", "estimated_hours", "cost", "required_materials",
            "photo_requirement", "photo_requirement_display", "depends_on",
            "status", "status_display", "is_available",
            "started_at", "completed_at", "completed_by_name", "updates", "created_at",
        )
        read_only_fields = fields
