"""Google ID token'ni server-side verifikatsiya qilish (docs: Google Login).

Faqat ID token (Google Identity Services'dan kelgan `credential`) qabul
qilinadi — access token emas. `id_token.verify_oauth2_token` imzo, `aud`
(bizning Client ID'ga mosligi), `iss` va muddatni Google'ning public
kalitlaridan avtomatik tekshiradi, shuning uchun frontenddan kelgan hech
qanday claim'ga to'g'ridan-to'g'ri ishonilmaydi.
"""

from django.conf import settings
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from rest_framework.exceptions import ValidationError


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
