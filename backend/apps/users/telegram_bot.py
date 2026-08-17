"""Telegram bot bilan ishlash: webhook registratsiyasi va Bot API'ga
so'rovlar (`getMe`, `sendMessage`) — login/hisob bog'lash mantig'i esa
`views.py`dagi `TelegramWebhookView`/`TelegramSessionPollView`da."""

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


def get_bot_username() -> str | None:
    """Bot username'ini qaytaradi (`https://t.me/<username>?start=...`
    deep-link uchun) — `TELEGRAM_BOT_USERNAME` sozlangan bo'lsa shundan,
    aks holda Telegram'ning `getMe`sidan bir martalik so'raladi."""
    if settings.TELEGRAM_BOT_USERNAME:
        return settings.TELEGRAM_BOT_USERNAME
    token = settings.TELEGRAM_BOT_TOKEN
    if not token:
        return None
    try:
        resp = requests.get(f"{TELEGRAM_API_BASE}/bot{token}/getMe", timeout=10)
        data = resp.json()
    except (requests.RequestException, ValueError):
        logger.exception("Telegram getMe so'rovi muvaffaqiyatsiz tugadi")
        return None
    if not data.get("ok"):
        return None
    return data["result"].get("username")


def send_message(chat_id: int, text: str) -> None:
    """Foydalanuvchiga botdan xabar yuboradi (masalan sessiya bog'langanini
    tasdiqlash) — xato bo'lsa jim log yozadi, chaqiruvchi oqimni buzmaydi."""
    token = settings.TELEGRAM_BOT_TOKEN
    if not token:
        return
    try:
        requests.post(
            f"{TELEGRAM_API_BASE}/bot{token}/sendMessage",
            json={"chat_id": chat_id, "text": text},
            timeout=10,
        )
    except requests.RequestException:
        logger.exception("Telegram sendMessage so'rovi muvaffaqiyatsiz tugadi")
