"""Sign in with Apple — identity token (JWT, RS256) server-side verifikatsiyasi.

Apple'ning public kalitlari (`https://appleid.apple.com/auth/keys`) bilan imzo,
`iss`, `aud` (bizning bundle ID) va muddat tekshiriladi — frontenddan kelgan
hech qanday claim'ga to'g'ridan-to'g'ri ishonilmaydi.
"""
import logging
import time

import jwt
import requests
from django.conf import settings
from jwt import PyJWKClient
from rest_framework.exceptions import ValidationError

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

logger = logging.getLogger(__name__)

_jwk_client = PyJWKClient(APPLE_JWKS_URL, cache_keys=True, lifespan=3600)

APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token"
APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke"


def verify_apple_identity_token(token: str) -> dict:
    """Tasdiqlangan claim'larni qaytaradi (`sub`, `email`, ...). Yaroqsiz token
    yoki sozlanmagan audience — `ValidationError`."""
    audiences = [a for a in (settings.APPLE_BUNDLE_ID, settings.APPLE_SERVICE_ID) if a]
    if not audiences:
        raise ValidationError("Apple orqali kirish hali sozlanmagan")
    try:
        signing_key = _jwk_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=audiences,
            issuer=APPLE_ISSUER,
        )
    except Exception as exc:  # noqa: BLE001 — jwt/jwks/tarmoq xatolarining hammasi "yaroqsiz token"
        raise ValidationError("Apple tokeni yaroqsiz yoki muddati o'tgan") from exc
    if not claims.get("sub"):
        raise ValidationError("Apple tokenida foydalanuvchi ID yo'q")
    return claims


def revocation_configured() -> bool:
    return bool(
        settings.APPLE_TEAM_ID and settings.APPLE_KEY_ID and settings.APPLE_PRIVATE_KEY_PATH
        and settings.APPLE_BUNDLE_ID
    )


def _client_secret() -> str:
    """Apple `client_secret` — `.p8` kalit bilan imzolangan qisqa muddatli ES256 JWT."""
    with open(settings.APPLE_PRIVATE_KEY_PATH, "r", encoding="utf-8") as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {
            "iss": settings.APPLE_TEAM_ID,
            "iat": now,
            "exp": now + 300,
            "aud": APPLE_ISSUER,
            "sub": settings.APPLE_BUNDLE_ID,
        },
        key,
        algorithm="ES256",
        headers={"kid": settings.APPLE_KEY_ID},
    )


def exchange_authorization_code(code: str) -> str | None:
    """Kirishda olingan `authorization_code`ni refresh tokenga almashtiradi (keyinroq
    revocation uchun saqlanadi). Sozlanmagan yoki xato bo'lsa `None` — kirishni to'xtatmaydi."""
    if not code or not revocation_configured():
        return None
    try:
        resp = requests.post(
            APPLE_TOKEN_URL,
            data={
                "client_id": settings.APPLE_BUNDLE_ID,
                "client_secret": _client_secret(),
                "code": code,
                "grant_type": "authorization_code",
            },
            timeout=10,
        )
        if resp.status_code != 200:
            logger.warning("Apple token almashtirish rad etildi: %s %s", resp.status_code, resp.text[:200])
            return None
        return resp.json().get("refresh_token")
    except Exception:  # noqa: BLE001
        logger.exception("Apple token almashtirish xatosi")
        return None


def revoke_refresh_token(refresh_token: str) -> bool:
    """Hisob o'chirilganda Apple tokenini bekor qiladi (App Store talabi).
    Muvaffaqiyat — `True`; sozlanmagan/xato — `False` (chaqiruvchi jarayonni to'xtatmaydi)."""
    if not refresh_token or not revocation_configured():
        return False
    try:
        resp = requests.post(
            APPLE_REVOKE_URL,
            data={
                "client_id": settings.APPLE_BUNDLE_ID,
                "client_secret": _client_secret(),
                "token": refresh_token,
                "token_type_hint": "refresh_token",
            },
            timeout=10,
        )
        if resp.status_code != 200:
            logger.warning("Apple revoke rad etildi: %s %s", resp.status_code, resp.text[:200])
        return resp.status_code == 200
    except Exception:  # noqa: BLE001
        logger.exception("Apple revoke xatosi")
        return False


def verify_apple_event_token(token: str) -> dict:
    """Server-to-server bildirishnoma JWT'si (Apple imzosi, `aud` = bizning bundle/service ID).
    `events` maydoni JSON satr — ochib, `dict` qaytariladi."""
    import json

    audiences = [a for a in (settings.APPLE_BUNDLE_ID, settings.APPLE_SERVICE_ID) if a]
    try:
        signing_key = _jwk_client.get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token, signing_key.key, algorithms=["RS256"], audience=audiences, issuer=APPLE_ISSUER
        )
        events = claims.get("events")
        return json.loads(events) if isinstance(events, str) else (events or {})
    except Exception as exc:  # noqa: BLE001
        raise ValidationError("Apple bildirishnomasi yaroqsiz") from exc
