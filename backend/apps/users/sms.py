"""Eskiz.uz SMS provayderi — OTP kodlarni haqiqiy SMS qilib yuboradi.

`ESKIZ_ENABLED=True` va `ESKIZ_EMAIL`/`ESKIZ_PASSWORD` berilmagan bo'lsa
(lokal/dev yoki moderatsiya kutilayotgan paytda) `is_configured()` False bo'ladi va OTP avvalgidek javobda `debug_code` sifatida qaytariladi."""
import logging
import re

import requests
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)

BASE_URL = "https://notify.eskiz.uz/api"
TOKEN_CACHE_KEY = "eskiz_token"
TOKEN_TTL = 20 * 24 * 3600  # Eskiz tokeni ~30 kun yashaydi
TIMEOUT = 10


# Eskiz moderatsiyasidan o'tgan matn — o'zgartirsangiz qayta moderatsiya kerak.
# Moderatsiyaga shu matnni haqiqiy 6 xonali kod bilan (masalan 1234) topshiring:
# o'zgaruvchan qismni moderatorning o'zi maskalaydi, bizda `****` almashtirish yo'q.
OTP_TEMPLATE = "Kodni hech kimga bermang! vidamarket.uz saytiga kirish uchun tasdiqlash kodi: {code}"


class SMSError(Exception):
    pass


def is_configured() -> bool:
    return bool(settings.ESKIZ_ENABLED and settings.ESKIZ_EMAIL and settings.ESKIZ_PASSWORD)


def normalize_phone(phone: str) -> str:
    """'+998 88 236-80-06' / '882368006' -> '998882368006'."""
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) == 9:
        digits = "998" + digits
    return digits


def _login() -> str:
    try:
        resp = requests.post(
            f"{BASE_URL}/auth/login",
            data={"email": settings.ESKIZ_EMAIL, "password": settings.ESKIZ_PASSWORD},
            timeout=TIMEOUT,
        )
        token = resp.json().get("data", {}).get("token")
    except (requests.RequestException, ValueError) as exc:
        logger.warning("Eskiz login xatosi: %s", exc)
        raise SMSError(f"Eskiz login xatosi: {exc}") from exc
    if not token:
        logger.warning("Eskiz login rad etildi: %s %s", resp.status_code, resp.text[:200])
        raise SMSError("Eskiz login rad etildi")
    cache.set(TOKEN_CACHE_KEY, token, TOKEN_TTL)
    return token


def _post_sms(token: str, phone: str, text: str) -> requests.Response:
    return requests.post(
        f"{BASE_URL}/message/sms/send",
        headers={"Authorization": f"Bearer {token}"},
        data={"mobile_phone": phone, "message": text, "from": settings.ESKIZ_FROM},
        timeout=TIMEOUT,
    )


def send_sms(phone: str, text: str) -> None:
    """SMS yuboradi; muvaffaqiyatsiz bo'lsa `SMSError`. Token eskirgan
    bo'lsa (401) bir marta qayta login qilib urinadi."""
    number = normalize_phone(phone)
    token = cache.get(TOKEN_CACHE_KEY) or _login()
    try:
        resp = _post_sms(token, number, text)
        if resp.status_code == 401:
            resp = _post_sms(_login(), number, text)
    except requests.RequestException as exc:
        logger.warning("Eskiz so'rovi xatosi: %s", exc)
        raise SMSError(f"Eskiz so'rovi xatosi: {exc}") from exc
    if resp.status_code >= 400:
        logger.warning("Eskiz SMS rad etildi: %s %s", resp.status_code, resp.text[:200])
        raise SMSError("SMS yuborib bo'lmadi")


def send_otp(phone: str, code: str) -> None:
    send_sms(phone, OTP_TEMPLATE.format(code=code))
