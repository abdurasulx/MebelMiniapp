"""Sotuvchi brauzeri 3D ko'rinishdan olgan skrinlarni qabul qilish va
standartlashtirish (kvadrat, 85% kadr, WebP/AVIF 400/800/1600). Chromium/GPU
serverda KERAK EMAS — faqat Pillow."""
import io

from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils.text import slugify
from PIL import Image

from ..models import Product, RenderedImage
from . import imaging

SHOTS = ("hero", "front", "side", "back", "top")
MAX_UPLOAD_BYTES = 12 * 1024 * 1024


class RenderUploadError(Exception):
    pass


def _usable(m) -> bool:
    # Frontend (captureRenders.renderSources) bilan bir xil shart: faqat `ready` modellar
    # render qilinadi; aks holda "ishlov berilmoqda" model render_source'ga kirib,
    # keyin tayyor bo'lganda qayta render qilinmay qolardi.
    return (
        m is not None
        and not m.is_deleted
        and m.status == "ready"
        and bool(m.glb_file)
        and m.glb_file.name.lower().endswith(".glb")
    )


def glb_sources(product: Product):
    """[(kind, model3d, variant|None)] — mahsulot umumiy GLB'i va o'z GLB'iga ega variantlar."""
    out = []
    pm = getattr(product, "model3d", None)
    if _usable(pm):
        out.append(("product", pm, None))
    for v in product.variants.filter(is_deleted=False).order_by("created_at"):
        vm = getattr(v, "model3d", None)
        if _usable(vm):
            out.append(("variant", vm, v))
    return out


def source_key(product: Product) -> str:
    return "|".join(sorted(m.glb_file.name for _, m, _ in glb_sources(product)))[:500]


def is_stale(product: Product) -> bool:
    key = source_key(product)
    return bool(key) and key != product.render_source


def _save(key: str, data: bytes) -> str:
    return default_storage.url(default_storage.save(key, ContentFile(data)))


def store_shot(product: Product, *, variant, variant_name: str, shot: str, upload) -> RenderedImage:
    """Bitta rakurs skrinini qabul qiladi, standartlaydi va saqlaydi (qayta yuborilsa — almashtiradi)."""
    if shot not in SHOTS:
        raise RenderUploadError("Noma'lum rakurs.")
    raw = upload.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise RenderUploadError("Rasm juda katta.")
    try:
        im = Image.open(io.BytesIO(raw))
        im.load()
    except Exception as exc:  # noqa: BLE001
        raise RenderUploadError("Rasm fayli yaroqsiz.") from exc
    if min(im.size) < 200:
        raise RenderUploadError("Rasm juda kichik.")
    base = imaging.normalize_square(im.convert("RGBA"), 1600)

    slug = slugify(variant_name) or "default"
    urls = {}
    for size in imaging.SIZES:
        urls[str(size)] = {}
        for fmt in ("webp", "avif"):
            data = imaging.encode(base, size, fmt)
            key = f"products/{product.id}/{slug}/{shot}-{size}-{imaging.short_hash(data)}.{fmt}"
            urls[str(size)][fmt] = _save(key, data)

    obj, _ = RenderedImage.objects.update_or_create(
        product=product,
        variant_slug=slug,
        shot=shot,
        defaults={
            "variant": variant,
            "variant_name": variant_name,
            "sort_order": SHOTS.index(shot),
            "urls": urls,
            "is_deleted": False,
        },
    )
    obj._hero_png = imaging.encode(base, 1600, "png") if shot == "hero" else None
    return obj
