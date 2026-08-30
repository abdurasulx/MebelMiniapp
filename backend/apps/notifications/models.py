from django.conf import settings
from django.db import models

from common.models import BaseModel


class NotificationType(models.TextChoices):
    ORDER_STATUS = "order_status", "Buyurtma holati"
    TASK_ASSIGNED = "task_assigned", "Vazifa tayinlandi"
    TASK_AVAILABLE = "task_available", "Vazifa boshlashga tayyor"
    MATERIAL_SUGGESTION = "material_suggestion", "Material tavsiyasi"
    TASK_POOL_OPEN = "task_pool_open", "Yangi erkin topshiriq"
    TASK_APPLICATION_REJECTED = "task_application_rejected", "Zayavka rad etildi"


class Notification(BaseModel):
    """Ilova-ichi (in-app) xabarnoma — mijozga buyurtma holati o'zgarganda,
    xodimga vazifa tayinlanganda/boshlashga tayyor bo'lganda yaratiladi
    (qarang `apps.notifications.services`). Push (FCM/APNs) hali ulanmagan —
    bu model shu tayyor bo'lganda ham o'zgarishsiz qoladi, faqat yetkazish
    qatlami (device token + push yuborish) ustiga qo'shiladi."""

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    notif_type = models.CharField(max_length=30, choices=NotificationType.choices)
    title = models.CharField(max_length=200)
    body = models.CharField(max_length=500, blank=True)
    order = models.ForeignKey(
        "orders.Order", on_delete=models.CASCADE, null=True, blank=True, related_name="+"
    )
    workflow_instance = models.ForeignKey(
        "workflow.WorkflowStepInstance", on_delete=models.CASCADE, null=True, blank=True, related_name="+"
    )
    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.recipient} — {self.title}"


class DevicePlatform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"


class PushDevice(BaseModel):
    """Foydalanuvchining ro'yxatdan o'tgan qurilmasi — ikki vazifani
    bajaradi: (1) push (FCM) yetkazish manzili (`token`), (2) mobil so'rov
    imzosi (HMAC) uchun qurilma identifikatori (`device_id`) va nazorat
    holati (`vcode`/`is_active`/`revoked_at`) — qarang
    `apps.notifications.security.DeviceSignatureMiddleware`.

    `updated_at` (BaseModel'dan meros) HAR BIR muvaffaqiyatli imzolangan
    so'rovda yangilanadi va spetsifikatsiyadagi `last_updated` vazifasini
    bajaradi — shundan `day_delta` server tomonida qayta hisoblanadi
    (mijoz yuborgan qiymatga ishonilmaydi)."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="push_devices"
    )
    # FCM push manzili — push ruxsat berilmagan/hali olinmagan bo'lsa bo'sh
    # qoldirilishi mumkin (qurilma baribir so'rov-imzosi uchun ro'yxatdan
    # o'tgan bo'ladi).
    token = models.CharField(max_length=255, unique=True, null=True, blank=True)
    platform = models.CharField(max_length=10, choices=DevicePlatform.choices, default=DevicePlatform.ANDROID)

    # Mijoz tomonida BIR MARTA generatsiya qilinib, doimiy saqlanadigan
    # (masalan shared_preferences'da) barqaror identifikator — `token`dan
    # farqli, FCM tomonidan hech qachon o'zgartirilmaydi. Imzo (`signature`)
    # shu qiymatga bog'liq hisoblanadi.
    device_id = models.CharField(max_length=128, unique=True, null=True, blank=True)
    device_name = models.CharField(max_length=150, blank=True)
    app_version = models.CharField(max_length=20, blank=True)
    vcode = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    last_seen = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.user} — {self.platform} ({self.device_id or self.token or self.id})"
