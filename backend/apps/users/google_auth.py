"""Google ID token'ni server-side verifikatsiya qilish (docs: Google Login).

Faqat ID token (Google Identity Services'dan kelgan `credential`) qabul
qilinadi — access token emas. `id_token.verify_oauth2_token` imzo, `aud`
(bizning Client ID'ga mosligi), `iss` va muddatni Google'ning public
kalitlaridan avtomatik tekshiradi, shuning uchun frontenddan kelgan hech
qanday claim'ga to'g'ridan-to'g'ri ishonilmaydi.
"""

import requests
from django.conf import settings
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from rest_framework.exceptions import ValidationError


def exchange_google_code(code: str, redirect_uri: str) -> str:
    """Authorization Code flow'dagi `code`ni Google'ning token endpoint'ida
    ID token'ga almashtiradi (server-to-server so'rov, Client Secret bilan).

    Qaytaradi: `id_token` (JWT string) — keyin `verify_google_credential`
    orqali tekshiriladi (imzo/audience/muddat), xuddi mobil SDK'dan kelgan
    token kabi.
    """
    resp = requests.post(
        "https://oauth2.googleapis.com/token",
        data={
            "code": code,
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
        },
        timeout=10,
    )
    if resp.status_code != 200:
        raise ValidationError("Google kodi yaroqsiz yoki muddati o'tgan")
    data = resp.json()
    token = data.get("id_token")
    if not token:
        raise ValidationError("Google javobida id_token yo'q")
    return token


def verify_google_credential(credential: str) -> dict:
    """Google ID token'ni tekshiradi va tasdiqlangan claim'larni qaytaradi.

    Noto'g'ri/eskirgan/soxta token — yoki `GOOGLE_CLIENT_ID` hali
    sozlanmagan bo'lsa — `ValidationError` ko'taradi.
    """
    if not settings.GOOGLE_CLIENT_ID:
        raise ValidationError("Google Login hali sozlanmagan")
    try:
        claims = id_token.verify_oauth2_token(
            credential, google_requests.Request(), settings.GOOGLE_CLIENT_ID
        )
    except ValueError:
        raise ValidationError("Google token noto'g'ri yoki muddati o'tgan")

    # `email` scope so'ralganda Google odatda `email_verified: true` beradi;
    # `false` bo'lsa shu email'ga tayanib eski hisobni izlash/bog'lash
    # xavfli — shuning uchun bunday holatda rad etiladi.
    if claims.get("email") and not claims.get("email_verified"):
        raise ValidationError("Google email tasdiqlanmagan")
    return claims
