from django.conf import settings
from django.db import models

from common.models import BaseModel


class CartItem(BaseModel):
    """Foydalanuvchi savati — endi serverda saqlanadi (qurilmalar orasida
    sinxron, ilgari faqat localStorage'da edi) va qidiruv/asosiy sahifa
    reytingiga "savatda turgan aktivligi" signalini beradi (qarang
    apps/products/views.py)."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="cart_items"
    )
    product = models.ForeignKey(
        "products.Product", on_delete=models.CASCADE, related_name="cart_items"
    )
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.CASCADE, related_name="cart_items"
    )
    width = models.DecimalField(max_digits=6, decimal_places=2)
    height = models.DecimalField(max_digits=6, decimal_places=2)
    depth = models.DecimalField(max_digits=6, decimal_places=2)
    quantity = models.PositiveIntegerField(default=1)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.user} savatida {self.product} x{self.quantity}"
