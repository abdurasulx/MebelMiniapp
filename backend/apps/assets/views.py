from rest_framework import permissions, viewsets
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.products.models import Product
from apps.products.views import can_manage

from .models import Model3D
from .serializers import Model3DSerializer, Model3DViewerSerializer


class Model3DViewSet(viewsets.ModelViewSet):
    """Mahsulotning 3D modelini boshqarish (firma tomoni).

    Har mahsulotda bitta 3D model (OneToOne) — barcha rang variantlari shu bitta
    geometriyaga runtime'da material sifatida qo'llanadi. Yaratish/tahrirlash —
    faqat mahsulotni boshqara oladigan foydalanuvchi (ega/xodim/admin).
    """

    serializer_class = Model3DSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        qs = Model3D.objects.filter(is_deleted=False).select_related("product")
        product_id = self.request.query_params.get("product")
        if product_id:
            qs = qs.filter(product_id=product_id)
        return qs

    def _get_product(self):
        product = Product.objects.select_related("company").get(
            pk=self.kwargs.get("product_pk") or self.request.data.get("product"),
            is_deleted=False,
        )
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product

    def perform_create(self, serializer):
        serializer.save(product=self._get_product())

    def perform_update(self, serializer):
        if not can_manage(self.request.user, serializer.instance.product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        serializer.save()

    def perform_destroy(self, instance):
        if not can_manage(self.request.user, instance.product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
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
                "product__company"
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
