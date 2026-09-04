import subprocess
import sys
from pathlib import Path

from django.conf import settings
from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Model3D


class Model3DSerializer(StorageStampMixin, serializers.ModelSerializer):
    """Firma tomoni: 3D yuklash/tahrirlash + ulashish sozlamalari."""

    file_fields = ("glb_file", "usdz_file", "texture_archive")
    glb_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    usdz_file = serializers.FileField(write_only=True, required=False, allow_null=True)
    texture_archive = serializers.FileField(write_only=True, required=False, allow_null=True)
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
            "variant",
            "glb_file",
            "usdz_file",
            "texture_archive",
            "glb_url",
            "usdz_url",
            "status",
            "status_display",
            "scale_width",
            "scale_height",
            "scale_depth",
            "bbox_width",
            "bbox_height",
            "bbox_depth",
            "shape_tag",
            "share_token",
            "visibility",
            "visibility_display",
            "allowed_emails",
            "created_at",
        )
        read_only_fields = ("id", "product", "variant", "status", "share_token", "created_at")

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))

    # FBX/OBJ -> to'g'ridan-to'g'ri konvertatsiya kerak; ZIP/RAR -> avval
    # ochilib, ichidan model fayli topiladi (bular ham "konvertatsiya kerak"
    # holatlar, chunki natija hali `glb_file`ga yozilmagan).
    CONVERSION_NEEDED_FORMATS = (".fbx", ".obj", ".dae", ".zip", ".rar")

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
            and Path(instance.glb_file.name).suffix.lower() in self.CONVERSION_NEEDED_FORMATS
        )
        needs_processing = instance.glb_file and (needs_conversion or not usdz_uploaded_manually)

        if needs_processing:
            instance.status = Model3D.Status.PROCESSING
            instance.save(update_fields=["status"])
            # Tekstura arxivi faqat shu so'rovda FBX/OBJ bilan birga yuklansa
            # foydali — konvertatsiya paytida manba fayl hali mavjud bo'lganda
            # rasm nomlarini moslashtirish mumkin. Keyinchalik alohida
            # yuklansa, moslashtirish uchun FBX/OBJ qayta yuklanishi kerak
            # (glb_file allaqachon yakuniy GLB'ga almashtirilgan bo'ladi).
            texture_archive_path = (
                instance.texture_archive.path if needs_conversion and instance.texture_archive else None
            )
            self._trigger_processing(
                instance.id, skip_usdz=usdz_uploaded_manually, texture_archive_path=texture_archive_path
            )
        else:
            # Konvertatsiya kerak emas — fayl allaqachon haqiqiy GLB, shuning
            # uchun geometriyani (bounding box/shakl) shu yerda darhol
            # hisoblab olamiz (process_model3d navbatiga tushmaydi).
            from .geometry import extract_bbox

            with instance.glb_file.open("rb") as f:
                instance.apply_bbox(extract_bbox(f))
            instance.save(update_fields=["status", "bbox_width", "bbox_height", "bbox_depth", "shape_tag"])
        return instance

    @staticmethod
    def _trigger_processing(model3d_id, skip_usdz=False, texture_archive_path=None):
        manage_py = Path(settings.BASE_DIR) / "manage.py"
        args = [sys.executable, str(manage_py), "process_model3d", str(model3d_id)]
        if skip_usdz:
            args.append("--skip-usdz")
        if texture_archive_path:
            args += ["--texture-archive", texture_archive_path]
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
    product_name = serializers.SerializerMethodField()
    variant_name = serializers.CharField(source="variant.name", read_only=True, default=None)
    company_name = serializers.SerializerMethodField()
    variants = serializers.SerializerMethodField()

    class Meta:
        model = Model3D
        fields = (
            "id",
            "product_name",
            "variant_name",
            "company_name",
            "variants",
            "glb_url",
            "usdz_url",
            "scale_width",
            "scale_height",
            "scale_depth",
            "visibility",
        )

    def get_product_name(self, obj):
        if obj.design_version_id:
            return f"Individual loyiha — {obj.design_version.design.order_id}"
        return obj.owning_product.name_uz

    def get_company_name(self, obj):
        return obj.owning_company.name

    def get_variants(self, obj):
        # Har bir variant o'zining alohida 3D faylini olishi mumkin (masalan
        # ko'p materialli mahsulotlarda runtime tint yetarli bo'lmaganda —
        # qarang Model3D docstring). Shuning uchun viewer sahifasi yuqorida
        # variant tanlash imkonini berishi uchun har biriga tegishli glb/usdz
        # havolasi (agar bo'lsa) shu yerda qaytariladi. Dizayn versiyasiga
        # biriktirilgan modelning variantlari yo'q (katalog mahsuloti emas).
        if obj.design_version_id:
            return []
        request = self.context.get("request")
        result = []
        for v in obj.owning_product.variants.filter(is_deleted=False):
            variant_model = getattr(v, "model3d", None)
            has_own_model = (
                variant_model is not None
                and not variant_model.is_deleted
                and variant_model.can_view(request.user if request else None)
            )
            result.append({
                "id": v.id,
                "name": v.name,
                "color_hex": v.color_hex,
                "is_current": v.id == obj.variant_id,
                "has_own_model": has_own_model,
                "glb_url": visible_file_url(variant_model, "glb_file", request) if has_own_model else None,
                "usdz_url": visible_file_url(variant_model, "usdz_file", request) if has_own_model else None,
            })
        return result

    def get_glb_url(self, obj):
        return visible_file_url(obj, "glb_file", self.context.get("request"))

    def get_usdz_url(self, obj):
        return visible_file_url(obj, "usdz_file", self.context.get("request"))
