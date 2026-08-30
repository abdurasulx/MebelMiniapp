from django.core.files.base import ContentFile
from django.db.models import Case, Count, F, IntegerField, OuterRef, Q, Subquery, Sum, Value, When
from django.db.models.functions import Coalesce
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.cart.models import CartItem
from apps.companies.models import Company
from apps.companies.views import user_company
from apps.likes.models import Like
from apps.orders.models import OrderItem
from common.geo import haversine_km

from . import embedding
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


def _companies_within_radius(lat, lng):
    """Foydalanuvchi nuqtasidan (`lat`, `lng`) firma o'zi sozlagan xizmat
    radiusi ichida bo'lgan (yoki lokatsiya/radius umuman sozlanmagan —
    ya'ni hammaga ochiq) kompaniyalar ID'lari."""
    ids = []
    for c in Company.objects.filter(is_active=True).only(
        "id", "latitude", "longitude", "service_radius_km"
    ):
        if c.latitude is None or c.longitude is None or c.service_radius_km is None:
            ids.append(c.id)
        elif haversine_km(lat, lng, float(c.latitude), float(c.longitude)) <= c.service_radius_km:
            ids.append(c.id)
    return ids


def _with_sales_and_cart_counts(qs):
    """Har mahsulotga (bekor qilinmagan buyurtmalardagi) sotilgan dona soni
    va hozir savatlarda turgan qatorlar sonini qo'shadi — qidiruv natijalari
    shular bo'yicha tartiblanadi (qarang get_queryset). Subquery orqali,
    Count/Sum'ni to'g'ridan-to'g'ri annotate qilish variants/images kabi
    boshqa reverse relationlar bilan JOIN fan-out hosil qilib, noto'g'ri
    sonlarga olib kelishi mumkin edi."""
    sales_subquery = (
        OrderItem.objects.filter(product=OuterRef("pk"))
        .exclude(order__status="cancelled")
        .values("product")
        .annotate(total=Sum("quantity"))
        .values("total")
    )
    cart_subquery = (
        CartItem.objects.filter(product=OuterRef("pk"), is_deleted=False)
        .values("product")
        .annotate(total=Count("id"))
        .values("total")
    )
    return qs.annotate(
        sales_count=Coalesce(Subquery(sales_subquery, output_field=IntegerField()), Value(0)),
        cart_count=Coalesce(Subquery(cart_subquery, output_field=IntegerField()), Value(0)),
    )


def _personalization_score_case(user):
    """Foydalanuvchining sevimlilar/buyurtma tarixi/savatidan kelib chiqib
    har kategoriya va rang uchun "qiziqish og'irligi" hisoblanadi (buyurtma
    eng ishonchli signal — og'irligi eng katta, keyin savat, keyin like).
    Signal umuman bo'lmasa `None` qaytaradi — chaqiruvchi bu holda oddiy
    xronologik tartibga tushadi."""
    category_weights = {}
    color_weights = {}

    def bump(weights, key, amount):
        if key:
            weights[key] = weights.get(key, 0) + amount

    for category_id, color_tag in Like.objects.filter(user=user).values_list(
        "product__category_id", "product__color_tag"
    ):
        bump(category_weights, category_id, 2)
        bump(color_weights, color_tag, 2)
    for category_id, color_tag in OrderItem.objects.filter(order__customer=user).values_list(
        "product__category_id", "product__color_tag"
    ):
        bump(category_weights, category_id, 3)
        bump(color_weights, color_tag, 3)
    for category_id, color_tag in CartItem.objects.filter(user=user, is_deleted=False).values_list(
        "product__category_id", "product__color_tag"
    ):
        bump(category_weights, category_id, 1)
        bump(color_weights, color_tag, 1)

    if not category_weights and not color_weights:
        return None

    category_case = Case(
        *[When(category_id=k, then=Value(v)) for k, v in category_weights.items()],
        default=Value(0),
        output_field=IntegerField(),
    )
    color_case = Case(
        *[When(color_tag=k, then=Value(v)) for k, v in color_weights.items()],
        default=Value(0),
        output_field=IntegerField(),
    )
    return category_case, color_case


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
        category_slug = self.request.query_params.get("category")
        if category_slug:
            qs = qs.filter(category__slug=category_slug)
        # Mahsulot sahifasidagi "Sizga yoqishi mumkin" bo'limi uchun —
        # ko'rilayotgan mahsulotning o'zi tavsiyalar orasida chiqmasin.
        exclude_id = self.request.query_params.get("exclude")
        if exclude_id:
            qs = qs.exclude(pk=exclude_id)
        search = self.request.query_params.get("search")
        if search:
            # Pastda `ordering=top` bilan Count() annotatsiyasi ham ishlatiladi —
            # model3d/variants orqali qo'shimcha JOIN qo'shsak, fan-out sabab
            # like_count noto'g'ri (bir necha marta) hisoblanib qolishi mumkin,
            # shuning uchun moslikni alohida subquery orqali topamiz.
            matching_ids = Product.objects.filter(
                Q(name_uz__icontains=search)
                | Q(company__name__icontains=search)
                | Q(color_tag__icontains=search)
                | Q(model3d__shape_tag__icontains=search)
                | Q(variants__model3d__shape_tag__icontains=search)
            ).values_list("pk", flat=True)
            qs = qs.filter(pk__in=matching_ids)
        # Foydalanuvchi lokatsiyasi (`lat`/`lng`) berilgan bo'lsa — firma
        # o'zi sozlagan xizmat radiusi (Company.service_radius_km) bo'yicha
        # filtrlanadi, ma'muriy viloyat chegarasidan qat'iy nazar (masalan
        # viloyat chegarasiga yaqin firma qo'shni viloyat mijozlariga ham
        # xizmat qilishi mumkin). Lokatsiya/radius sozlanmagan firmalar
        # avvalgidek hammaga ko'rinadi. Eski klientlar uchun `viloyat`
        # parametri hali ham qo'llab-quvvatlanadi (lat/lng bo'lmasa).
        lat = self.request.query_params.get("lat")
        lng = self.request.query_params.get("lng")
        if lat and lng:
            try:
                allowed_ids = _companies_within_radius(float(lat), float(lng))
                qs = qs.filter(company_id__in=allowed_ids)
            except (TypeError, ValueError):
                pass
        else:
            viloyat = self.request.query_params.get("viloyat")
            if viloyat:
                qs = qs.filter(Q(company__viloyat=viloyat) | Q(company__viloyat=""))
        ordering = self.request.query_params.get("ordering")
        if ordering == "top":
            qs = qs.annotate(like_count=Count("liked_by")).order_by("-like_count", "-created_at")
        elif search:
            # Qidiruv natijalari — eng ko'p sotilgan, keyin hozir eng ko'p
            # savatda turgan mahsulot birinchi (sof matn moslikdan ko'ra
            # "haqiqatan xarid qilinadigan" narsa yuqorida bo'lishi kerak).
            qs = _with_sales_and_cart_counts(qs).order_by("-sales_count", "-cart_count", "-created_at")
        elif user.is_authenticated and not company_slug:
            # Asosiy sahifa (filtrsiz ko'rinish) — foydalanuvchining
            # sevimlilar/buyurtma/savat tarixidan kelib chiqib kategoriya va
            # rang moslashuvi asosiy rol o'ynaydi. Signal umuman bo'lmasa
            # (yangi foydalanuvchi) — oddiy xronologik tartib qoladi.
            personalization = _personalization_score_case(user)
            if personalization is not None:
                category_case, color_case = personalization
                qs = qs.annotate(
                    _category_score=category_case, _color_score=color_case
                ).annotate(
                    personal_score=F("_category_score") + F("_color_score")
                ).order_by("-personal_score", "-created_at")
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
    rasmga eng o'xshash nashr etilgan mahsulotlarni topadi. CLIP (OpenCLIP)
    embedding + Qdrant vektor qidiruvi orqali ishlaydi (qarang
    apps/products/embedding.py) — shakl/rang/uslub bo'yicha semantik
    o'xshashlikni ushlaydi, aynan bir xil piksel talab qilmaydi.
    Ixtiyoriy `category` (slug) parametri natijani shu kategoriya bilan
    cheklaydi. Faqat `min_similarity` (standart 60) foizdan yuqori yoki
    teng natijalar qaytariladi — aks holda umuman aloqador bo'lmagan
    mahsulot ham "eng yaqin"i sifatida chiqib qolardi."""

    permission_classes = (permissions.AllowAny,)
    MAX_RESULTS = 20
    CANDIDATE_LIMIT = 60
    DEFAULT_MIN_SIMILARITY = 60

    def post(self, request):
        serializer = ImageSearchSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        category_id = None
        category_slug = request.data.get("category")
        if category_slug:
            category_id = Category.objects.filter(slug=category_slug).values_list(
                "id", flat=True
            ).first()

        try:
            min_similarity = float(request.data.get("min_similarity", self.DEFAULT_MIN_SIMILARITY))
        except (TypeError, ValueError):
            min_similarity = self.DEFAULT_MIN_SIMILARITY

        hits = embedding.search_similar(
            serializer.validated_data["image"],
            category_id=category_id,
            limit=self.CANDIDATE_LIMIT,
            score_threshold=min_similarity / 100,
        )
        if not hits:
            return Response([])

        score_by_id = {product_id: score for product_id, score in hits}
        candidates = {
            str(p.id): p
            for p in Product.objects.filter(
                id__in=score_by_id.keys(), is_deleted=False, is_published=True
            ).select_related("company", "category").prefetch_related("variants", "images")
        }

        ordered = [
            (candidates[pid], score)
            for pid, score in hits
            if pid in candidates
        ][: self.MAX_RESULTS]

        products_data = ProductSerializer(
            [p for p, _ in ordered], many=True, context={"request": request}
        ).data
        for item, (_, score) in zip(products_data, ordered):
            item["similarity_percent"] = round(score * 100, 1)

        return Response(products_data)
