"""WebSocket'lar uchun JWT autentifikatsiyasi — REST API bilan bir xil
Access Token'dan foydalanadi (qarang apps.users, SIMPLE_JWT sozlamalari).
Brauzer/mobil WS ulanishda maxsus header qo'shib bo'lmaydi (JS
`WebSocket` API buni qo'llab-quvvatlamaydi), shuning uchun token URL
query orqali uzatiladi: `wss://host/ws/notifications/?token=<access>`
— bu standart HTTPS/WSS transport ostida ketadi (TLS bilan shifrlangan),
xuddi boshqa so'rov parametrlari kabi."""
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def _user_from_token(token):
    from apps.users.models import User

    try:
        validated = AccessToken(token)
        return User.objects.get(pk=validated["user_id"], is_active=True)
    except (TokenError, User.DoesNotExist, KeyError):
        return AnonymousUser()


class JWTAuthMiddleware:
    """ASGI middleware — `scope["user"]`ni JWT access tokendan aniqlaydi.
    Token yo'q/yaroqsiz bo'lsa `AnonymousUser` (consumer o'zi rad etadi)."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        query_string = scope.get("query_string", b"").decode()
        token = parse_qs(query_string).get("token", [None])[0]
        scope["user"] = await _user_from_token(token) if token else AnonymousUser()
        return await self.app(scope, receive, send)


def JWTAuthMiddlewareStack(app):
    return JWTAuthMiddleware(app)
