from rest_framework import serializers

from .models import AttendanceEditLog, AttendanceRecord, Workplace


class WorkplaceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Workplace
        fields = ("id", "company", "name", "latitude", "longitude", "radius_meters", "is_active")
        read_only_fields = ("id", "company")


class AttendanceRecordSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(source="employee.user.get_full_name", read_only=True)
    workplace_name = serializers.CharField(source="workplace.name", read_only=True, default=None)

    class Meta:
        model = AttendanceRecord
        fields = (
            "id", "employee", "employee_name", "workplace", "workplace_name", "action",
            "latitude", "longitude", "accuracy", "server_timestamp", "device_timestamp",
            "is_mock", "integrity_result", "distance_meters", "status", "reason", "created_at",
        )
        read_only_fields = fields


class AttendanceCheckInSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    accuracy = serializers.DecimalField(max_digits=8, decimal_places=2, required=False, allow_null=True)
    device_timestamp = serializers.DateTimeField(required=False, allow_null=True)
    is_mock = serializers.BooleanField(default=False)
    integrity_token = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    platform = serializers.ChoiceField(choices=("android", "ios"), default="android")


class AttendanceEditLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = AttendanceEditLog
        fields = ("id", "record", "changed_by", "old_value", "new_value", "reason", "created_at")
        read_only_fields = fields
