"""ASGI config for config project.

Django Channels qo'shilgach — endi faqat HTTP emas, WebSocket'ni ham
shu yerda marshrutlaydi (`/ws/notifications/`, qarang
apps/notifications/routing.py). `manage.py runserver` `channels` ilova
ro'yxatida bo'lsa avtomatik shu ASGI ilovasini serve qiladi (alohida
daphne/uvicorn kerak emas — qarang config/settings/base.py
CHANNEL_LAYERS izohi).
"""

import os

import django
from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")
django.setup()

# `apps.notifications.routing` import qilinishidan OLDIN Django to'liq
# ishga tushishi kerak (model importlari bor) — shuning uchun
# `get_asgi_application()`dan keyin, pastda import qilinadi.
from apps.notifications.routing import websocket_urlpatterns  # noqa: E402
from apps.notifications.ws_auth import JWTAuthMiddlewareStack  # noqa: E402

django_asgi_app = get_asgi_application()

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": JWTAuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
    }
)
