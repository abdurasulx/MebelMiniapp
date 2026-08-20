from django.conf import settings
from django.db import models

from common.models import BaseModel


class NotificationType(models.TextChoices):
    ORDER_STATUS = "order_status", "Buyurtma holati"
    TASK_ASSIGNED = "task_assigned", "Vazifa tayinlandi"
    TASK_AVAILABLE = "task_available", "Vazifa boshlashga tayyor"


class Notification(BaseModel):
    """Ilova-ichi (in-app) xabarnoma — mijozga buyurtma holati o'zgarganda,
    xodimga vazifa tayinlanganda/boshlashga tayyor bo'lganda yaratiladi
    (qarang `apps.notifications.services`). Push (FCM/APNs) hali ulanmagan —
    bu model shu tayyor bo'lganda ham o'zgarishsiz qoladi, faqat yetkazish
    qatlami (device token + push yuborish) ustiga qo'shiladi."""

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    notif_type = models.CharField(max_length=20, choices=NotificationType.choices)
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
