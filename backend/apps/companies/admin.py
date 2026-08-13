from django.contrib import admin

from .models import Company, Employee, PositionPayStandard, Review


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "viloyat", "is_active", "created_at")
    search_fields = ("name",)
    list_filter = ("viloyat",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ("user", "company", "positions", "is_active")


@admin.register(PositionPayStandard)
class PositionPayStandardAdmin(admin.ModelAdmin):
    list_display = ("position", "company", "pay_type", "min_salary", "max_salary", "kpi_bonus_multiplier")
    list_filter = ("position", "pay_type")


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("company", "customer", "rating", "created_at")
    list_filter = ("rating",)
