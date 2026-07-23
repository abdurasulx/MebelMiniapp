from django.contrib import admin

from .models import Category, Product, ProductImage, Variant


class VariantInline(admin.TabularInline):
    model = Variant
    extra = 0


class ProductImageInline(admin.TabularInline):
    model = ProductImage
    extra = 0


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name_uz", "name_ru", "parent")
    prepopulated_fields = {"slug": ("name_uz",)}


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name_uz", "company", "category", "is_published", "created_at")
    list_filter = ("is_published", "category")
    search_fields = ("name_uz", "name_ru")
    inlines = (VariantInline, ProductImageInline)
