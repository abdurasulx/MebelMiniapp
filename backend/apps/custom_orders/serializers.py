from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Design, DesignVersion, SiteSurvey, SiteSurveyMedia

User = get_user_model()


class SiteSurveyMediaSerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("file",)
    file = serializers.FileField(write_only=True)
    file_url = serializers.SerializerMethodField()

    class Meta:
        model = SiteSurveyMedia
        fields = ("id", "survey", "file", "file_url", "media_type", "caption", "created_at")
        read_only_fields = ("id", "survey", "created_at")

    def get_file_url(self, obj):
        return visible_file_url(obj, "file", self.context.get("request"))


class SiteSurveySerializer(serializers.ModelSerializer):
    # Xodimlar taklif qilishdagi bir xil naqsh (qarang EmployeeInvitationSerializer):
    # mijoz doimiy qidiruvchi ID (worker_id) orqali topiladi, UUID emas.
    # Ixtiyoriy — admin tayinlash paytida mijozni bilmasligi mumkin (masalan
    # murojaat/lead orqali), usta keyinroq (buyurtma yaratayotganda) ham
    # kiritishi mumkin (qarang CreateCustomOrderSerializer).
    customer_worker_id = serializers.CharField(write_only=True, required=False, allow_blank=True)
    assigned_master_name = serializers.CharField(source="assigned_master.user.first_name", read_only=True)
    customer_name = serializers.CharField(source="customer.first_name", read_only=True, default=None)
    customer_worker_id_display = serializers.CharField(source="customer.worker_id", read_only=True, default=None)
    company_slug = serializers.CharField(source="company.slug", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    media = SiteSurveyMediaSerializer(many=True, read_only=True)

    class Meta:
        model = SiteSurvey
        fields = (
            "id", "company", "company_slug", "customer_worker_id", "customer_name", "customer_worker_id_display",
            "assigned_master", "assigned_master_name",
            "address", "latitude", "longitude", "notes", "status", "status_display",
            "order", "media", "created_at",
        )
        read_only_fields = ("id", "company", "status", "order", "created_at")

    def validate_customer_worker_id(self, value):
        if not value:
            self._customer = None
            return value
        try:
            self._customer = User.objects.get(worker_id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Bu qidiruvchi ID bo'yicha foydalanuvchi topilmadi")
        return value

    def create(self, validated_data):
        validated_data.pop("customer_worker_id", None)
        return SiteSurvey.objects.create(customer=getattr(self, "_customer", None), **validated_data)


class DesignVersionSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source="created_by.user.first_name", read_only=True, default=None)
    glb_url = serializers.SerializerMethodField()
    usdz_url = serializers.SerializerMethodField()
    is_approved = serializers.SerializerMethodField()

    class Meta:
        model = DesignVersion
        fields = (
            "id", "design", "version_number", "notes", "created_by", "created_by_name",
            "glb_url", "usdz_url", "is_approved", "created_at",
        )
        read_only_fields = ("id", "design", "version_number", "created_at")

    def get_glb_url(self, obj):
        model = getattr(obj, "model3d", None)
        return visible_file_url(model, "glb_file", self.context.get("request")) if model else None

    def get_usdz_url(self, obj):
        model = getattr(obj, "model3d", None)
        return visible_file_url(model, "usdz_file", self.context.get("request")) if model else None

    def get_is_approved(self, obj):
        return obj.design.approved_version_id == obj.id


class DesignSerializer(serializers.ModelSerializer):
    versions = DesignVersionSerializer(many=True, read_only=True)
    approved_by_name = serializers.CharField(source="approved_by.first_name", read_only=True, default=None)

    class Meta:
        model = Design
        fields = (
            "id", "order", "approved_version", "approved_by", "approved_by_name", "approved_at",
            "production_sequence", "versions", "created_at",
        )
        read_only_fields = ("id", "order", "approved_version", "approved_by", "approved_at", "created_at")


class CustomOrderItemInputSerializer(serializers.Serializer):
    product = serializers.UUIDField()
    variant = serializers.UUIDField(required=False, allow_null=True)
    width = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    height = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    depth = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    quantity = serializers.IntegerField(min_value=1, default=1)
    is_custom_size = serializers.BooleanField(default=False)


class CreateCustomOrderSerializer(serializers.Serializer):
    items = CustomOrderItemInputSerializer(many=True)
    # Usta mijoz bilan uchrashganda uning ilova ID'sini shu yerda kiritishi
    # mumkin — mijoz o'z ilovasida buyurtmani kuzatib borishi uchun
    # (survey.customer hali bo'lmasa majburiy, bo'lsa ixtiyoriy — berilsa
    # o'rniga qo'yiladi).
    customer_worker_id = serializers.CharField(required=False, allow_blank=True)

    def validate_items(self, items):
        if not items:
            raise serializers.ValidationError("Kamida bitta band kerak")
        return items

    def validate_customer_worker_id(self, value):
        if not value:
            return value
        try:
            self._customer = User.objects.get(worker_id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Bu qidiruvchi ID bo'yicha foydalanuvchi topilmadi")
        return value
