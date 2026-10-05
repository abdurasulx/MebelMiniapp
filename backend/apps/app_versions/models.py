from django.db import models


class AppVersion(models.Model):
    """Mobil ilovaning (Android/iOS) bitta versiyasi va uning holati.
    Eski versiyalar HECH QACHON o'chirilmaydi (admin panelda delete yo'q) —
    tarix saqlanadi. Qaror qoidalari uchun qarang `versioning.resolve`."""

    PLATFORM_ANDROID = "android"
    PLATFORM_IOS = "ios"
    PLATFORM_CHOICES = [(PLATFORM_ANDROID, "Android"), (PLATFORM_IOS, "iOS")]

    STATUS_ACTIVE = "active"
    STATUS_UPDATE_REQUIRED = "update_required"
    STATUS_BLOCKED = "blocked"
    STATUS_CHOICES = [
        (STATUS_ACTIVE, "Active"),
        (STATUS_UPDATE_REQUIRED, "Update Required"),
        (STATUS_BLOCKED, "Blocked"),
    ]

    version = models.CharField(max_length=20)
    platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    force_update = models.BooleanField(default=False)
    store_url = models.URLField(blank=True)
    update_message = models.TextField(blank=True)
    release_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["version", "platform"], name="unique_app_version_platform"),
        ]
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.version} ({self.get_platform_display()}) — {self.get_status_display()}"
