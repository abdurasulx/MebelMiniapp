from django.contrib import admin, messages
from django.utils import timezone

from .models import BroadcastNotification, Notification, NotificationType, PushDevice
from .push import send_push
from .ws import push_unread_count


@admin.register(BroadcastNotification)
class BroadcastNotificationAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "delivery_type",
        "target_audience",
        "target_user",
        "is_sent",
        "sent_at",
        "recipients_count",
        "created_at",
    )
    list_filter = ("is_sent", "delivery_type", "target_audience")
    search_fields = ("title", "body")
    readonly_fields = ("is_sent", "sent_at", "recipients_count")
    actions = ("send_now",)

    def save_model(self, request, obj, form, change):
        is_new = obj._state.adding
        super().save_model(request, obj, form, change)
        if is_new and not obj.is_sent:
            self._send_broadcast(request, obj)

    @admin.action(description="Tanlangan xabarnomalarni hoziroq yuborish (Qayta yuborish)")
    def send_now(self, request, queryset):
        for item in queryset:
            self._send_broadcast(request, item)

    def _send_broadcast(self, request, obj):
        from django.contrib.auth import get_user_model

        User = get_user_model()
        if obj.target_user:
            users = [obj.target_user]
        elif obj.target_audience == BroadcastNotification.TargetAudience.ALL:
            users = list(User.objects.filter(is_active=True))
        else:
            users = list(User.objects.filter(is_active=True, role=obj.target_audience))

        if not users:
            messages.warning(request, f"'{obj.title}' uchun mos foydalanuvchilar topilmadi.")
            return

        # 1. In-app xabarnomalarni bazaga saqlash (faqat BOTH yoki INAPP_ONLY bo'lsa)
        if obj.delivery_type in (
            BroadcastNotification.DeliveryType.BOTH,
            BroadcastNotification.DeliveryType.INAPP_ONLY,
        ):
            notifs = [
                Notification(
                    recipient=u,
                    notif_type=NotificationType.BROADCAST,
                    title=obj.title,
                    body=obj.body,
                )
                for u in users
            ]
            Notification.objects.bulk_create(notifs, batch_size=500)

            for u in users:
                try:
                    push_unread_count(u.id)
                except Exception:
                    pass

        # 2. Push (FCM) xabarnoma yuborish (faqat BOTH yoki PUSH_ONLY bo'lsa)
        if obj.delivery_type in (
            BroadcastNotification.DeliveryType.BOTH,
            BroadcastNotification.DeliveryType.PUSH_ONLY,
        ):
            for u in users:
                try:
                    send_push(u, obj.title, obj.body, data={"type": "broadcast"})
                except Exception:
                    pass

        obj.is_sent = True
        obj.sent_at = timezone.now()
        obj.recipients_count = len(users)
        obj.save(update_fields=["is_sent", "sent_at", "recipients_count"])

        delivery_info = (
            "Faqat Push sifatida"
            if obj.delivery_type == BroadcastNotification.DeliveryType.PUSH_ONLY
            else (
                "Faqat Ilova ichida"
                if obj.delivery_type == BroadcastNotification.DeliveryType.INAPP_ONLY
                else "Push va Ilova ichida"
            )
        )
        messages.success(
            request,
            f"'{obj.title}' xabarnomasi ({delivery_info}) {len(users)} ta foydalanuvchiga muvaffaqiyatli yuborildi!",
        )


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("recipient", "notif_type", "title", "is_read", "created_at")
    list_filter = ("notif_type", "is_read")
    search_fields = ("recipient__email", "title", "body")


@admin.register(PushDevice)
class PushDeviceAdmin(admin.ModelAdmin):
    list_display = (
        "user", "device_name", "platform", "vcode", "is_active", "last_seen", "revoked_at", "created_at",
    )
    list_filter = ("platform", "is_active")
    search_fields = ("user__email", "device_id", "device_name", "token")
    actions = ("revoke_devices", "unrevoke_devices")

    @admin.action(description="Tanlangan qurilmalarni bekor qilish (revoke)")
    def revoke_devices(self, request, queryset):
        queryset.update(is_active=False, revoked_at=timezone.now())

    @admin.action(description="Tanlangan qurilmalarni qayta faollashtirish")
    def unrevoke_devices(self, request, queryset):
        queryset.update(is_active=True, revoked_at=None)

