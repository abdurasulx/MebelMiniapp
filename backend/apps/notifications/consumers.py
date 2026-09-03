import json

from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth.models import AnonymousUser


class NotificationConsumer(AsyncWebsocketConsumer):
    """Foydalanuvchi ulanganda o'z guruhiga (`notifications_<user_id>`)
    qo'shiladi — `apps.notifications.ws.push_unread_count` shu guruhga
    yangi son yuboradi (har bir yangi xabarnoma/o'qilgan belgilanganda).
    Ulangan zahoti joriy sonni ham darhol yuboradi (ilova ochilganda
    birinchi qiymat kutib turmasin)."""

    async def connect(self):
        user = self.scope.get("user")
        if user is None or isinstance(user, AnonymousUser):
            await self.close(code=4001)
            return
        self.group_name = f"notifications_{user.id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        # Ulanish payti — hozirgi qiymatni sync-vazifa ichida hisoblab
        # to'g'ridan-to'g'ri shu socket'ga yuboramiz (guruhga emas, faqat
        # shu yangi ulanishga — boshqa allaqachon ulangan sessiyalarni
        # keraksiz qayta xabarlamaslik uchun).
        from asgiref.sync import sync_to_async

        from .models import Notification

        count = await sync_to_async(
            lambda: Notification.objects.visible_for(user).filter(is_read=False).count()
        )()
        await self.send(text_data=json.dumps({"type": "unread_count", "count": count}))

    async def disconnect(self, close_code):
        if hasattr(self, "group_name"):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Mijozdan xabar kutilmaydi (faqat server->client) — jim o'tkaziladi.
        pass

    async def notify(self, event):
        """`channel_layer.group_send`dan keladi (qarang
        `apps.notifications.ws.push_unread_count`) — `event["data"]`ni
        JSON sifatida socket'ga yuboradi."""
        await self.send(text_data=json.dumps(event["data"]))
