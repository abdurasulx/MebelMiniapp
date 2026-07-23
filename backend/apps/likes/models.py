from django.conf import settings
from django.db import models

from common.models import BaseModel


class Like(BaseModel):
    """Mijozning sevimli (saqlangan) mahsuloti — serverda saqlanadi,
    qaysi qurilma/ilovadan kirsa ham bir xil ro'yxat ko'rinadi."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="likes"
    )
    product = models.ForeignKey(
        "products.Product", on_delete=models.CASCADE, related_name="liked_by"
    )

    class Meta:
        unique_together = ("user", "product")
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.user} ❤ {self.product}"
