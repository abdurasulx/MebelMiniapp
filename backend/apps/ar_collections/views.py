from rest_framework import permissions, viewsets
from rest_framework.exceptions import PermissionDenied, ValidationError

from apps.products.models import Product

from .models import ARCollection, ARCollectionItem
from .serializers import ARCollectionItemSerializer, ARCollectionSerializer


class ARCollectionViewSet(viewsets.ModelViewSet):
    """Foydalanuvchining o'ziga tegishli AR to'plamlari ("loyihalari") —
    fazoviy (position/rotation) ma'lumot saqlanmaydi, qarang models.py."""

    serializer_class = ARCollectionSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "patch", "delete", "head", "options")

    def get_queryset(self):
        return ARCollection.objects.filter(
            owner=self.request.user, is_deleted=False
        ).prefetch_related("items__product__variants", "items__product__images", "items__variant")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ARCollectionItemNestedMixin:
    def _get_collection(self):
        try:
            return ARCollection.objects.get(
                pk=self.kwargs["collection_pk"], owner=self.request.user, is_deleted=False
            )
        except ARCollection.DoesNotExist:
            raise PermissionDenied("Bu loyiha sizga tegishli emas")


class ARCollectionItemViewSet(ARCollectionItemNestedMixin, viewsets.ModelViewSet):
    serializer_class = ARCollectionItemSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "delete", "head", "options")

    def get_queryset(self):
        collection = self._get_collection()
        return ARCollectionItem.objects.filter(collection=collection, is_deleted=False).select_related(
            "product", "variant"
        )

    def perform_create(self, serializer):
        collection = self._get_collection()
        product_id = serializer.validated_data.pop("product_id")
        try:
            product = Product.objects.get(pk=product_id, is_deleted=False)
        except Product.DoesNotExist:
            raise ValidationError("Mahsulot topilmadi")

        variant = serializer.validated_data.pop("variant", None)
        if variant is not None and variant.product_id != product.id:
            raise ValidationError("Bu variant tanlangan mahsulotga tegishli emas")

        serializer.save(collection=collection, product=product, variant=variant)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])
