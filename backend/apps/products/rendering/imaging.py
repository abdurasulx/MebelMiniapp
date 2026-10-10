"""Render qilingan PNG'larni standartlashtirish va WebP/AVIF ko'rinishlarini
tayyorlash (shaffoflik saqlanadi)."""
import base64
import hashlib
import io

from PIL import Image

SIZES = (400, 800, 1600)
FILL = 0.85  # mahsulot kadrning ~85%ini egallaydi


def data_url_to_image(data_url: str) -> Image.Image:
    raw = base64.b64decode(data_url.split(",", 1)[1])
    return Image.open(io.BytesIO(raw)).convert("RGBA")


def normalize_square(im: Image.Image, size: int = 1600, fill: float = FILL) -> Image.Image:
    """Shaffof chekkalarni kesib, mahsulotni kvadrat kadr markaziga `fill` ulushda joylaydi."""
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    longest = max(im.size)
    target = max(1, round(size * fill))
    scale = target / longest
    new = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(new, ((size - new.width) // 2, (size - new.height) // 2), new)
    return canvas


def encode(im: Image.Image, size: int, fmt: str) -> bytes:
    resized = im if im.width == size else im.resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    if fmt == "webp":
        resized.save(buf, "WEBP", quality=88, method=4)
    elif fmt == "avif":
        resized.save(buf, "AVIF", quality=62, speed=6)
    elif fmt == "png":
        resized.save(buf, "PNG", optimize=True)
    else:
        raise ValueError(fmt)
    return buf.getvalue()


def short_hash(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()[:10]
