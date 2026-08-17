"""Telegram bot webhook boshqaruvi.

Hozircha faqat webhook registratsiyasi (`set_webhook`) va uni qabul
qiladigan endpoint (`TelegramWebhookView`, qarang views.py) mavjud — bot
orqali login/hisob bog'lash logikasi (session_id asosida) hali
loyihalanmagan, keyingi bosqichda shu joyga qo'shiladi. Hozirgi maqsad:
backend ishga tushganda webhook'ni qo'lda emas, avtomatik bog'lab qo'yish.
"""

import logging

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

TELEGRAM_API_BASE = "https://api.telegram.org"


def set_webhook() -> bool:
    """Botga webhook URL'ni ro'yxatdan o'tkazadi (Telegram `setWebhook`).

    `TELEGRAM_BOT_TOKEN` yoki `TELEGRAM_WEBHOOK_URL` hali sozlanmagan
    bo'lsa hech narsa qilmaydi (jim o'tkazib yuboriladi — dev muhitda
    xatolik chiqmasligi uchun). Tarmoq xatosi bo'lsa ham backend ishga
    tushishini to'xtatmaydi, faqat log yozadi.
    """
    token = settings.TELEGRAM_BOT_TOKEN
    base_url = settings.TELEGRAM_WEBHOOK_URL
    if not token or not base_url:
        return False

    webhook_url = f"{base_url.rstrip('/')}/api/v1/auth/telegram/webhook/"
    payload = {"url": webhook_url}
    if settings.TELEGRAM_WEBHOOK_SECRET:
        payload["secret_token"] = settings.TELEGRAM_WEBHOOK_SECRET

    try:
        resp = requests.post(
            f"{TELEGRAM_API_BASE}/bot{token}/setWebhook", json=payload, timeout=10
        )
        data = resp.json()
    except (requests.RequestException, ValueError):
        logger.exception("Telegram setWebhook so'rovi muvaffaqiyatsiz tugadi")
        return False

    if not data.get("ok"):
        logger.warning("Telegram setWebhook rad etildi: %s", data)
        return False

    logger.info("Telegram webhook ro'yxatdan o'tkazildi: %s", webhook_url)
    return True
