from django.contrib import admin

from .models import Company, CompanyDeliverySettings, Employee, Review, TariffPlan


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "viloyat", "tariff_plan", "is_active", "is_verified", "created_at")
    search_fields = ("name",)
    list_filter = ("viloyat", "is_verified")
    prepopulated_fields = {"slug": ("name",)}
    # Sana avtomatik (Company.save): tasdiqlanganda belgilanadi, bekor qilinganda tozalanadi.
    readonly_fields = ("verified_at",)
    actions = ("mark_verified", "mark_unverified")

    @admin.action(description="Tanlangan firmalarni tasdiqlash")
    def mark_verified(self, request, queryset):
        for company in queryset:
            company.set_verified(True)

    @admin.action(description="Tanlangan firmalar tasdig'ini bekor qilish")
    def mark_unverified(self, request, queryset):
        for company in queryset:
            company.set_verified(False)


@admin.register(CompanyDeliverySettings)
class CompanyDeliverySettingsAdmin(admin.ModelAdmin):
    list_display = ("company", "free_delivery", "delivery_price", "delivery_min_days", "delivery_max_days")


@admin.register(TariffPlan)
class TariffPlanAdmin(admin.ModelAdmin):
    list_display = ("name", "price_per_employee", "price_per_product", "currency", "is_active")
    list_filter = ("is_active", "currency")


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ("user", "company", "positions", "is_active")


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("company", "customer", "rating", "created_at")
    list_filter = ("rating",)
