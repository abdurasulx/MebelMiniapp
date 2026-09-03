"""WebSocket orqali bildirishnoma sanog'ini real vaqtda yuborish — avval
30s'da bir marta HTTP so'rov (`/notifications/unread_count/`) bilan
so'ralardi (qarang git tarixi), endi shu funksiya har bir yangi
xabarnoma/o'qilgan belgilanganda (`apps.notifications.services`,
`apps.notifications.views`) chaqirilib, ulangan mijozga darhol yangi
sonni yetkazadi. Real push (FCM, OS xabarnoma tokchasi) bilan
ARALASHTIRILMAYDI — bu FAQAT ilova OCHIQ turgan paytdagi qo'ng'iroq
sanog'i uchun (qarang consumers.py)."""
import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

logger = logging.getLogger(__name__)


def push_unread_count(user_id):
    """Berilgan foydalanuvchining ulangan WebSocket'lariga (agar bo'lsa)
    joriy o'qilmagan sonini yuboradi. Channel layer sozlanmagan yoki
    hech kim ulanmagan bo'lsa — jim o'tkaziladi (xato chiqarmaydi, FCM
    push baribir alohida yuboriladi)."""
    layer = get_channel_layer()
    if layer is None or user_id is None:
        return
    from .models import Notification

    # `visible_for` FK maydonini filtrlaydi — Django FK filtriga to'g'ridan-
    # to'g'ri pk (obyekt emas, `user_id`) berish ham ishlaydi.
    count = Notification.objects.visible_for(user_id).filter(is_read=False).count()
    try:
        async_to_sync(layer.group_send)(
            f"notifications_{user_id}",
            {"type": "notify", "data": {"type": "unread_count", "count": count}},
        )
    except Exception:
        logger.exception("WS bildirishnoma yuborilmadi: user=%s", user_id)
