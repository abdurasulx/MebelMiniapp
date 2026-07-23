import random
import uuid
from datetime import timedelta

from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("Email majburiy")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", User.Role.PLATFORM_ADMIN)
        return self._create_user(email, password, **extra_fields)


class User(AbstractUser):
    """Email-login user with platform roles (docs/04, docs/05)."""

    class Role(models.TextChoices):
        PLATFORM_ADMIN = "platform_admin", "Platform Admin"
        COMPANY_OWNER = "company_owner", "Company Owner"
        EMPLOYEE = "employee", "Employee"
        CUSTOMER = "customer", "Customer"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = None
    email = models.EmailField("email", unique=True)
    phone = models.CharField(max_length=20, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CUSTOMER)
    # Doimiy, kompaniyalararo qidiruvchi ID (kamida 10 raqam) — firma egasi xodimni
    # ishga shu ID orqali taklif qiladi (roadmap: "Worker ID" — profilda ko'rsatiladi).
    worker_id = models.CharField(max_length=12, unique=True, editable=False, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def save(self, *args, **kwargs):
        if not self.worker_id:
            self.worker_id = self._generate_worker_id()
        super().save(*args, **kwargs)

    @staticmethod
    def _generate_worker_id():
        while True:
            candidate = "".join(random.choices("0123456789", k=10))
            if not User.objects.filter(worker_id=candidate).exists():
                return candidate

    def __str__(self):
        return self.email


class PhoneOTP(models.Model):
    """SMS-tasdiqlash kodi (docs: telefon orqali kirish).

    SMS provayder hali ulanmagan (production oldidan sotib olinadi) — hozircha
    kod javobda `debug_code` sifatida qaytariladi, front bu qiymatni ekranda
    ko'rsatadi. Provayder ulanganda faqat shu joy (view) o'zgaradi.

    Suiiste'moldan himoya: qayta yuborish uchun eng kam kutish vaqti
    (`RESEND_COOLDOWN_SECONDS`), bir vaqt oynasidagi eng ko'p so'rovlar soni
    (`OTPRequestView`da tekshiriladi) va noto'g'ri kod urinishlari soni
    (`attempts`, `MAX_ATTEMPTS`dan oshsa kod bekor qilinadi).
    """

    RESEND_COOLDOWN_SECONDS = 60
    MAX_ATTEMPTS = 5

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20)
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)
    attempts = models.PositiveSmallIntegerField(default=0)

    def is_valid(self):
        return (
            not self.is_used
            and self.attempts < self.MAX_ATTEMPTS
            and timezone.now() - self.created_at < timedelta(minutes=5)
        )
