"""Furniture Platform — base settings (docs/30, techdocs/03)."""
import sys
from datetime import timedelta
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env")

# `manage.py test` orqali ishga tushirilganda — CLIP/Qdrant kabi disk holatiga
# bog'liq modullar test izolyatsiyasi uchun shu flagga qaraydi (masalan
# in-memory Qdrant ishlatish, disk lock to'qnashuvidan qochish).
TESTING = "test" in sys.argv

SECRET_KEY = env("SECRET_KEY", default="insecure-dev-key-change-me")
DEBUG = env.bool("DEBUG", default=False)
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # third-party
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    # local apps
    "apps.users",
    "apps.companies",
    "apps.products",
    "apps.orders",
    "apps.assets",
    "apps.crm",
    "apps.production",
    "apps.likes",
    "apps.workflow",
    "apps.projects",
    "apps.inventory",
    "apps.cart",
    "apps.notifications",
    "apps.ar_collections",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    # Mobil ilova so'rovlari uchun qo'shimcha HMAC imzo qatlami (nwupdate.md) —
    # faqat `X-Device-Id` headeri bor so'rovlarga qo'llanadi, veb frontend'ga
    # tegmaydi (qarang apps/notifications/security.py).
    "apps.notifications.security.DeviceSignatureMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": env.db("DATABASE_URL", default="postgres:///furniture_platform"),
}

AUTH_USER_MODEL = "users.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=30),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
}

LANGUAGE_CODE = "uz"
TIME_ZONE = "Asia/Tashkent"
USE_I18N = True
USE_TZ = True

# Fayl saqlash rejimi: "local" (dev) yoki "cloud" (Google Drive/S3 — keyin).
# Fayl yuklanganda rejim yozuvga muhrlanadi; rejim mos kelmagan fayllar API'da ko'rinmaydi.
STORAGE_MODE = env("STORAGE_MODE", default="local")

# Google Login (Sign in with Google) — qarang apps/users/google_auth.py.
# Klassik OAuth 2.0 Authorization Code flow ishlatiladi (GIS JS SDK'siz —
# uning iframe/popup asosidagi bog'lanishi Chrome'da uchinchi tomon cookie
# bloklanganda `gsi/transform`da abadiy osilib qolishi mumkin edi). Shuning
# uchun Client Secret HAM kerak (kod-tokenga almashtirish uchun).
GOOGLE_CLIENT_ID = env("GOOGLE_CLIENT_ID", default="")
GOOGLE_CLIENT_SECRET = env("GOOGLE_CLIENT_SECRET", default="")

# Native ilovalar (iOS/Android) platformaning o'z (native) OAuth Client ID'i
# bilan Google Sign-In qiladi — bu ID token'ning `aud` (audience) qiymati
# HAR DOIM shu native Client ID bo'ladi, `GOOGLE_CLIENT_ID` (Web) EMAS
# (Android'da Flutter `google_sign_in` paketi `serverClientId` bergani uchun
# istisno — u web audience'li token qaytaradi, lekin iOS'dagi `GoogleSignIn`
# SDK bunday emas: `GIDClientID` doim o'zining audience'i bo'lib qoladi).
# Shuning uchun `verify_google_credential` bir nechta audience'ni qabul
# qiladi — qarang apps/users/google_auth.py.
GOOGLE_IOS_CLIENT_ID = env("GOOGLE_IOS_CLIENT_ID", default="")

# Market (asosiy) frontend'ning ochiq manzili — Google callback (qarang
# apps/users/views.py: GoogleLoginCallbackView) shu yerga JWT bilan qaytarib
# yuboradi (`?access=&refresh=` — main.jsx'dagi mavjud portal-o'tkazish
# mexanizmi bilan bir xil naqsh).
FRONTEND_URL = env("FRONTEND_URL", default="http://localhost:5173")

# Backend'ning tashqi dunyoga ochiq manzili — Google'ga `redirect_uri`
# sifatida beriladi (Google Console'dagi "Authorized redirect URIs" bilan
# ANIQ mos kelishi shart).
BACKEND_URL = env("BACKEND_URL", default="http://127.0.0.1:8000")

# Telegram bot login (webhook) — qarang apps/users/telegram_bot.py.
TELEGRAM_BOT_TOKEN = env("TELEGRAM_BOT_TOKEN", default="")
TELEGRAM_BOT_USERNAME = env("TELEGRAM_BOT_USERNAME", default="")
TELEGRAM_WEBHOOK_URL = env("TELEGRAM_WEBHOOK_URL", default="")
TELEGRAM_WEBHOOK_SECRET = env("TELEGRAM_WEBHOOK_SECRET", default="")

# Push (FCM) — Firebase konsoli > Project Settings > Service Accounts >
# "Generate new private key" orqali olingan JSON fayl yo'li. Bo'sh bo'lsa
# (default), push jim o'tkazib yuboriladi — qarang apps/notifications/push.py.
# MUHIM: bu fayl HECH QACHON git'ga commit qilinmasin (.gitignore'da).
FIREBASE_CREDENTIALS_PATH = env("FIREBASE_CREDENTIALS_PATH", default="")

# Mobil so'rov-imzosi (HMAC-SHA256, nwupdate.md §5) sirri — qarang
# apps/notifications/security.py. MUHIM: bu APK ichiga joylashtiriladigan
# sir emas (u reverse-engineering'dan himoyalanmagan) — asosiy xavfsizlik
# baribir Access/Refresh Token orqali; bu faqat qo'shimcha qatlam. Prodda
# `.env`da o'ziga xos qiymat bilan almashtirilishi kerak.
DEVICE_HMAC_SECRET = env("DEVICE_HMAC_SECRET", default=SECRET_KEY)

# Shu vcode'dan past bo'lgan mobil ilova versiyalari 403/UPDATE_REQUIRED
# bilan rad etiladi (nwupdate.md §11). 0 — hozircha hech qanday versiya
# bloklanmaydi (min talab qo'yilmagan).
MOBILE_MIN_VCODE = env.int("MOBILE_MIN_VCODE", default=0)

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
