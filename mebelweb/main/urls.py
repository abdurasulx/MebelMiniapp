from django.urls import path
from . import views
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('', views.index, name='index'),
    path('login/', views.telegram_login, name='login'),
    path('register/', views.register, name='register'),
    path('logout/', views.logout_view, name='logout'),
    path('orders/', views.orders_view, name='orders'),
    path('category/<int:cat_id>/', views.category_view, name='category'),
    path('product/<int:prod_id>/', views.product_view, name='product'),
    path('product/<int:prod_id>/variant/<int:var_id>/', views.variant_view, name='variant'),
    path('cart/', views.cart_view, name='cart'),
    path('add-to-cart/', views.add_to_cart, name='add_to_cart'),
    path('update-cart/', views.update_cart, name='update_cart'),
    path('profile/', views.profile_view, name='profile'),
    path('statistics/', views.admin_stats, name='statistics'),
    path('products/', views.admin_products, name='admin_products'),
    path('products/add/', views.admin_product_add, name='admin_product_add'),
    path('products/<int:pk>/edit/', views.admin_product_edit, name='admin_product_edit'),
    path('products/<int:pk>/delete/', views.admin_product_delete, name='admin_product_delete'),
    path('categories/', views.admin_categories, name='admin_categories'),
    path('categories/add/', views.admin_category_add, name='admin_category_add'),
    path('categories/<int:pk>/edit/', views.admin_category_edit, name='admin_category_edit'),
    path('categories/<int:pk>/delete/', views.admin_category_delete, name='admin_category_delete'),
    path('variant/<int:variant_id>/add-image/', views.add_variant_image, name='add_variant_image'),
    path('variant-image/<int:image_id>/delete/', views.delete_variant_image, name='delete_variant_image'),
    path('place-order/', views.place_order, name='place_order'),
    path('order/<int:pk>/', views.order_detail, name='order_detail'),
    path('order/<int:pk>/json/', views.order_detail_json, name='order_detail_json'),
    path('order/<int:pk>/update-status/', views.order_update_status, name='order_update_status'),
]
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)