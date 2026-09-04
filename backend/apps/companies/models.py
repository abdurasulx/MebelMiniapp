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


class Viloyat(models.TextChoices):
    """O'zbekiston viloyatlari — kompaniya qaysi hududda joylashganini
    belgilash va katalogni foydalanuvchi lokatsiyasiga qarab filtrlash uchun.

    Ilgari bu filial (Branch) darajasida edi — bitta firma bir nechta
    viloyatda filiali bo'lishi mumkin edi. Endi har bir jismoniy joylashuv
    alohida Company sifatida ro'yxatdan o'tadi, shuning uchun viloyat
    to'g'ridan-to'g'ri Company'ga ko'chirildi."""

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


class TariffPlan(BaseModel):
    """Platforma tarif rejasi — FAQAT platforma admini yaratadi/tahrirlaydi
    (Django admin yoki `/tariff-plans/`), firma egasi esa ro'yxatdan birini
    o'zi tanlaydi (`Company.tariff_plan`, majburiy emas). Oylik hisob ikki
    komponentdan iborat: xodimlar soni (har biri uchun `price_per_employee`)
    va 3D modeli bor mahsulotlar soni (har biri uchun `price_per_product` —
    VARIANT emas, MAHSULOT bo'yicha, chunki bitta mahsulotning bir nechta
    varianti bo'lishi mumkin va ular bitta "bulutli saqlash" o'rnini
    egallaydi)."""

    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    price_per_employee = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    price_per_product = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    currency = models.CharField(max_length=3, default="USD")
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("price_per_employee", "price_per_product")

    def __str__(self):
        return self.name


class Company(BaseModel, StoredFileMixin):
    """Tenant: mebel ishlab chiqaruvchi kompaniya (docs/06, techdocs/06 §6)."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="companies"
    )
    tariff_plan = models.ForeignKey(
        TariffPlan, on_delete=models.SET_NULL, null=True, blank=True, related_name="companies"
    )
    name = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True)
    description = models.TextField(blank=True)
    phone = models.CharField(max_length=20, blank=True)
    address = models.CharField(max_length=500, blank=True)
    viloyat = models.CharField(max_length=30, choices=Viloyat.choices, blank=True)
    # Aniq geolokatsiya — viloyatdan farqli, mahsulotlar foydalanuvchiga
    # xizmat radiusi (pastda) orqali ko'rsatiladi, ma'muriy hudud chegarasiga
    # qarab emas (qarang apps/products/views.py). Ikkalasi ham bo'sh bo'lsa,
    # eski xatti-harakat davom etadi — firma hamma joyda ko'rinadi.
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    service_radius_km = models.PositiveIntegerField(null=True, blank=True)
    logo = models.ImageField(upload_to="companies/logos/", blank=True, null=True)
    # Ijtimoiy tarmoq/veb-sahifa havolalari — firma profilida (Do'kon sahifasi)
    # bosiladigan ikonka sifatida ko'rsatiladi. Barchasi ixtiyoriy.
    instagram_url = models.URLField(max_length=300, blank=True)
    telegram_url = models.URLField(max_length=300, blank=True)
    facebook_url = models.URLField(max_length=300, blank=True)
    website_url = models.URLField(max_length=300, blank=True)
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

    @property
    def billing_employee_count(self):
        return self.employees.filter(is_active=True, is_deleted=False).count()

    @property
    def billing_product_count(self):
        # Variant emas, MAHSULOT bo'yicha — bitta mahsulotning bir nechta
        # varianti bo'lsa ham bitta "bulutli 3D saqlash" narxi to'lanadi
        # (qarang TariffPlan izohi).
        return self.products.filter(is_deleted=False, model3d__isnull=False, model3d__is_deleted=False).count()

    @property
    def billing_summary(self):
        employees = self.billing_employee_count
        products = self.billing_product_count
        plan = self.tariff_plan
        if plan is None:
            return {
                "plan": None, "employee_count": employees, "product_count": products, "total": None,
            }
        total = employees * plan.price_per_employee + products * plan.price_per_product
        return {
            "plan": {
                "id": str(plan.id), "name": plan.name,
                "price_per_employee": plan.price_per_employee, "price_per_product": plan.price_per_product,
                "currency": plan.currency,
            },
            "employee_count": employees,
            "product_count": products,
            "total": total,
        }


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


class PayType(models.TextChoices):
    FIXED = "fixed", "Faqat oylik"
    FIXED_BONUS = "fixed_bonus", "Oylik + vazifa bonusi"
    COMMISSION = "commission", "Komissiya (% sotuvdan)"
    HOURLY = "hourly", "Soatbay"
    PIECEWORK = "piecework", "Ishbay"


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
    # Ish haqi (docs/41 §20 "employees.salary"): to'lov turi + shu turga mos
    # summa(lar). Xodim qo'shilganda/taklif qilinganda `PositionPayStandard`
    # (pastda) frontendda taklif sifatida ko'rsatiladi, lekin bu yerda har
    # doim aniq, individual kiritilgan qiymat saqlanadi — "o'zi individual
    # sozlasin" talabiga ko'ra standart faqat boshlang'ich taklif, keyingi
    # hisob-kitob (Payslip.recompute) shu yerdagi qiymatlarga tayanadi.
    pay_type = models.CharField(max_length=20, choices=PayType.choices, default=PayType.FIXED_BONUS)
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    # Soatbay xodim uchun belgilangan ish grafigi — kechikish/erta ketish/
    # ortiqcha ish hisoblashda solishtirish uchun (qarang apps/attendance).
    shift_start = models.TimeField(null=True, blank=True)
    shift_end = models.TimeField(null=True, blank=True)
    lunch_start = models.TimeField(null=True, blank=True)
    lunch_end = models.TimeField(null=True, blank=True)
    # Ish kunlari — Python `date.weekday()` bilan bir xil: Dushanba=0 ... Yakshanba=6.
    work_days = models.JSONField(default=list, blank=True)

    class Meta:
        unique_together = ("company", "user")

    def __str__(self):
        return f"{self.user} @ {self.company}"


class PositionPayStandard(BaseModel):
    """Lavozim bo'yicha standart to'lov tuzilmasi — ikkita daraja: platforma
    darajasida (`company=None`, faqat platforma admini sozlaydi) va firma
    o'ziga moslashtirgan daraja (`company=X`). Xodim qo'shish/taklif qilish
    formasida shu standart (avval firma o'ziniki, bo'lmasa platforma
    standarti) boshlang'ich taklif sifatida frontendda avtomatik to'ldiriladi
    — Employee'ning o'zida saqlanmaydi, faqat taklif manbai.

    KPI maqsadlari esa "taklif" emas — Payslip.recompute() har safar shu
    yozuvdan real vaqtda o'qib, bonusga multiplikator sifatida qo'llaydi
    (qarang PayslipMixin/KPI hisoblash apps/production/models.py)."""

    company = models.ForeignKey(
        Company, on_delete=models.CASCADE, related_name="pay_standards", null=True, blank=True
    )
    position = models.CharField(max_length=20, choices=Employee.Position.choices)
    pay_type = models.CharField(max_length=20, choices=PayType.choices, default=PayType.FIXED_BONUS)
    min_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    max_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    default_bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    default_commission_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    default_hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    # KPI — bajarilishi shart bo'lgan maqsad(lar). Bo'sh (None) qoldirilgan
    # maqsad tekshirilmaydi. Ikkalasi ham bo'sh bo'lsa, KPI multiplikatori
    # umuman qo'llanmaydi (faqat kuzatuv/hisobot uchun ishlatilishi mumkin).
    kpi_target_tasks_per_month = models.PositiveIntegerField(null=True, blank=True)
    kpi_target_on_time_percent = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True
    )
    kpi_bonus_multiplier = models.DecimalField(max_digits=4, decimal_places=2, default=1)

    class Meta:
        unique_together = ("company", "position")
        ordering = ("position",)

    def __str__(self):
        scope = self.company.name if self.company_id else "Platforma"
        return f"{scope} — {self.get_position_display()}"


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
    pay_type = models.CharField(max_length=20, choices=PayType.choices, default=PayType.FIXED_BONUS)
    base_salary = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    bonus_per_task = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    commission_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    hourly_rate = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    shift_start = models.TimeField(null=True, blank=True)
    shift_end = models.TimeField(null=True, blank=True)
    lunch_start = models.TimeField(null=True, blank=True)
    lunch_end = models.TimeField(null=True, blank=True)
    work_days = models.JSONField(default=list, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.invited_user} -> {self.company} ({self.status})"
