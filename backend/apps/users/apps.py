import os
import sys

from django.apps import AppConfig


class UsersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.users"
    label = "users"

    def ready(self):
        # `manage.py test`da tarmoqqa chiqmaymiz. `runserver` autoreload
        # ishlatganda Django ikkita jarayon ochadi (kuzatuvchi + haqiqiy
        # server) — faqat haqiqiy server (`RUN_MAIN=true`) chaqirsin, aks
        # holda har bir kod o'zgarishida ikki marta so'rov ketardi.
        if "test" in sys.argv:
            return
        if "runserver" in sys.argv and os.environ.get("RUN_MAIN") != "true":
            return

        from . import telegram_bot

        telegram_bot.set_webhook()
