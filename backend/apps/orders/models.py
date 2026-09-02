from django.conf import settings
from django.db import models

from common.models import BaseModel


class Order(BaseModel):
    """Mijoz buyurtmasi — bitta kompaniyaga tegishli (docs/10, roadmap Phase 5)."""

    class Status(models.TextChoices):
        NEW = "new", "Kutilmoqda"
        ACCEPTED = "accepted", "Qabul qilindi"
        IN_PRODUCTION = "in_production", "Ishlab chiqarilmoqda"
        READY = "ready", "Tayyor"
        DELIVERING = "delivering", "Yetkazilmoqda"
        COMPLETED = "completed", "Yakunlandi"
        CANCELLED = "cancelled", "Bekor qilindi"

    # ruxsat etilgan status o'tishlari (kompaniya tomoni)
    TRANSITIONS = {
        Status.NEW: [Status.ACCEPTED, Status.CANCELLED],
        Status.ACCEPTED: [Status.IN_PRODUCTION, Status.CANCELLED],
        Status.IN_PRODUCTION: [Status.READY],
        Status.READY: [Status.DELIVERING, Status.COMPLETED],
        Status.DELIVERING: [Status.COMPLETED],
    }

    company = models.ForeignKey(
        "companies.Company", on_delete=models.PROTECT, related_name="orders"
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="orders"
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.NEW)
    # Endi mijozdan so'ralmaydi (tasdiqlangan profildan avtomatik olinadi) —
    # shuning uchun `blank=True`, lekin backward-compat uchun maydonning
    # o'zi saqlanadi (eski buyurtmalar, admin ko'rinishi va h.k.).
    phone = models.CharField(max_length=20, blank=True)
    # Qo'lda kiritiladigan manzil o'rniga endi GPS geolokatsiyasi
    # (`latitude`/`longitude`) yuboriladi — bu maydon endi faqat
    # ko'rsatish/qidiruv uchun (masalan koordinatalarning o'qiladigan
    # ko'rinishi) saqlanadi, mijozdan so'ralmaydi.
    address = models.CharField(max_length=500, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    note = models.TextField(blank=True)
    total_price = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    # Komissiyali xodim (masalan sotuvchi/menejer) uchun — shu buyurtma kim
    # tomonidan yopilgani, oylik komissiya hisob-kitobida ishlatiladi (qarang
    # apps/production/models.py Payslip.recompute).
    sold_by = models.ForeignKey(
        "companies.Employee", on_delete=models.SET_NULL, null=True, blank=True, related_name="sold_orders"
    )

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"Order {str(self.id)[:8]} — {self.company.name}"


class OrderItem(BaseModel):
    """Buyurtma bandi: narx buyurtma paytida muhrlanadi (snapshot)."""

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(
        "products.Product", on_delete=models.PROTECT, related_name="order_items"
    )
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.PROTECT, related_name="order_items"
    )
    product_name = models.CharField(max_length=255)
    variant_name = models.CharField(max_length=255)
    width = models.DecimalField(max_digits=6, decimal_places=2)
    height = models.DecimalField(max_digits=6, decimal_places=2)
    depth = models.DecimalField(max_digits=6, decimal_places=2)
    quantity = models.PositiveIntegerField(default=1)
    unit_m3_price = models.DecimalField(max_digits=12, decimal_places=2)
    subtotal = models.DecimalField(max_digits=14, decimal_places=2)

    def __str__(self):
        return f"{self.product_name} ({self.variant_name}) x{self.quantity}"
