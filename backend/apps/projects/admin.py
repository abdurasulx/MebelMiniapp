from django.contrib import admin

from .models import DetailAsset, Project, ProjectItem


@admin.register(DetailAsset)
class DetailAssetAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "company")
    list_filter = ("category",)
    search_fields = ("name",)


class ProjectItemInline(admin.TabularInline):
    model = ProjectItem
    extra = 0


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ("name", "customer", "is_paid", "is_public", "created_at")
    list_filter = ("is_paid", "is_public")
    inlines = [ProjectItemInline]
