from django.db.models.signals import post_save
from django.dispatch import receiver

from . import versioning
from .models import AppVersion


@receiver(post_save, sender=AppVersion)
def clear_policy_cache(sender, instance, **kwargs):
    versioning.invalidate_cache(instance.platform)
