from django.conf import settings
from django.db import models

from common.models import BaseModel


class Lead(BaseModel):
    """Potensial mijoz — sotuv voronkasi (docs/39 §4-5, roadmap Phase 6).

    MVP pipeline: New → Contacted → Measurement → Offer Sent → Won/Lost.
    """

    class Status(models.TextChoices):
        NEW = "new", "Yangi"
        CONTACTED = "contacted", "Bog'lanildi"
        MEASUREMENT = "measurement", "O'lchov rejalashtirildi"
        OFFER_SENT = "offer_sent", "Taklif yuborildi"
        WON = "won", "Yutildi"
        LOST = "lost", "Yo'qotildi"

    class Source(models.TextChoices):
        WEBSITE = "website", "Sayt"
        INSTAGRAM = "instagram", "Instagram"
        TELEGRAM = "telegram", "Telegram"
        REFERRAL = "referral", "Tavsiya"
        AD = "ad", "Reklama"
        OTHER = "other", "Boshqa"

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="leads"
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="leads",
        null=True,
        blank=True,
    )
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20)
    interested_product = models.CharField(max_length=255, blank=True)
    budget = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.OTHER)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.NEW)
    assigned_to = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="assigned_leads",
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.name} ({self.get_status_display()})"


class Note(BaseModel):
    """Aloqa tarixi: qo'ng'iroq, chat, tashrif va h.k. (docs/39 §11)."""

    class Kind(models.TextChoices):
        CALL = "call", "Qo'ng'iroq"
        MESSAGE = "message", "Xabar"
        VISIT = "visit", "Tashrif"
        NOTE = "note", "Izoh"

    lead = models.ForeignKey(Lead, on_delete=models.CASCADE, related_name="notes")
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    kind = models.CharField(max_length=20, choices=Kind.choices, default=Kind.NOTE)
    text = models.TextField()

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.get_kind_display()}: {self.text[:40]}"
