"""FCM (Firebase Cloud Messaging) orqali real push yuborish.

`apps.notifications.services`dagi in-app `Notification` yozuvidan farqli —
bu funksiya foydalanuvchining ro'yxatdan o'tgan qurilmalariga (`PushDevice`)
ilova yopiq/fon holatida bo'lsa ham OS xabarnoma tokchasiga chiqadigan push
yuboradi. `FIREBASE_CREDENTIALS_PATH` sozlanmagan bo'lsa (masalan lokal dev
muhitida hali Firebase key qo'yilmagan bo'lsa) — jim o'tkazib yuboriladi,
xato chiqarmaydi (in-app xabarnoma baribir yaratilgan bo'ladi).
"""
import logging

from django.conf import settings

logger = logging.getLogger(__name__)

_firebase_app = None
_firebase_init_failed = False


def _get_app():
    """Firebase Admin SDK ilovasini bir marta ishga tushiradi (lazy —
    Django ishga tushishida emas, birinchi push yuborilganda), shunda
    credential fayli hali yo'q bo'lsa ham server xatosiz ko'tariladi."""
    global _firebase_app, _firebase_init_failed
    if _firebase_app is not None or _firebase_init_failed:
        return _firebase_app
    if not settings.FIREBASE_CREDENTIALS_PATH:
        _firebase_init_failed = True
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS_PATH)
        _firebase_app = firebase_admin.initialize_app(cred)
    except Exception:
        logger.exception("Firebase Admin SDK ishga tushmadi — push o'chirilgan holda qoladi")
        _firebase_init_failed = True
    return _firebase_app


def send_push(user, title, body, data=None):
    """`user`ning barcha ro'yxatdan o'tgan qurilmalariga push yuboradi.
    Eskirgan/bekor qilingan token uchun FCM xato qaytarsa, o'sha
    `PushDevice` yozuvi o'chiriladi (qarang firebase_admin.messaging
    xatolik turlari: UnregisteredError va shunga o'xshash)."""
    app = _get_app()
    if app is None:
        return

    from .models import PushDevice

    devices = list(PushDevice.objects.filter(user=user, is_deleted=False))
    if not devices:
        return

    from firebase_admin import messaging

    for device in devices:
        message = messaging.Message(
            token=device.token,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(priority="high"),
        )
        try:
            messaging.send(message, app=app)
        except messaging.UnregisteredError:
            device.delete()
        except Exception:
            logger.exception("Push yuborilmadi: user=%s device=%s", user.id, device.id)
