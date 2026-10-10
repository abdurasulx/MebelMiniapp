"""Sign in with Apple — identity token (JWT, RS256) server-side verifikatsiyasi.

Apple'ning public kalitlari (`https://appleid.apple.com/auth/keys`) bilan imzo,
`iss`, `aud` (bizning bundle ID) va muddat tekshiriladi — frontenddan kelgan
hech qanday claim'ga to'g'ridan-to'g'ri ishonilmaydi.
"""
import jwt
from django.conf import settings
from jwt import PyJWKClient
from rest_framework.exceptions import ValidationError

APPLE_ISSUER = "https://appleid.apple.com"
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"

_jwk_client = PyJWKClient(APPLE_JWKS_URL, cache_keys=True, lifespan=3600)


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
