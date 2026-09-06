from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework import serializers

from common.serializers import visible_file_url

from .models import Design, DesignVersion

User = get_user_model()


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


class CreateCustomOrderOnSiteSerializer(serializers.Serializer):
    """Usta mijoz uyida turib to'g'ridan-to'g'ri individual (CUSTOM_PROJECT)
    buyurtma yaratganda yuboriladi — alohida "joy o'rganish" bosqichi
    endi yo'q (qarang services.create_custom_order_on_site). Joylashuv
    qurilmadan olinadi va soxta (mock) GPS aniqlansa buyurtma baribir
    yaratiladi, lekin firma egasiga xabar boradi (attendance check-in
    bilan bir xil `is_mock` naqshi, qarang apps.attendance.services)."""

    items = CustomOrderItemInputSerializer(many=True)
    # Mijoz doimiy qidiruvchi ID (worker_id) orqali topiladi — mijoz shu
    # orqali o'z ilovasida buyurtmani kuzatib borishi mumkin bo'ladi.
    # Endi survey.customer degan zaxira yo'q, shuning uchun majburiy.
    customer_worker_id = serializers.CharField()
    address = serializers.CharField(required=False, allow_blank=True, default="")
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True, default=None)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True, default=None)
    accuracy = serializers.FloatField(required=False, allow_null=True, default=None)
    is_mock = serializers.BooleanField(required=False, default=False)
    device_timestamp = serializers.DateTimeField(required=False, allow_null=True, default=None)
    platform = serializers.CharField(required=False, default="android")

    def validate_items(self, items):
        if not items:
            raise serializers.ValidationError("Kamida bitta band kerak")
        return items

    def validate_customer_worker_id(self, value):
        try:
            self._customer = User.objects.get(worker_id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Bu qidiruvchi ID bo'yicha foydalanuvchi topilmadi")
        return value
