from django.apps import AppConfig


class AppVersionsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.app_versions"
    verbose_name = "Versiya nazorati"

    def ready(self):
        from . import signals  # noqa: F401
