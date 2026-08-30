from rest_framework import mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import DevicePlatform, Notification, PushDevice
from .serializers import NotificationSerializer


class NotificationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Foydalanuvchining o'z xabarnomalari — mijoz (buyurtma holati) va
    xodim (vazifa tayinlash/tayyorlik) uchun bitta ro'yxat, `recipient`ga
    qarab avtomatik cheklanadi."""

    serializer_class = NotificationSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user, is_deleted=False)

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
        """Ilova login bo'lgach (yoki FCM token yangilanganda —
        `onTokenRefresh`) chaqiriladi. Token boshqa userga tegishli bo'lib
        qolgan bo'lsa (masalan shu qurilmada avval boshqa hisob bilan
        kirilgan bo'lsa) — egasi shu userga o'tkaziladi, chunki bitta fizik
        qurilma bir vaqtning o'zida faqat bitta hisobga push olishi kerak."""
        token = request.data.get("token")
        if not token:
            return Response({"detail": "token majburiy"}, status=status.HTTP_400_BAD_REQUEST)
        platform = request.data.get("platform") or DevicePlatform.ANDROID
        PushDevice.objects.update_or_create(
            token=token, defaults={"user": request.user, "platform": platform, "is_deleted": False}
        )
        return Response({"status": "ok"})

    @action(detail=False, methods=["post"])
    def unregister_device(self, request):
        """Logout bo'lganda chaqiriladi — shu qurilma endi hech kimga push
        olmasligi kerak (keyingi foydalanuvchi login bo'lganda qayta
        ro'yxatdan o'tkaziladi)."""
        token = request.data.get("token")
        if token:
            PushDevice.objects.filter(token=token).delete()
        return Response({"status": "ok"})
