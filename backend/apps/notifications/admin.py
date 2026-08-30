from django.contrib import admin
from django.utils import timezone

from .models import Notification, PushDevice


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "notif_type", "title", "is_read", "created_at")
    list_filter = ("notif_type", "is_read")
    search_fields = ("recipient__email", "title", "body")


@admin.register(PushDevice)
class PushDeviceAdmin(admin.ModelAdmin):
    list_display = (
        "user", "device_name", "platform", "vcode", "is_active", "last_seen", "revoked_at", "created_at",
    )
    list_filter = ("platform", "is_active")
    search_fields = ("user__email", "device_id", "device_name", "token")
    actions = ("revoke_devices", "unrevoke_devices")

    @admin.action(description="Tanlangan qurilmalarni bekor qilish (revoke)")
    def revoke_devices(self, request, queryset):
        queryset.update(is_active=False, revoked_at=timezone.now())

    @admin.action(description="Tanlangan qurilmalarni qayta faollashtirish")
    def unrevoke_devices(self, request, queryset):
        queryset.update(is_active=True, revoked_at=None)
