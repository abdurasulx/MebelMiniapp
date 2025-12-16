from django.contrib import admin
from .models import Category, Product, Variant, VariantImage, Order, OrderItem

class VariantImageInline(admin.TabularInline):
    model = VariantImage
    extra = 1

class VariantInline(admin.TabularInline):
    model = Variant
    extra = 1
    show_change_link = True

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name_uz', 'name_ru')

@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name_uz', 'category')
    search_fields = ('name_uz',)
    list_filter = ('category',)
    inlines = [VariantInline]

@admin.register(Variant)
class VariantAdmin(admin.ModelAdmin):
    list_display = ('product', 'name', 'base_price', 'width', 'height', 'depth')
    list_editable = ('name', 'base_price')
    list_filter = ('product__category', 'product')
    search_fields = ('name', 'product__name_uz')
    inlines = [VariantImageInline]

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'total_price', 'status', 'created_at')
    list_filter = ('status', 'created_at', 'user')
    search_fields = ('id', 'user__username', 'user__first_name')
    readonly_fields = ('created_at',)

@admin.register(OrderItem)
class OrderItemAdmin(admin.ModelAdmin):
    list_display = ('id', 'variant', 'quantity', 'price')
    list_filter = ('variant',)
    search_fields = ('variant__name',)

@admin.register(VariantImage)
class VariantImageAdmin(admin.ModelAdmin):
    list_display = ('variant', 'image')