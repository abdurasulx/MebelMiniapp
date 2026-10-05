from django.db.models.signals import post_save
from django.dispatch import receiver

from . import versioning
from .models import AppVersion, PlatformLink


@receiver(post_save, sender=AppVersion)
def clear_policy_cache(sender, instance, **kwargs):
    versioning.invalidate_cache(instance.platform)


@receiver(post_save, sender=PlatformLink)
def clear_link_cache(sender, instance, **kwargs):
    versioning.invalidate_cache(instance.platform)
