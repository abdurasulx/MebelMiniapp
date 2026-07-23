from django.contrib import admin

from .models import Model3D


@admin.register(Model3D)
class Model3DAdmin(admin.ModelAdmin):
    list_display = ("product", "status", "created_at")
    list_filter = ("status",)
