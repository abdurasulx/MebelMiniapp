from django.apps import AppConfig


class AssetsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.assets"

    def ready(self):
        from django.db.models.signals import post_save

        from .models import Model3D
        from .signals import enqueue_render_on_model_save

        post_save.connect(enqueue_render_on_model_save, sender=Model3D, dispatch_uid="model3d-render-enqueue")
