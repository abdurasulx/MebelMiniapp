from django.db.models import Count, Q
from rest_framework import permissions, viewsets
from rest_framework.exceptions import PermissionDenied

from apps.companies.views import user_company

from .models import Category, Product, ProductImage, Variant
from .serializers import (
    CategorySerializer,
    ProductImageSerializer,
    ProductSerializer,
    VariantSerializer,
)


class IsPlatformAdminOrReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user.is_authenticated and request.user.role == "platform_admin"


class CategoryViewSet(viewsets.ModelViewSet):
    serializer_class = CategorySerializer
    permission_classes = (IsPlatformAdminOrReadOnly,)
    lookup_field = "slug"

    def get_queryset(self):
        return Category.objects.filter(is_deleted=False)


def can_manage(user, company):
    """Mahsulotni boshqarish huquqi: platforma admini, kompaniya egasi yoki faol xodimi."""
    if not user.is_authenticated:
        return False
    if user.role == "platform_admin":
        return True
    own = user_company(user)
    return own is not None and own.id == company.id


class IsProductManagerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return can_manage(request.user, obj.company)


class ProductViewSet(viewsets.ModelViewSet):
    """Marketplace: hamma published mahsulotlarni ko'radi; ega/xodim o'zinikini boshqaradi."""

    serializer_class = ProductSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly, IsProductManagerOrReadOnly)

    def get_queryset(self):
        qs = Product.objects.filter(is_deleted=False).select_related(
            "company", "category"
        ).prefetch_related("variants", "images")
        user = self.request.user
        if user.is_authenticated:
            if user.role == "platform_admin":
                return qs
            company = user_company(user)
            if company:
                qs = qs.filter(Q(is_published=True) | Q(company=company))
            else:
                qs = qs.filter(is_published=True)
        else:
            qs = qs.filter(is_published=True)
        company_slug = self.request.query_params.get("company")
        if company_slug:
            qs = qs.filter(company__slug=company_slug)
        # Bir nechta viloyatda filiali bor firmalar uchun: foydalanuvchi
        # joylashgan viloyatga tegishli (yoki filialsiz, ya'ni hammaga umumiy)
        # mahsulotlarnigina ko'rsatish.
        viloyat = self.request.query_params.get("viloyat")
        if viloyat:
            qs = qs.filter(Q(branch__viloyat=viloyat) | Q(branch__isnull=True))
        ordering = self.request.query_params.get("ordering")
        if ordering == "top":
            qs = qs.annotate(like_count=Count("liked_by")).order_by("-like_count", "-created_at")
        return qs

    def perform_create(self, serializer):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Avval kompaniya yarating yoki kompaniyaga xodim bo'ling")
        serializer.save(company=company)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ProductImageViewSet(viewsets.ModelViewSet):
    """Mahsulot galereyasi — bitta asosiy rasmdan tashqari qo'shimcha rasmlar
    (masalan "loyiha mahsuloti" — butun xona/loyihaning bir nechta burchagi)."""

    serializer_class = ProductImageSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        return ProductImage.objects.filter(
            is_deleted=False, product_id=self.kwargs["product_pk"]
        ).order_by("sort_order")

    def _get_product(self):
        product = Product.objects.get(pk=self.kwargs["product_pk"], is_deleted=False)
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product

    def perform_create(self, serializer):
        serializer.save(product=self._get_product())

    def perform_update(self, serializer):
        self._get_product()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_product()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class VariantViewSet(viewsets.ModelViewSet):
    serializer_class = VariantSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        return Variant.objects.filter(
            is_deleted=False, product_id=self.kwargs["product_pk"]
        )

    def _get_product(self):
        product = Product.objects.get(pk=self.kwargs["product_pk"], is_deleted=False)
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product

    def perform_create(self, serializer):
        serializer.save(product=self._get_product())

    def perform_update(self, serializer):
        self._get_product()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_product()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])
