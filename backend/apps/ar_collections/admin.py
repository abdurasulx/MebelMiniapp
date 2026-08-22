from django.contrib import admin

from .models import ARCollection, ARCollectionItem


@admin.register(ARCollection)
class ARCollectionAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "created_at")
    search_fields = ("name", "owner__email")


@admin.register(ARCollectionItem)
class ARCollectionItemAdmin(admin.ModelAdmin):
    list_display = ("collection", "product", "variant", "created_at")
