import re

from django.conf import settings
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.static import serve as serve_static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/", include("api.v1.urls")),
]

# nginx (deploy/nginx/qrbite.uz.conf) uchun alohida `/media/` location'i
# yo'q — hammasi Django'ga proksi qilinadi. `django.conf.urls.static.static()`
# yordamchisi ISHLATILMAYDI — u ichida `settings.DEBUG`ni o'zi tekshirib,
# DEBUG=False bo'lganda JIM ravishda bo'sh ro'yxat qaytaradi (bizning tashqi
# `if`imizdan mustaqil ravishda) — shuning uchun mahsulot rasmlari
# DEBUG'ni xavfsizlik uchun o'chirgandan keyin butunlay 404 bera boshlagan
# edi. Pastdagi `re_path` shu DEBUG-tekshiruvisiz, to'g'ridan-to'g'ri serve
# view'ini ro'yxatdan o'tkazadi.
urlpatterns += [
    re_path(
        r"^%s(?P<path>.*)$" % re.escape(settings.MEDIA_URL.lstrip("/")),
        serve_static,
        {"document_root": settings.MEDIA_ROOT},
    ),
]
