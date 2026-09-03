from django.db.models import Q
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.workflow.models import StepStatus

from .models import DevicePlatform, Notification, NotificationType, PushDevice
from .serializers import NotificationSerializer


class NotificationViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Foydalanuvchining o'z xabarnomalari — mijoz (buyurtma holati) va
    xodim (vazifa tayinlash/tayyorlik) uchun bitta ro'yxat, `recipient`ga
    qarab avtomatik cheklanadi. `retrieve` (`GET /notifications/{id}/`)
    ilova tomonidan bitta xabarnoma hali dolzarbmi (masalan "erkin
    topshiriq" hali ochiqmi) tekshirish uchun ishlatiladi — pastdagi
    filtr tufayli eskirgan bo'lsa 404 qaytaradi (qarang mobil
    `notifications_screen.dart::_checkStillOpen`)."""

    serializer_class = NotificationSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = Notification.objects.filter(recipient=self.request.user, is_deleted=False)
        # "Erkin topshiriq" (TASK_POOL_OPEN) bir nechta ustaga BIR VAQTDA
        # yuboriladi, lekin faqat bittasi qabul qila oladi — boshqa usta
        # allaqachon olib ulgurgan yoki bosqich endi "ochiq havzada" bo'lmasa
        # (bekor qilingan, boshqa holatga o'tgan) bu xabarnoma endi hech
        # kimga ochilmaydigan "o'lik" holga tushadi, shuning uchun bu yerda
        # butunlay ko'rsatilmaydi (`unread_count` ham shu queryset'dan
        # foydalanadi — sanoq ham to'g'irlanadi). Mezon `open_pool`dagi
        # bilan bir xil (qarang apps.workflow.views.WorkflowStepInstanceViewSet).
        stale_pool = Q(notif_type=NotificationType.TASK_POOL_OPEN) & (
            Q(workflow_instance__isnull=True)
            | Q(workflow_instance__employee__isnull=False)
            | ~Q(workflow_instance__status=StepStatus.PENDING)
        )
        return qs.exclude(stale_pool)

    @action(detail=False, methods=["get"])
    def unread_count(self, request):
        count = self.get_queryset().filter(is_read=False).count()
        return Response({"count": count})

    @action(detail=False, methods=["post"])
    def mark_all_read(self, request):
        self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({"status": "ok"})

    @action(detail=True, methods=["post"])
    def mark_read(self, request, pk=None):
        notif = self.get_object()
        if not notif.is_read:
            notif.is_read = True
            notif.save(update_fields=["is_read"])
        return Response(NotificationSerializer(notif).data)

    @action(detail=False, methods=["post"])
    def register_device(self, request):
        """Ilova login bo'lgach (yoki FCM token/app versiyasi yangilanganda)
        chaqiriladi. `device_id` — mijoz tomonida bir marta generatsiya
        qilinib doimiy saqlanadigan barqaror identifikator (so'rov-imzosi
        uchun asosiy kalit, qarang apps.notifications.security); `token` —
        FCM push manzili, push ruxsat berilmagan bo'lsa bo'sh bo'lishi
        mumkin. Qurilma boshqa userga tegishli bo'lib qolgan bo'lsa
        (masalan shu qurilmada avval boshqa hisob bilan kirilgan bo'lsa) —
        egasi shu userga o'tkaziladi va (agar avval bekor qilingan bo'lsa)
        qayta faollashtiriladi."""
        device_id = request.data.get("device_id")
        if not device_id:
            return Response({"detail": "device_id majburiy"}, status=status.HTTP_400_BAD_REQUEST)

        defaults = {
            "user": request.user,
            "platform": request.data.get("platform") or DevicePlatform.ANDROID,
            "is_deleted": False,
            "is_active": True,
            "revoked_at": None,
        }
        if request.data.get("token"):
            defaults["token"] = request.data["token"]
        if request.data.get("device_name"):
            defaults["device_name"] = request.data["device_name"]
        if request.data.get("app_version"):
            defaults["app_version"] = request.data["app_version"]
        if request.data.get("vcode") is not None:
            try:
                defaults["vcode"] = int(request.data["vcode"])
            except (TypeError, ValueError):
                pass

        PushDevice.objects.update_or_create(device_id=device_id, defaults=defaults)
        return Response({"status": "ok"})

    @action(detail=False, methods=["post"])
    def unregister_device(self, request):
        """Logout bo'lganda chaqiriladi — shu qurilma endi hech kimga push
        olmasligi va so'rov imzolay olmasligi kerak (keyingi foydalanuvchi
        login bo'lganda qayta ro'yxatdan o'tkaziladi)."""
        device_id = request.data.get("device_id")
        token = request.data.get("token")
        if device_id:
            PushDevice.objects.filter(device_id=device_id).delete()
        elif token:
            PushDevice.objects.filter(token=token).delete()
        return Response({"status": "ok"})
