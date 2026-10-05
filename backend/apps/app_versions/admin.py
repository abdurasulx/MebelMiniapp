from django.contrib import admin

from .models import AppVersion


@admin.register(AppVersion)
class AppVersionAdmin(admin.ModelAdmin):
    list_display = ("version", "platform", "status", "force_update", "release_date", "updated_at")
    list_filter = ("platform", "status")
    search_fields = ("version",)
    ordering = ("-created_at",)

    def has_delete_permission(self, request, obj=None):
        return False  # tarix saqlanishi shart
