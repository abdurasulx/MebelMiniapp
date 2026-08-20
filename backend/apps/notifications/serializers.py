from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    notif_type_display = serializers.CharField(source="get_notif_type_display", read_only=True)

    class Meta:
        model = Notification
        fields = (
            "id", "notif_type", "notif_type_display", "title", "body",
            "order", "workflow_instance", "is_read", "created_at",
        )
        read_only_fields = fields
