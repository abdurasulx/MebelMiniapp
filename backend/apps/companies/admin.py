from django.contrib import admin

from .models import Company, Employee, PositionPayStandard, Review, TariffPlan


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "viloyat", "tariff_plan", "is_active", "created_at")
    search_fields = ("name",)
    list_filter = ("viloyat",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(TariffPlan)
class TariffPlanAdmin(admin.ModelAdmin):
    list_display = ("name", "price_per_employee", "price_per_product", "currency", "is_active")
    list_filter = ("is_active", "currency")


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
