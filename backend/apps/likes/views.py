from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from apps.products.models import Product

from .models import Like
from .serializers import LikeSerializer


class LikeViewSet(
    mixins.ListModelMixin, mixins.DestroyModelMixin, viewsets.GenericViewSet
):
    """Foydalanuvchining sevimli mahsulotlari — faqat o'ziniki, serverda saqlanadi."""

    serializer_class = LikeSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return Like.objects.filter(
            user=self.request.user, is_deleted=False
        ).select_related("product__company").prefetch_related(
            "product__variants", "product__images"
        )

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])

    @action(detail=False, methods=["post"])
    def toggle(self, request):
        product_id = request.data.get("product")
        if not product_id:
            raise ValidationError("product majburiy")
        try:
            product = Product.objects.get(pk=product_id, is_deleted=False)
        except Product.DoesNotExist:
            raise ValidationError("Mahsulot topilmadi")

        existing = Like.objects.filter(user=request.user, product=product).first()
        if existing and not existing.is_deleted:
            existing.is_deleted = True
            existing.save(update_fields=["is_deleted"])
            return Response({"liked": False})
        if existing:
            existing.is_deleted = False
            existing.save(update_fields=["is_deleted"])
        else:
            Like.objects.create(user=request.user, product=product)
        return Response({"liked": True})
