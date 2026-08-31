from .base import *  # noqa

# MUHIM: bu server nafaqat lokal dev uchun, balki `.qrbite.uz` ORQALI
# TASHQI INTERNETGA HAM ochiq (qarang pastdagi ALLOWED_HOSTS izohi) — shuning
# uchun DEBUG standart holatda O'CHIQ. Faqat haqiqatan ham lokal debugging
# kerak bo'lganda `.env`ga `DEBUG=True` qo'shib vaqtincha yoqing — aks holda
# har qanday xato (404/500) butun internetga ichki fayl yo'llari, URL
# ro'yxati va hatto stack trace'ni ko'rsatib qo'yadi.
DEBUG = env.bool("DEBUG", default=False)
CORS_ALLOW_ALL_ORIGINS = True

# Lokal subdomen portallari: lvh.me va uning subdomenlari 127.0.0.1 ga ishora qiladi
# (domen.uz → lvh.me, admin.domen.uz → admin.lvh.me, firma.domen.uz → firma.lvh.me).
# LAN IP — USB/wifi orqali ulangan haqiqiy iOS qurilma shu orqali kiradi.
# Tailscale IP — Android (Flutter) qurilma tarmoq izolyatsiyasi tufayli LAN
# o'rniga Tailscale VPN orqali ulanadi (Mac'ning Tailscale manzili).
# .ngrok-free.app — Telegram webhook sinovlari uchun (bepul tarifda subdomen
# har ishga tushirishda o'zgaradi, shuning uchun butun domen ruxsat etiladi).
# .qrbite.uz — haqiqiy domen, VPS'dagi nginx Tailscale orqali shu Mac'ga
# reverse-proxy qiladi (qarang deploy/nginx/qrbite.uz.conf).
ALLOWED_HOSTS = [
    ".lvh.me", "localhost", "127.0.0.1", "192.168.100.185", "100.69.182.71",
    ".ngrok-free.app", ".qrbite.uz",
]
