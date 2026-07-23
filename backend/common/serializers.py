from django.conf import settings


class StorageStampMixin:
    """Fayl qayta yuklanganda storage_mode ni joriy rejimga yangilaydi."""

    file_fields = ()

    def update(self, instance, validated_data):
        if any(f in validated_data for f in self.file_fields):
            instance.storage_mode = settings.STORAGE_MODE
        return super().update(instance, validated_data)


def visible_file_url(obj, field_name, request=None):
    """Fayl URL'ini qaytaradi; storage rejimi mos kelmasa yoki fayl bo'lmasa — None."""
    f = getattr(obj, field_name, None)
    if not f or not obj.file_visible():
        return None
    url = f.url
    return request.build_absolute_uri(url) if request is not None else url
