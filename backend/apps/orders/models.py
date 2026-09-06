from django.conf import settings
from django.db import models

from common.models import BaseModel


class OrderType(models.TextChoices):
    READY_PRODUCT = "ready_product", "Tayyor mahsulot"
    CUSTOM_PROJECT = "custom_project", "Individual loyiha"


class Order(BaseModel):
    """Mijoz buyurtmasi — bitta kompaniyaga tegishli (docs/10, roadmap Phase 5).

    Ikki turi qat'iy ajratiladi (`order_type`): READY_PRODUCT — katalogdan
    to'g'ridan-to'g'ri xarid (narx avtomatik), CUSTOM_PROJECT — usta joy
    o'rganib yaratgan individual loyiha (qarang apps.custom_orders). Ikkalasi
    ham shu bir modelga tayanadi, lekin yaratilish/status oqimi mustaqil —
    READY_PRODUCT kodi CUSTOM_PROJECT qo'shilishi bilan o'zgarmadi.
    """

    class Status(models.TextChoices):
        NEW = "new", "Kutilmoqda"
        ACCEPTED = "accepted", "Qabul qilindi"
        # Faqat CUSTOM_PROJECT uchun — dizayner 3D loyiha tayyorlayotgan va
        # tasdiqlanishini kutayotgan oraliq bosqich (qarang apps.custom_orders.Design).
        DESIGNING = "designing", "Loyihalashtirilmoqda"
        IN_PRODUCTION = "in_production", "Ishlab chiqarilmoqda"
        READY = "ready", "Tayyor"
        DELIVERING = "delivering", "Yetkazilmoqda"
        COMPLETED = "completed", "Yakunlandi"
        CANCELLED = "cancelled", "Bekor qilindi"

    OrderType = OrderType

    # ruxsat etilgan status o'tishlari (kompaniya tomoni). DESIGNING faqat
    # CUSTOM_PROJECT uchun ma'noli — READY_PRODUCT buyurtmalar hech qachon
    # shu holatga o'tmaydi (qarang OrderViewSet.set_status).
    TRANSITIONS = {
        Status.NEW: [Status.ACCEPTED, Status.CANCELLED],
        Status.ACCEPTED: [Status.DESIGNING, Status.IN_PRODUCTION, Status.CANCELLED],
        Status.DESIGNING: [Status.IN_PRODUCTION, Status.CANCELLED],
        Status.IN_PRODUCTION: [Status.READY],
        Status.READY: [Status.DELIVERING, Status.COMPLETED],
        Status.DELIVERING: [Status.COMPLETED],
    }

    order_type = models.CharField(max_length=20, choices=OrderType.choices, default=OrderType.READY_PRODUCT)
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
    # CUSTOM_PROJECT buyurtmalar usta mijoz uyida turib to'g'ridan-to'g'ri
    # yaratganda (qarang apps.custom_orders.services.create_custom_order_on_site)
    # qurilma geolokatsiyasi soxta (mock) deb aniqlansa shu yerda belgilanadi —
    # buyurtma baribir yaratiladi (savdoni bloklamaslik uchun), lekin firma
    # egasiga xabar boradi va shu bayroq orqali keyinroq ko'rib chiqilishi mumkin.
    location_flagged = models.BooleanField(default=False)
    location_flag_reason = models.CharField(max_length=255, blank=True)

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
    # CUSTOM_PROJECT'da variant tanlanmasligi mumkin (masalan mahsulot
    # umuman katalog variantiga mos kelmaydigan individual buyum) — shuning
    # uchun nullable, READY_PRODUCT uchun hamon amalda har doim to'ldiriladi.
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.PROTECT, related_name="order_items",
        null=True, blank=True,
    )
    product_name = models.CharField(max_length=255)
    variant_name = models.CharField(max_length=255, blank=True)
    width = models.DecimalField(max_digits=6, decimal_places=2)
    height = models.DecimalField(max_digits=6, decimal_places=2)
    depth = models.DecimalField(max_digits=6, decimal_places=2)
    quantity = models.PositiveIntegerField(default=1)
    # `is_custom_size=True` bo'lsa narx avtomatik hisoblanmaydi —
    # `unit_m3_price`/`subtotal` bo'sh/0 qoladi, admin keyin `cost_amount`ni
    # qo'lda kiritadi (docs "Buyurtma va ishlab chiqarish tizimi" §4).
    is_custom_size = models.BooleanField(default=False)
    unit_m3_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    cost_amount = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    subtotal = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    def __str__(self):
        return f"{self.product_name} ({self.variant_name}) x{self.quantity}"
