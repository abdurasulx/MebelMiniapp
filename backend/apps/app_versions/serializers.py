from rest_framework import serializers

from . import versioning
from .models import AppVersion


class AppVersionSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    platform_display = serializers.CharField(source="get_platform_display", read_only=True)

    class Meta:
        model = AppVersion
        fields = (
            "id", "version", "platform", "platform_display", "status", "status_display",
            "force_update", "orders_enabled", "store_url", "update_message", "release_date",
            "created_at", "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_version(self, value):
        parsed = versioning.parse_version(value, strict=True)
        if parsed is None:
            raise serializers.ValidationError("Versiya major.minor.patch ko'rinishida bo'lishi kerak (masalan 2.4.0)")
        return versioning.format_version(parsed)

    def validate(self, attrs):
        # BLOCKED versiya oddiy API'dan foydalana olmaydi — har doim majburiy.
        status = attrs.get("status", getattr(self.instance, "status", AppVersion.STATUS_ACTIVE))
        if status == AppVersion.STATUS_BLOCKED:
            attrs["force_update"] = True
        return attrs
