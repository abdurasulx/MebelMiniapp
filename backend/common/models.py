import uuid

from django.conf import settings
from django.db import models


def current_storage_mode():
    return settings.STORAGE_MODE


class BaseModel(models.Model):
    """UUID pk + timestamps + soft delete (techdocs/06 §2)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        abstract = True


class StoredFileMixin(models.Model):
    """Fayl saqlovchi modellar uchun: fayl qaysi STORAGE_MODE da yuklangani.

    Rejim joriy STORAGE_MODE ga mos kelmasa, fayl API javoblarida yashiriladi
    (masalan, lokalda yuklangan fayllar cloud rejimda ko'rinmaydi).
    """

    storage_mode = models.CharField(
        max_length=20, default=current_storage_mode, editable=False
    )

    class Meta:
        abstract = True

    def file_visible(self):
        return self.storage_mode == settings.STORAGE_MODE

