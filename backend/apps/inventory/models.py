from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import models

from common.models import BaseModel

UNIT_CHOICES = [
    ("dona", "Dona"),
    ("kg", "Kilogramm"),
    ("m", "Metr"),
    ("m2", "Kvadrat metr"),
    ("m3", "Kub metr"),
    ("litr", "Litr"),
]


class Warehouse(BaseModel):
    """Firma o'zi yaratadigan ombor — bitta firmada bir nechtasi bo'lishi mumkin
    (masalan har filialda alohida, yoki bir filialda ham xom ashyo, ham tayyor
    mahsulot uchun alohida-alohida)."""

    class Kind(models.TextChoices):
        RAW_MATERIAL = "raw_material", "Xom ashyo ombori"
        FINISHED_GOODS = "finished_goods", "Tayyor mahsulot ombori"

    company = models.ForeignKey("companies.Company", on_delete=models.CASCADE, related_name="warehouses")
    branch = models.ForeignKey(
        "companies.Branch", on_delete=models.SET_NULL, null=True, blank=True, related_name="warehouses"
    )
    name = models.CharField(max_length=255)
    kind = models.CharField(max_length=20, choices=Kind.choices)
    address = models.CharField(max_length=500, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.company.name} — {self.name}"


class Material(BaseModel):
    """Xom ashyo katalogi — bitta firmaga tegishli (masalan taxta, mix, mato).
    `unit_cost` keyingi bosqichda mahsulot tannarxini hisoblashda ishlatiladi."""

    company = models.ForeignKey("companies.Company", on_delete=models.CASCADE, related_name="materials")
    name = models.CharField(max_length=255)
    unit = models.CharField(max_length=10, choices=UNIT_CHOICES, default="dona")
    unit_cost = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)

    def __str__(self):
        return self.name


class MaterialStock(BaseModel):
    """Bitta ombordagi bitta xom ashyoning joriy qoldig'i — harakatlar
    (MaterialMovement) yaratilganda avtomatik yangilanadi, qo'lda o'zgartirilmaydi."""

    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE, related_name="material_stocks")
    material = models.ForeignKey(Material, on_delete=models.CASCADE, related_name="stocks")
    quantity = models.DecimalField(max_digits=14, decimal_places=3, default=0)

    class Meta:
        unique_together = ("warehouse", "material")
        ordering = ("material__name",)

    def __str__(self):
        return f"{self.material.name} @ {self.warehouse.name}: {self.quantity}"


class MaterialMovement(BaseModel):
    """Ombordagi xom ashyo kirim/chiqim tarixi (audit) — har yozuv qoldiqni
    (`MaterialStock`) ham mos ravishda o'zgartiradi."""

    class Type(models.TextChoices):
        IN = "in", "Kirim"
        OUT = "out", "Chiqim"

    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE, related_name="material_movements")
    material = models.ForeignKey(Material, on_delete=models.CASCADE, related_name="movements")
    movement_type = models.CharField(max_length=10, choices=Type.choices)
    quantity = models.DecimalField(max_digits=14, decimal_places=3, validators=[MinValueValidator(0.001)])
    note = models.CharField(max_length=500, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )

    class Meta:
        ordering = ("-created_at",)


class ProductStock(BaseModel):
    """Tayyor mahsulot omboridagi joriy qoldiq — mahsulot (va ixtiyoriy variant)
    bo'yicha."""

    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE, related_name="product_stocks")
    product = models.ForeignKey("products.Product", on_delete=models.CASCADE, related_name="stocks")
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.CASCADE, related_name="stocks", null=True, blank=True
    )
    quantity = models.DecimalField(max_digits=14, decimal_places=3, default=0)

    class Meta:
        unique_together = ("warehouse", "product", "variant")


class ProductMovement(BaseModel):
    """Tayyor mahsulot ombori kirim/chiqim tarixi (masalan ishlab chiqarishdan
    kirim, sotuvdan chiqim)."""

    class Type(models.TextChoices):
        IN = "in", "Kirim"
        OUT = "out", "Chiqim"

    warehouse = models.ForeignKey(Warehouse, on_delete=models.CASCADE, related_name="product_movements")
    product = models.ForeignKey("products.Product", on_delete=models.CASCADE, related_name="movements")
    variant = models.ForeignKey(
        "products.Variant", on_delete=models.CASCADE, related_name="movements", null=True, blank=True
    )
    movement_type = models.CharField(max_length=10, choices=Type.choices)
    quantity = models.DecimalField(max_digits=14, decimal_places=3, validators=[MinValueValidator(0.001)])
    note = models.CharField(max_length=500, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )

    class Meta:
        ordering = ("-created_at",)
