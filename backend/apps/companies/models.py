from django.conf import settings
from django.db import models
from django.db.models import Avg
from django.utils.text import slugify

from common.models import BaseModel, StoredFileMixin

# Bajarilgan buyurtmalar soniga qarab ishonch darajasi (techdocs pattern:
# bazissoft.ru kabi marketplacelarda kompaniya "daraja"si). Yulduzcha reytingi
# past bo'lsa (o'rtacha < 3), hajmidan qat'iy nazar rang "ogohlantiruvchi"ga
# tushadi — reyting doim rangga ta'sir qiladi.
TIER_THRESHOLDS = (
    (100, "gold", "Premium firma", "#f5b301"),
    (10, "silver", "Ishonchli firma", "#64748b"),
    (0, "bronze", "Faol firma", "#b87333"),
)
TIER_NEW = {"key": "new", "label": "Yangi firma", "color": "#94a3b8"}
TIER_LOW_RATING_COLOR = "#ef4444"


class Company(BaseModel, StoredFileMixin):
    """Tenant: mebel ishlab chiqaruvchi kompaniya (docs/06, techdocs/06 §6)."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="companies"
    )
    name = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True)
    description = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    address = models.CharField(max_length=500, blank=True)
    logo = models.ImageField(upload_to="companies/logos/", blank=True, null=True)
    is_active = models.BooleanField(default=True)
    # Har firma o'zining ishga olish shartnomasi matnini moslashtirib qo'yadi —
    # xodim taklifnomani (EmployeeInvitation) qabul qilishdan oldin shu matnni
    # ko'radi.
    employment_contract_template = models.TextField(blank=True)

    class Meta:
        verbose_name_plural = "companies"
        ordering = ("-created_at",)

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name

    @property
    def completed_orders_count(self):
        return self.orders.filter(status="completed", is_deleted=False).count()

    @property
    def review_count(self):
        return self.reviews.filter(is_deleted=False).count()

    @property
    def average_rating(self):
        avg = self.reviews.filter(is_deleted=False).aggregate(avg=Avg("rating"))["avg"]
        return round(avg, 1) if avg is not None else None

    @property
    def tier(self):
        count = self.completed_orders_count
        rating = self.average_rating
        for threshold, key, label, color in TIER_THRESHOLDS:
            if count > threshold:
                break
        else:
            key, label, color = TIER_NEW["key"], TIER_NEW["label"], TIER_NEW["color"]
        if count > 0 and rating is not None and rating < 3:
            color = TIER_LOW_RATING_COLOR
        return {
            "key": key,
            "label": label,
            "color": color,
            "completed_orders": count,
            "rating": rating,
            "review_count": self.review_count,
        }


class Viloyat(models.TextChoices):
    """O'zbekiston viloyatlari — filialni qaysi hududga tegishli ekanini
    belgilash va katalogni foydalanuvchi lokatsiyasiga qarab filtrlash uchun."""

    TOSHKENT_SHAHRI = "toshkent_shahri", "Toshkent shahri"
    TOSHKENT_VILOYATI = "toshkent_viloyati", "Toshkent viloyati"
    ANDIJON = "andijon", "Andijon"
    BUXORO = "buxoro", "Buxoro"
    FARGONA = "fargona", "Farg'ona"
    JIZZAX = "jizzax", "Jizzax"
    XORAZM = "xorazm", "Xorazm"
    NAMANGAN = "namangan", "Namangan"
    NAVOIY = "navoiy", "Navoiy"
    QASHQADARYO = "qashqadaryo", "Qashqadaryo"
    QORAQALPOGISTON = "qoraqalpogiston", "Qoraqalpog'iston Respublikasi"
    SAMARQAND = "samarqand", "Samarqand"
    SIRDARYO = "sirdaryo", "Sirdaryo"
    SURXONDARYO = "surxondaryo", "Surxondaryo"


class Branch(BaseModel):
    """Bir firma nomi ostida bir nechta viloyatda ishlaydigan filial (docs
    talab: "toshkentdan turib ko'rsam toshkentdagi offisi materiallari
    ko'rinsin"). Mahsulot muayyan filialga bog'lanadi — filial orqali
    katalog foydalanuvchi joylashgan viloyatga qarab filtrlanadi."""

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="branches")
    viloyat = models.CharField(max_length=30, choices=Viloyat.choices)
    address = models.CharField(max_length=500, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    # Firma birinchi marta filialsiz yaratilgan bo'lsa ham ishlashi uchun
    # asosiy filial belgisi — yangi firma ro'yxatdan o'tganda avtomatik shu bo'ladi.
    is_main = models.BooleanField(default=False)

    class Meta:
        ordering = ("-is_main", "viloyat")

    def __str__(self):
        return f"{self.company.name} — {self.get_viloyat_display()}"


class Review(BaseModel):
    """Mijozning kompaniyaga qoldirgan bahosi (1 mijoz — 1 kompaniyaga 1 baho)."""

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="reviews")
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="company_reviews"
    )
    rating = models.PositiveSmallIntegerField()
    comment = models.TextField(blank=True)

    class Meta:
        unique_together = ("company", "customer")
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.customer} → {self.company}: {self.rating}★"


class Employee(BaseModel):
    """Kompaniya xodimi a'zoligi (techdocs/06 §7).

    Bitta xodimda bir nechta kasb bo'lishi mumkin (multi-role) —
    kirishda qaysi rolda ishlashini o'zi tanlaydi.
    """

    class Position(models.TextChoices):
        USTA = "usta", "Usta (ishlab chiqarish)"
        SOTUVCHI = "sotuvchi", "Sotuvchi"
        ORNATUVCHI = "ornatuvchi", "O'rnatuvchi (montaj)"
        DIZAYNER = "dizayner", "Dizayner"
        OMBORCHI = "omborchi", "Omborchi"
        HAYDOVCHI = "haydovchi", "Yetkazib beruvchi"
        MENEJER = "menejer", "Menejer"

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="employees")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="employments"
    )
    positions = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)
    # Karyera tarixi uchun: ishdan bo'shatilgan/chiqib ketgan sana (is_active=False
    # bo'lganda o'rnatiladi). Bo'sh bo'lsa — hozir ham shu firmada ishlayapti.
    left_at = models.DateTimeField(null=True, blank=True)
    # Ish haqi (docs/41 §20 "employees.salary"): bazaviy oylik + bajarilgan
    # vazifa uchun bonus (docs/38 §9 "Employee Productivity" bilan bog'liq).
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    class Meta:
        unique_together = ("company", "user")

    def __str__(self):
        return f"{self.user} @ {self.company}"


class EmployeeInvitation(BaseModel):
    """Firma egasi foydalanuvchini uning `worker_id`si orqali ishga taklif qiladi —
    foydalanuvchi qabul qilsagina shu firma xodimi bo'lib qoladi (bir tomonlama
    qo'shish emas, taklif→qabul oqimi, ish tarixi/karyerasiga ta'sir qiladi)."""

    class Status(models.TextChoices):
        PENDING = "pending", "Kutilmoqda"
        ACCEPTED = "accepted", "Qabul qilindi"
        DECLINED = "declined", "Rad etildi"

    company = models.ForeignKey(Company, on_delete=models.CASCADE, related_name="invitations")
    invited_user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="employee_invitations"
    )
    positions = models.JSONField(default=list, blank=True)
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.invited_user} -> {self.company} ({self.status})"
