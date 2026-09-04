from django.conf import settings
from django.db import models
from django.db.models import Q

from common.models import BaseModel


class NotificationType(models.TextChoices):
    ORDER_STATUS = "order_status", "Buyurtma holati"
    TASK_ASSIGNED = "task_assigned", "Vazifa tayinlandi"
    TASK_AVAILABLE = "task_available", "Vazifa boshlashga tayyor"
    MATERIAL_SUGGESTION = "material_suggestion", "Material tavsiyasi"
    TASK_POOL_OPEN = "task_pool_open", "Yangi erkin topshiriq"
    TASK_APPLICATION_REJECTED = "task_application_rejected", "Zayavka rad etildi"
    ATTENDANCE_REJECTED = "attendance_rejected", "Davomat rad etildi"


class NotificationQuerySet(models.QuerySet):
    def visible_for(self, user):
        """Foydalanuvchiga ko'rsatiladigan xabarnomalar — REST ro'yxati
        (`NotificationViewSet`) va WebSocket sanog'i (`consumers.py`)
        IKKALASI ham shu bir xil filtrdan foydalanadi (bir joyda saqlash —
        boshqacha bo'lib qolmasin). "Erkin topshiriq" (TASK_POOL_OPEN) bir
        nechta ustaga bir vaqtda yuboriladi, lekin faqat bittasi qabul
        qila oladi — boshqa usta olib ulgurgan yoki bosqich holati
        o'zgargan (endi ochiq havzada emas) bo'lsa, bu yerda ko'rsatilmaydi
        (mezon `WorkflowStepInstanceViewSet.open_pool` bilan bir xil)."""
        from apps.workflow.models import StepStatus

        qs = self.filter(recipient=user, is_deleted=False)
        stale_pool = Q(notif_type=NotificationType.TASK_POOL_OPEN) & (
            Q(workflow_instance__isnull=True)
            | Q(workflow_instance__employee__isnull=False)
            | ~Q(workflow_instance__status=StepStatus.PENDING)
        )
        return qs.exclude(stale_pool)


class Notification(BaseModel):
    """Ilova-ichi (in-app) xabarnoma — mijozga buyurtma holati o'zgarganda,
    xodimga vazifa tayinlanganda/boshlashga tayyor bo'lganda yaratiladi
    (qarang `apps.notifications.services`). Real push (FCM) — bu yozuv
    yaratilgan paytda `send_push()` orqali ham yuboriladi (qarang
    `apps.notifications.push`); bu model shundan qat'iy nazar o'zgarishsiz
    qoladi, faqat yetkazish qatlami (device token + push yuborish)."""

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

    objects = NotificationQuerySet.as_manager()

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.recipient} — {self.title}"


class DevicePlatform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"
    WEB = "web", "Web"


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
