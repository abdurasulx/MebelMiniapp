"""Rasm bo'yicha o'xshashlik qidiruvi — tashqi AI/ML xizmatga (kredential
kerak bo'ladigan) muhtoj bo'lmasligi uchun ikkita mustaqil signal
birlashtiriladi:

1. **Rang gistogrammasi** (global, pozitsiyaga bog'liq emas) — mahsulotning
   umumiy rang tarkibini ushlaydi (masalan yog'och jigarrang, mato ko'k).
   Piksel-piksel solishtirishdan farqli o'laroq, mahsulot kadr ichida
   boshqacha joylashgan/burchakdan olingan bo'lsa ham ishlaydi.
2. **Difference hash (dHash)** — kulrang gradient naqshiga asoslangan
   "barmoq izi", shakl/silуэt o'xshashligini ushlaydi, rang o'zgarishiga
   (turli yorug'lik, material rangi) sezgir emas.

Ikkalasi ham haqiqiy obyekt tanish emas, lekin birgalikda faqat rang yoki
faqat piksel-joylashuvga qaraganda ancha ishonchli "shunga o'xshash"
natija beradi."""

from PIL import Image, UnidentifiedImageError

HIST_BINS_PER_CHANNEL = 8  # 8x8x8 = 512 bin
HASH_SIZE = 8  # dHash — 8x8 = 64 bit

# Ikkita normallashtirilgan (yig'indisi 1 ga teng) gistogramma orasidagi
# eng katta mumkin bo'lgan Evklid masofasi — bir-biriga umuman mos kelmagan
# ikkita distributsiya uchun sqrt(2).
_MAX_HIST_DISTANCE = 2 ** 0.5
_MAX_HAMMING = HASH_SIZE * HASH_SIZE


def _to_opaque_rgb(file_obj):
    """Shaffof (RGBA/LA/paletali-shaffof) rasmlarni OQ fonga qo'shib RGB'ga
    aylantiradi — aks holda shaffof qismlar QORA deb hisoblanib, mebel
    render-eksportlarida (keng tarqalgan format) signature butunlay
    buzilib ketadi."""
    raw = Image.open(file_obj)
    if raw.mode in ("RGBA", "LA") or (raw.mode == "P" and "transparency" in raw.info):
        raw = raw.convert("RGBA")
        background = Image.new("RGB", raw.size, (255, 255, 255))
        background.paste(raw, mask=raw.split()[-1])
        return background
    return raw.convert("RGB")


def _soft_bins(value, n, bin_width):
    """Bitta kanal qiymatini eng yaqin ikkita "quti" orasida proporsional
    taqsimlaydi (trilinear interpolyatsiya) — aks holda bir-biriga juda
    yaqin ikkita rang tasodifan qo'shni qutilarga tushib qolsa, "butunlay
    boshqa rang" deb hisoblanib qolar edi (qattiq chegara muammosi)."""
    pos = value / bin_width - 0.5
    lo = int(pos // 1)
    frac = pos - lo
    idx_lo = max(0, min(n - 1, lo))
    idx_hi = max(0, min(n - 1, lo + 1))
    if idx_lo == idx_hi:
        return [(idx_lo, 1.0)]
    return [(idx_lo, 1 - frac), (idx_hi, frac)]


def _color_histogram(img):
    small = img.resize((64, 64), Image.BILINEAR)
    n = HIST_BINS_PER_CHANNEL
    bin_width = 256 / n
    hist = [0.0] * (n ** 3)
    pixels = list(small.getdata())
    for r, g, b in pixels:
        for ri, rw in _soft_bins(r, n, bin_width):
            for gi, gw in _soft_bins(g, n, bin_width):
                for bi, bw in _soft_bins(b, n, bin_width):
                    weight = rw * gw * bw
                    if weight:
                        hist[ri * n * n + gi * n + bi] += weight
    total = len(pixels) or 1
    return [round(c / total, 5) for c in hist]


def _diff_hash(img):
    gray = img.convert("L").resize((HASH_SIZE + 1, HASH_SIZE), Image.BILINEAR)
    pixels = list(gray.getdata())
    width = HASH_SIZE + 1
    bits = 0
    for row in range(HASH_SIZE):
        for col in range(HASH_SIZE):
            left = pixels[row * width + col]
            right = pixels[row * width + col + 1]
            bits = (bits << 1) | (1 if left > right else 0)
    return format(bits, f"0{HASH_SIZE * HASH_SIZE // 4}x")


def compute_signature(file_obj):
    """Fayl-obyektdan (ImageFieldFile yoki UploadedFile) qidiruv uchun
    signature hisoblaydi: `{"hist": [...], "hash": "..."}`. Rasm sifatida
    ochib bo'lmasa None qaytaradi."""
    try:
        file_obj.seek(0)
    except (AttributeError, ValueError):
        pass
    try:
        img = _to_opaque_rgb(file_obj)
    except (UnidentifiedImageError, OSError):
        return None
    return {"hist": _color_histogram(img), "hash": _diff_hash(img)}


def _hist_distance(a, b):
    if not a or not b or len(a) != len(b):
        return float("inf")
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def _hamming_distance(hash_a, hash_b):
    try:
        return bin(int(hash_a, 16) ^ int(hash_b, 16)).count("1")
    except (TypeError, ValueError):
        return _MAX_HAMMING


def similarity_percent(sig_a, sig_b):
    """0..100 oralig'ida o'xshashlik foizi (100 = bir xil rasm) — rang
    gistogrammasi (45%) va shakl/struktura xeshi (55%) birlashtirilgan."""
    if not isinstance(sig_a, dict) or not isinstance(sig_b, dict):
        return 0.0

    hist_dist = _hist_distance(sig_a.get("hist"), sig_b.get("hist"))
    if hist_dist == float("inf"):
        return 0.0
    hist_similarity = max(0.0, 1 - hist_dist / _MAX_HIST_DISTANCE)

    hamming = _hamming_distance(sig_a.get("hash"), sig_b.get("hash"))
    hash_similarity = max(0.0, 1 - hamming / _MAX_HAMMING)

    combined = 0.45 * hist_similarity + 0.55 * hash_similarity
    return round(combined * 100, 1)
