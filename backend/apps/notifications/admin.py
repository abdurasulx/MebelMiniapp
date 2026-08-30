from django.contrib import admin

from .models import Notification, PushDevice


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "notif_type", "title", "is_read", "created_at")
    list_filter = ("notif_type", "is_read")
    search_fields = ("recipient__email", "title", "body")


@admin.register(PushDevice)
class PushDeviceAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "token", "created_at")
    list_filter = ("platform",)
    search_fields = ("user__email", "token")
