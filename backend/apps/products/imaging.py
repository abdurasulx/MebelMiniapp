"""Rasm bo'yicha o'xshashlik qidiruvi uchun yengil "signature" — tashqi AI/ML
xizmatga (kredential kerak bo'ladigan) muhtoj bo'lmasligi uchun, rasmni kichik
o'lchamga tushirib har pikselning RGB qiymatlarini vektor sifatida saqlaymiz.
Bu haqiqiy obyekt tanish emas, balki rang/shakl bo'yicha o'xshashlik — mebel
katalogida "shunga o'xshash" natijalarni topish uchun amalda yetarli."""

from PIL import Image, UnidentifiedImageError

SIGNATURE_SIZE = 12  # 12x12x3 = 432 o'lchamli vektor


def compute_signature(file_obj):
    """Fayl-obyektdan (ImageFieldFile yoki UploadedFile) 0..1 oralig'idagi
    RGB vektorini hisoblaydi. Rasm sifatida ochib bo'lmasa None qaytaradi."""
    try:
        file_obj.seek(0)
    except (AttributeError, ValueError):
        pass
    try:
        img = Image.open(file_obj).convert("RGB").resize(
            (SIGNATURE_SIZE, SIGNATURE_SIZE), Image.BILINEAR
        )
    except (UnidentifiedImageError, OSError):
        return None
    return [round(c / 255, 4) for pixel in img.getdata() for c in pixel]


def distance(a, b):
    """Ikki vektor orasidagi Evklid masofasi (kichikroq = o'xshashroq)."""
    if not a or not b or len(a) != len(b):
        return float("inf")
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
