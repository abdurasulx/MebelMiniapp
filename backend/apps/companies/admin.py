from django.contrib import admin

from .models import Branch, Company, Employee, Review


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    list_display = ("name", "owner", "is_active", "created_at")
    search_fields = ("name",)
    prepopulated_fields = {"slug": ("name",)}


@admin.register(Branch)
class BranchAdmin(admin.ModelAdmin):
    list_display = ("company", "viloyat", "is_main", "address")
    list_filter = ("viloyat", "is_main")


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ("user", "company", "positions", "is_active")


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ("company", "customer", "rating", "created_at")
    list_filter = ("rating",)
