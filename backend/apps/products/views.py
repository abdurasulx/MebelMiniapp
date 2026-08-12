from django.core.files.base import ContentFile
from django.db.models import Count, Q
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.views import user_company

from .imaging import compute_signature, similarity_percent
from .models import Category, Product, ProductImage, Variant
from .serializers import (
    CategorySerializer,
    ImageSearchSerializer,
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
        search = self.request.query_params.get("search")
        if search:
            qs = qs.filter(Q(name_uz__icontains=search) | Q(company__name__icontains=search))
        # Foydalanuvchi joylashgan viloyatga tegishli (yoki viloyati
        # ko'rsatilmagan, ya'ni hammaga umumiy) firmalarning mahsulotlarigina
        # ko'rsatiladi.
        viloyat = self.request.query_params.get("viloyat")
        if viloyat:
            qs = qs.filter(Q(company__viloyat=viloyat) | Q(company__viloyat=""))
        ordering = self.request.query_params.get("ordering")
        if ordering == "top":
            qs = qs.annotate(like_count=Count("liked_by")).order_by("-like_count", "-created_at")
        return qs

    def perform_create(self, serializer):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Avval kompaniya yarating yoki kompaniyaga xodim bo'ling")
        serializer.save(company=company)

    @action(detail=True, methods=["post"], url_path="set-primary-image")
    def set_primary_image(self, request, pk=None):
        """Galereyadagi (`ProductImage`) mavjud rasmlardan birini asosiy rasm
        (`Product.image`) sifatida belgilaydi — qayta yuklash shart emas,
        fayl serverda ichkarida nusxalanadi."""
        product = self.get_object()
        if not can_manage(request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        try:
            gallery_image = product.images.get(pk=request.data.get("image"), is_deleted=False)
        except ProductImage.DoesNotExist:
            raise NotFound("Bu rasm mahsulot galereyasida topilmadi")
        if not gallery_image.image:
            raise ValidationError("Bu rasm fayli mavjud emas")

        with gallery_image.image.open("rb") as f:
            product.image.save(gallery_image.image.name.rsplit("/", 1)[-1], ContentFile(f.read()), save=True)

        return Response(ProductSerializer(product, context={"request": request}).data)

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


class ProductSearchByImageView(APIView):
    """`/products/search-by-image/` — mijoz rasm yuklab, katalogdagi shu
    rasmga eng o'xshash (rang/shakl bo'yicha) nashr etilgan mahsulotlarni
    topadi. Faqat `min_similarity` (standart 70) foizdan yuqori yoki teng
    natijalar qaytariladi, eng o'xshashidan boshlab. Tashqi AI xizmatiga
    muhtoj emas — qarang apps/products/imaging.py."""

    permission_classes = (permissions.AllowAny,)
    MAX_RESULTS = 24
    DEFAULT_MIN_SIMILARITY = 70

    def post(self, request):
        serializer = ImageSearchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        query_signature = compute_signature(serializer.validated_data["image"])
        if query_signature is None:
            raise ValidationError("Rasmni o'qib bo'lmadi — boshqa fayl tanlang")

        try:
            min_similarity = float(request.data.get("min_similarity", self.DEFAULT_MIN_SIMILARITY))
        except (TypeError, ValueError):
            min_similarity = self.DEFAULT_MIN_SIMILARITY

        candidates = Product.objects.filter(
            is_deleted=False, is_published=True, image_signature__isnull=False
        ).select_related("company", "category").prefetch_related("variants", "images")

        scored = [
            (p, similarity_percent(query_signature, p.image_signature)) for p in candidates
        ]
        scored = [(p, s) for p, s in scored if s >= min_similarity]
        scored.sort(key=lambda pair: pair[1], reverse=True)
        scored = scored[: self.MAX_RESULTS]

        products_data = ProductSerializer(
            [p for p, _ in scored], many=True, context={"request": request}
        ).data
        for item, (_, score) in zip(products_data, scored):
            item["similarity_percent"] = round(score, 1)

        return Response(products_data)
