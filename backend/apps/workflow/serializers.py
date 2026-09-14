from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import (
    STAGE_POSITION,
    ApplicationStatus,
    ProgressUpdate,
    StepApplication,
    StepStatus,
    WorkflowStep,
    WorkflowStepInstance,
    WorkType,
)


class WorkTypeSerializer(serializers.ModelSerializer):
    stage_display = serializers.CharField(source="get_stage_display", read_only=True, default=None)
    unit_display = serializers.CharField(source="get_unit_display", read_only=True)
    required_role_display = serializers.CharField(source="get_required_role_display", read_only=True, default=None)

    class Meta:
        model = WorkType
        fields = (
            "id", "stage", "stage_display", "name", "unit", "unit_display",
            "price_per_unit", "required_role", "required_role_display", "is_active", "created_at",
        )
        read_only_fields = ("id", "created_at")


class StepApplicationSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(source="employee.user.display_name", read_only=True)

    class Meta:
        model = StepApplication
        fields = ("id", "step", "employee", "employee_name", "status", "created_at", "decided_at")
        read_only_fields = ("id", "step", "employee", "status", "created_at", "decided_at")


class WorkflowStepSerializer(serializers.ModelSerializer):
    role_display = serializers.CharField(source="get_role_display", read_only=True)
    employee_name = serializers.CharField(source="employee.user.display_name", read_only=True)
    photo_requirement_display = serializers.CharField(
        source="get_photo_requirement_display", read_only=True
    )
    comment_requirement_display = serializers.CharField(
        source="get_comment_requirement_display", read_only=True
    )
    work_type_name = serializers.CharField(source="work_type.name", read_only=True, default=None)
    work_type_unit_display = serializers.CharField(source="work_type.get_unit_display", read_only=True, default=None)
    raw_material_name = serializers.CharField(source="raw_material.name", read_only=True, default=None)
    raw_material_unit = serializers.CharField(source="raw_material.unit", read_only=True, default=None)
    cutting_instruction = serializers.CharField(read_only=True)
    depends_on = serializers.PrimaryKeyRelatedField(
        many=True, queryset=WorkflowStep.objects.filter(is_deleted=False), required=False
    )

    class Meta:
        model = WorkflowStep
        fields = (
            "id", "product", "order_index", "name", "role", "role_display",
            "employee", "employee_name", "estimated_hours",
            "work_type", "work_type_name", "work_type_unit_display", "quantity", "cost",
            "raw_material", "raw_material_name", "raw_material_unit",
            "cut_piece_length", "cut_piece_width", "cut_piece_count", "cut_note", "cutting_instruction",
            "required_materials", "photo_requirement", "photo_requirement_display",
            "comment_requirement", "comment_requirement_display", "requires_approval",
            "depends_on", "created_at",
        )
        read_only_fields = ("id", "product", "created_at")


class ProgressUpdateSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("image",)
    image = serializers.ImageField(write_only=True, required=False, allow_null=True)
    image_url = serializers.SerializerMethodField()
    employee_name = serializers.CharField(source="employee.display_name", read_only=True)

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
    """Ishlab chiqarish vazifasi — avtomatik (retsept, `template_step` bor)
    yoki qo'lda (`template_step` bo'sh, avvalgi `ProductionTask`) yaratilgan.
    Qo'lda yaratishda faqat pastdagi `read_only_fields`dan tashqarisi
    to'ldiriladi — `company`/`template_step`/DAG-bog'liq maydonlar server
    tomonidan boshqariladi."""

    role_display = serializers.CharField(source="get_role_display", read_only=True)
    stage_display = serializers.CharField(source="get_stage_display", read_only=True, default=None)
    suggested_position = serializers.SerializerMethodField()
    employee_name = serializers.CharField(source="employee.user.display_name", read_only=True, default=None)
    photo_requirement_display = serializers.CharField(
        source="get_photo_requirement_display", read_only=True
    )
    comment_requirement_display = serializers.CharField(
        source="get_comment_requirement_display", read_only=True
    )
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    completed_by_name = serializers.CharField(source="completed_by.display_name", read_only=True, default=None)
    approved_by_name = serializers.CharField(source="approved_by.display_name", read_only=True, default=None)
    cancelled_by_name = serializers.CharField(source="cancelled_by.display_name", read_only=True, default=None)
    depends_on = serializers.PrimaryKeyRelatedField(many=True, read_only=True)
    is_available = serializers.BooleanField(read_only=True)
    is_manual = serializers.SerializerMethodField()
    updates = serializers.SerializerMethodField()
    order_display = serializers.SerializerMethodField()
    order_status = serializers.CharField(source="order.status", read_only=True, default=None)
    open_applications_count = serializers.SerializerMethodField()
    my_application_status = serializers.SerializerMethodField()
    product_name = serializers.CharField(source="product.name_uz", read_only=True, default=None)
    awaiting_approval = serializers.SerializerMethodField()

    def get_awaiting_approval(self, obj):
        # `status` allaqachon COMPLETED ("Bajarildi") deb ko'rsatilsa ham,
        # `requires_approval=True` bosqichlarda bu hali yakuniy emas — ish
        # haqi ham kreditlanmagan (qarang views.py::complete). Frontend/
        # mobil shu bayroqqa qarab "Admin tasdig'ini kutmoqda" deb
        # ko'rsatishi kerak (docs §4.1).
        return obj.status == StepStatus.COMPLETED and obj.requires_approval

    def get_open_applications_count(self, obj):
        # Faqat xodimi hali yo'q ("erkin") bosqich uchun ma'noli — firma
        # egasi/menejer shu son orqali "kimdir zayavka yubordimi" bilishi
        # uchun (qarang FirmaProduction.jsx).
        if obj.employee_id:
            return 0
        return sum(1 for a in obj.applications.all() if not a.is_deleted and a.status == ApplicationStatus.PENDING)

    def get_my_application_status(self, obj):
        # So'rovchi ustaning shu bosqichga o'zi yuborgan zayavkasi holati
        # (bo'lmasa None) — ilovada "Zayavka yuborildi (kutilmoqda)" kabi
        # holatni ko'rsatish uchun.
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return None
        for a in obj.applications.all():
            if not a.is_deleted and a.employee.user_id == request.user.id:
                return a.status
        return None

    def get_updates(self, obj):
        # `obj.updates` — filtrlanmagan teskari FK manager, is_deleted=False
        # bilan filtrlamasak o'chirilgan yangilanishlar abadiy ko'rinib
        # qolar edi (xuddi variant/lead-note/filial o'chirish xatolaridagi kabi).
        visible = [u for u in obj.updates.all() if not u.is_deleted]
        return ProgressUpdateSerializer(visible, many=True, context=self.context).data

    def get_order_display(self, obj):
        return f"#{str(obj.order_id)[:8]}" if obj.order_id else None

    def get_suggested_position(self, obj):
        return STAGE_POSITION.get(obj.stage)

    def get_is_manual(self, obj):
        return obj.template_step_id is None

    work_type_name = serializers.CharField(source="work_type.name", read_only=True, default=None)
    work_type_unit_display = serializers.CharField(source="work_type.get_unit_display", read_only=True, default=None)
    raw_material_name = serializers.CharField(source="raw_material.name", read_only=True, default=None)
    raw_material_unit = serializers.CharField(source="raw_material.unit", read_only=True, default=None)
    cutting_instruction = serializers.CharField(read_only=True)

    class Meta:
        model = WorkflowStepInstance
        fields = (
            "id", "company", "order", "order_display", "order_status", "template_step", "order_index",
            "is_manual", "name", "description", "product", "product_name",
            "stage", "stage_display", "suggested_position",
            "role", "role_display",
            "employee", "employee_name", "estimated_hours",
            "work_type", "work_type_name", "work_type_unit_display", "quantity", "cost",
            "raw_material", "raw_material_name", "raw_material_unit", "material_consumed",
            "cut_piece_length", "cut_piece_width", "cut_piece_count", "cut_note", "cutting_instruction",
            "required_materials",
            "photo_requirement", "photo_requirement_display",
            "comment_requirement", "comment_requirement_display", "depends_on",
            "requires_approval", "awaiting_approval",
            "status", "status_display", "is_available", "planned_start_date", "deadline",
            "started_at", "completed_at", "completed_by_name", "approved_at", "approved_by_name",
            "cancelled_at", "cancelled_by_name", "updates", "created_at",
            "open_applications_count", "my_application_status",
        )
        read_only_fields = (
            "id", "company", "order_index", "template_step", "depends_on", "is_available",
            "started_at", "completed_at", "approved_at", "cancelled_at", "created_at", "work_type", "quantity",
            "raw_material", "material_consumed",
            "cut_piece_length", "cut_piece_width", "cut_piece_count", "cut_note",
        )
