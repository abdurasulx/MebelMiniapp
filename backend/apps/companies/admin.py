from django.contrib import admin

from .models import Company, CompanyDeliverySettings, Employee, Review, ReviewReport, TariffPlan, UserBlock


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
    list_display = ("company", "customer", "rating", "is_hidden", "created_at")
    list_filter = ("is_hidden", "rating")
    search_fields = ("comment", "company__name")
    actions = ("hide", "unhide")

    @admin.action(description="Tanlangan sharhlarni yashirish")
    def hide(self, request, queryset):
        queryset.update(is_hidden=True, hidden_reason="Admin tomonidan")

    @admin.action(description="Tanlangan sharhlarni qaytarish")
    def unhide(self, request, queryset):
        queryset.update(is_hidden=False, hidden_reason="")


@admin.register(ReviewReport)
class ReviewReportAdmin(admin.ModelAdmin):
    list_display = ("review", "reporter", "reason", "status", "created_at")
    list_filter = ("status", "reason")
    actions = ("hide_reviewed", "dismiss")

    @admin.action(description="Sharhni yashirish va shikoyatni 'choralar ko'rildi' deb belgilash")
    def hide_reviewed(self, request, queryset):
        for report in queryset.select_related("review"):
            report.review.is_hidden = True
            report.review.hidden_reason = f"Shikoyat: {report.reason}"
            report.review.save(update_fields=["is_hidden", "hidden_reason", "updated_at"])
        queryset.update(status=ReviewReport.Status.ACTIONED)

    @admin.action(description="Shikoyatni rad etish")
    def dismiss(self, request, queryset):
        queryset.update(status=ReviewReport.Status.DISMISSED)


@admin.register(UserBlock)
class UserBlockAdmin(admin.ModelAdmin):
    list_display = ("blocker", "blocked", "created_at")
