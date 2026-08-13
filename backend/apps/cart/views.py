from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import CartItem
from .serializers import CartItemSerializer


class CartItemViewSet(viewsets.ModelViewSet):
    """`/cart-items/` — foydalanuvchining serverda saqlanadigan savati.
    Har bir mijoz faqat o'z savatini ko'radi/boshqaradi."""

    serializer_class = CartItemSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return CartItem.objects.filter(
            user=self.request.user, is_deleted=False
        ).select_related("product", "product__company", "variant")

    def perform_create(self, serializer):
        # Bir xil mahsulot+variant+o'lchamdagi qator allaqachon savatda
        # bo'lsa, sonini oshiramiz — frontend (cart.js) va Flutter
        # (cart_store.dart) dagi "bir xil bandni birlashtirish" mantig'i
        # bilan bir xil, aks holda bir xil qator ikki marta chiqib qolardi.
        data = serializer.validated_data
        existing = CartItem.objects.filter(
            user=self.request.user,
            is_deleted=False,
            product=data["product"],
            variant=data["variant"],
            width=data["width"],
            height=data["height"],
            depth=data["depth"],
        ).first()
        if existing:
            existing.quantity += data.get("quantity", 1)
            existing.save(update_fields=["quantity"])
            serializer.instance = existing
        else:
            serializer.save(user=self.request.user)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])

    @action(detail=False, methods=["delete"])
    def clear(self, request):
        self.get_queryset().update(is_deleted=True)
        return Response(status=204)
