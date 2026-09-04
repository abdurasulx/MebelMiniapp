from rest_framework import permissions, viewsets
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.products.models import Product, Variant
from apps.products.views import can_manage

from .models import Model3D
from .serializers import Model3DSerializer, Model3DViewerSerializer


class Model3DViewSet(viewsets.ModelViewSet):
    """3D modelni boshqarish (firma tomoni).

    Odatda mahsulotda bitta umumiy 3D model (product FK) — barcha rang
    variantlari shu bitta geometriyaga runtime'da material sifatida
    qo'llanadi. Ko'p materialli mahsulotlar uchun esa ma'lum bir variant
    o'zining alohida 3D faylini olishi mumkin (variant FK) — bunda
    `product`/`variant`dan aynan bittasi berilishi kerak. Yaratish/tahrirlash
    — faqat mahsulotni boshqara oladigan foydalanuvchi (ega/xodim/admin).
    """

    serializer_class = Model3DSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        qs = Model3D.objects.filter(is_deleted=False).select_related("product", "variant__product")
        product_id = self.request.query_params.get("product")
        if product_id:
            qs = qs.filter(product_id=product_id)
        variant_id = self.request.query_params.get("variant")
        if variant_id:
            qs = qs.filter(variant_id=variant_id)
        return qs

    def _resolve_owner(self):
        """POST tanasidan `product` yoki `variant`dan aynan bittasini kutadi
        va foydalanuvchi shu mahsulotni boshqara olishini tekshiradi."""
        product_id = self.request.data.get("product")
        variant_id = self.request.data.get("variant")
        if bool(product_id) == bool(variant_id):
            raise PermissionDenied("Aynan bittasi ko'rsatilishi kerak: mahsulot yoki variant")

        if variant_id:
            variant = Variant.objects.select_related("product__company").get(
                pk=variant_id, is_deleted=False
            )
            if not can_manage(self.request.user, variant.product.company):
                raise PermissionDenied("Bu mahsulot sizniki emas")
            return {"variant": variant}

        product = Product.objects.select_related("company").get(pk=product_id, is_deleted=False)
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return {"product": product}

    def perform_create(self, serializer):
        serializer.save(**self._resolve_owner())

    def perform_update(self, serializer):
        if not can_manage(self.request.user, serializer.instance.owning_product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        serializer.save()

    def perform_destroy(self, instance):
        if not can_manage(self.request.user, instance.owning_product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        if instance.variant_id:
            # Variant darajasidagi 3D fayl majburiy — sof o'chirishga ruxsat
            # berilmaydi, faqat yangi fayl bilan almashtirish mumkin (PATCH).
            raise ValidationError(
                "Variant uchun 3D fayl majburiy — uni o'chirib bo'lmaydi, faqat yangisi bilan almashtiring"
            )
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class Model3DViewerView(APIView):
    """Mustaqil 3D-viewer havolasi (bazissoft.ru uslubida): /viewer/<share_token>/.

    Ko'rinuvchanlikka qarab: ochiq — hammaga, yopiq — faqat firma a'zolariga,
    cheklangan — faqat ro'yxatdagi emaillarga (login qilingan holda).
    """

    permission_classes = (permissions.AllowAny,)

    def get(self, request, token):
        try:
            model = Model3D.objects.select_related(
                "product__company", "variant__product__company",
                "design_version__design__order__company",
            ).get(share_token=token, is_deleted=False)
        except Model3D.DoesNotExist:
            raise NotFound("Havola topilmadi")

        if not model.can_view(request.user):
            return Response(
                {
                    "detail": "Bu 3D modelni ko'rish huquqingiz yo'q.",
                    "requires_login": not request.user.is_authenticated,
                },
                status=403,
            )
        return Response(Model3DViewerSerializer(model, context={"request": request}).data)
