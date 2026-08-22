from django.conf import settings
from django.db import models

from common.models import BaseModel


class ARCollection(BaseModel):
    """Foydalanuvchi (odatda usta) bir marta yaratadigan, keyin AR seanslarida
    qayta-qayta ochib turadigan mahsulotlar to'plami — "loyiha" (web'dagi
    xaridor uchun mo'ljallangan `apps.projects.Project`dan farqli, bu yerda
    HECH QANDAY fazoviy (position/rotation) ma'lumot saqlanmaydi: ARKit dunyo
    koordinatasi har safar yangi seansda noldan boshlanadi va faqat o'sha
    fizik xonada ma'noli — boshqa xona/qurilmada saqlangan pozitsiyalarni
    qayta ishlatish natijani "hunuk" qilib qo'yardi. Shuning uchun bu yerda
    faqat "qaysi mahsulot+variant loyihaga tegishli" saqlanadi — har safar
    AR ochilganda foydalanuvchi ularni xonaga qaytadan joylashtiradi."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="ar_collections"
    )
    name = models.CharField(max_length=150, default="Yangi loyiha")

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.name} ({self.owner})"


class ARCollectionItem(BaseModel):
    collection = models.ForeignKey(ARCollection, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey("products.Product", on_delete=models.CASCADE, related_name="+")
    # Tanlangan rang/material — bo'sh bo'lsa mahsulotning standart (birinchi) varianti.
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        ordering = ("created_at",)

    def __str__(self):
        return f"{self.product} @ {self.collection}"
