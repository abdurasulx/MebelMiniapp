import subprocess
import sys
from pathlib import Path

from django.conf import settings
from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Model3D


class Model3DSerializer(StorageStampMixin, serializers.ModelSerializer):
    """Firma tomoni: 3D yuklash/tahrirlash + ulashish sozlamalari."""

    file_fields = ("glb_file", "usdz_file")
    glb_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    usdz_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    glb_url = serializers.SerializerMethodField()
    usdz_url = serializers.SerializerMethodField()
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    visibility_display = serializers.CharField(source="get_visibility_display", read_only=True)
    allowed_emails = serializers.ListField(
        child=serializers.EmailField(), required=False, default=list
    )

    class Meta:
        model = Model3D
        fields = (
            "id",
            "product",
            "glb_file",
            "usdz_file",
            "glb_url",
            "usdz_url",
            "status",
            "status_display",
            "scale_width",
            "scale_height",
            "scale_depth",
            "share_token",
            "visibility",
            "visibility_display",
            "allowed_emails",
            "created_at",
        )
        read_only_fields = ("id", "product", "status", "share_token", "created_at")

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))

    SOURCE_FORMATS = (".fbx", ".obj")

    def save(self, **kwargs):
        # Firma GLB, yoki hatto xom FBX/OBJ yuklasa ham — qo'lda Blender/Reality
        # Converter ishlatishi shart emas: server fonda kerakli bosqichlarni
        # (FBX/OBJ -> GLB, GLB -> USDZ) avtomatik bajaradi. Agar bu so'rovda
        # usdz_file qo'lda ham yuklangan bo'lsa, uni ustunlik beramiz (USDZ
        # generatsiyasi o'tkazib yuboriladi — GLB konvertatsiyasi kerak bo'lsa
        # baribir bajariladi).
        usdz_uploaded_manually = "usdz_file" in self.validated_data
        instance = super().save(**kwargs)
        instance.recompute_status()

        needs_conversion = (
            instance.glb_file
            and Path(instance.glb_file.name).suffix.lower() in self.SOURCE_FORMATS
        )
        needs_processing = instance.glb_file and (needs_conversion or not usdz_uploaded_manually)

        if needs_processing:
            instance.status = Model3D.Status.PROCESSING
            instance.save(update_fields=["status"])
            self._trigger_processing(instance.id, skip_usdz=usdz_uploaded_manually)
        else:
            instance.save(update_fields=["status"])
        return instance

    @staticmethod
    def _trigger_processing(model3d_id, skip_usdz=False):
        manage_py = Path(settings.BASE_DIR) / "manage.py"
        args = [sys.executable, str(manage_py), "process_model3d", str(model3d_id)]
        if skip_usdz:
            args.append("--skip-usdz")
        subprocess.Popen(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


class Model3DViewerSerializer(serializers.ModelSerializer):
    """Ochiq/cheklangan viewer sahifasi uchun — faqat ko'rish uchun kerak bo'lgan
    minimal ma'lumot (bazissoft.ru uslubidagi mustaqil 3D-havola)."""

    glb_url = serializers.SerializerMethodField()
    usdz_url = serializers.SerializerMethodField()
    product_name = serializers.CharField(source="product.name_uz", read_only=True)
    company_name = serializers.CharField(source="product.company.name", read_only=True)
    variants = serializers.SerializerMethodField()

    class Meta:
        model = Model3D
        fields = (
            "id",
            "product_name",
            "company_name",
            "variants",
            "glb_url",
            "usdz_url",
            "scale_width",
            "scale_height",
            "scale_depth",
            "visibility",
        )

    def get_variants(self, obj):
        return [
            {"id": v.id, "name": v.name, "color_hex": v.color_hex}
            for v in obj.product.variants.filter(is_deleted=False)
        ]

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))
