from .base import *  # noqa

DEBUG = True
CORS_ALLOW_ALL_ORIGINS = True

# Lokal subdomen portallari: lvh.me va uning subdomenlari 127.0.0.1 ga ishora qiladi
# (domen.uz → lvh.me, admin.domen.uz → admin.lvh.me, firma.domen.uz → firma.lvh.me).
# LAN IP — USB/wifi orqali ulangan haqiqiy iOS qurilma shu orqali kiradi.
ALLOWED_HOSTS = [".lvh.me", "localhost", "127.0.0.1", "192.168.100.185"]
