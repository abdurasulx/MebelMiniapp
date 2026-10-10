from django.contrib import admin

from .models import (
    Category,
    Product,
    ProductImage,
    RenderedImage,
    RenderJob,
    ShowcaseImage,
    ShowcaseProduct,
    Variant,
)


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
    list_display = ("name_uz", "company", "category", "is_published", "render_status", "needs_moderation", "created_at")
    list_filter = ("is_published", "category", "render_status", "needs_moderation")
    search_fields = ("name_uz", "name_ru")
    inlines = (VariantInline, ProductImageInline)


class ShowcaseImageInline(admin.TabularInline):
    model = ShowcaseImage
    extra = 0


@admin.register(ShowcaseProduct)
class ShowcaseProductAdmin(admin.ModelAdmin):
    list_display = ("__str__", "category", "price_from", "sort_order", "is_published")
    list_filter = ("is_published", "category")
    inlines = (ShowcaseImageInline,)


@admin.register(RenderJob)
class RenderJobAdmin(admin.ModelAdmin):
    list_display = ("product", "status", "attempts", "duration_s", "finished_at")
    list_filter = ("status",)
    readonly_fields = ("error",)


@admin.register(RenderedImage)
class RenderedImageAdmin(admin.ModelAdmin):
    list_display = ("product", "variant_name", "shot", "sort_order")
    list_filter = ("shot",)
