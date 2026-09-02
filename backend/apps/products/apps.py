import os
import sys

from django.apps import AppConfig


class ProductsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.products"
    label = "products"

    def ready(self):
        # CLIP modeli avval FAQAT birinchi "rasm bilan qidirish" so'rovida
        # yuklanardi (~80s) — shu foydalanuvchi bekorga kutardi. Endi server
        # ISHGA TUSHGANDA (birinchi so'rovdan OLDIN) yuklab qo'yamiz.
        #
        # MUHIM: faqat haqiqatan serverni ishga tushiradigan buyruqda
        # ("runserver") — `manage.py shell`/`migrate`/`check` kabi oddiy
        # buyruqlarni ham 80 soniyaga sekinlashtirib qo'ymaslik uchun.
        # `runserver`ning autoreload kuzatuvchi jarayonida (RUN_MAIN hali
        # yo'q) ham ishlamaydi — aks holda ikki marta yuklanardi.
        if "runserver" not in sys.argv:
            return
        # Autoreload YOQILGAN (standart) holatda Django ikkita jarayon
        # ochadi — kuzatuvchi (watcher, RUN_MAIN hali "true" bo'lmagan) va
        # haqiqiy server. Faqat haqiqiy serverda yuklaymiz. `--noreload`
        # bilan ishga tushirilganda RUN_MAIN umuman o'rnatilmaydi — bu
        # yagona jarayonning o'zi, watcher emas.
        is_autoreload_watcher = "--noreload" not in sys.argv and os.environ.get("RUN_MAIN") != "true"
        if is_autoreload_watcher:
            return

        from . import embedding

        embedding.preload_model()
