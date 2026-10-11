"""Ikki geografik nuqta orasidagi masofa (Haversine formulasi) — firma
xizmat radiusi bo'yicha mahsulot ko'rinishini aniqlashda ishlatiladi
(qarang apps/products/views.py)."""

from math import asin, cos, radians, sin, sqrt

EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1, lon1, lat2, lon2):
    lat1, lon1, lat2, lon2 = map(radians, (lat1, lon1, lat2, lon2))
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * EARTH_RADIUS_KM * asin(sqrt(a))


# Viloyat markazlari (taxminiy) — lat/lng berilganda foydalanuvchi qaysi viloyatda
# ekanini eng yaqin markaz bo'yicha aniqlash uchun (faqat "viloyat bo'yicha xizmat"
# rejimidagi firmalar uchun; chegara yaqinida taxminiy bo'lishi mumkin).
VILOYAT_CENTERS = {
    "toshkent_shahri": (41.3111, 69.2797),
    "toshkent_viloyati": (41.0, 69.6),
    "andijon": (40.7821, 72.3442),
    "buxoro": (39.7747, 64.4286),
    "fargona": (40.3842, 71.7843),
    "jizzax": (40.1158, 67.8422),
    "xorazm": (41.55, 60.6333),
    "namangan": (41.0011, 71.6726),
    "navoiy": (40.1030, 65.3739),
    "qashqadaryo": (38.8606, 65.7890),
    "qoraqalpogiston": (43.8041, 59.4458),
    "samarqand": (39.6542, 66.9597),
    "sirdaryo": (40.4897, 68.7842),
    "surxondaryo": (37.2242, 67.2783),
}


# O'zbekiston chegarasini o'rab turuvchi taxminiy to'rtburchak.
_UZ_LAT = (37.1, 45.7)
_UZ_LNG = (55.9, 73.2)


def in_uzbekistan(lat, lng):
    return _UZ_LAT[0] <= lat <= _UZ_LAT[1] and _UZ_LNG[0] <= lng <= _UZ_LNG[1]


def nearest_viloyat(lat, lng):
    """Nuqta O'zbekiston ichida bo'lsa — eng yaqin viloyat markazi kaliti, aks holda None
    (chet eldagi foydalanuvchiga viloyat bo'yicha xizmat qo'llanmaydi, faqat radius)."""
    if not in_uzbekistan(lat, lng):
        return None
    return min(VILOYAT_CENTERS, key=lambda k: haversine_km(lat, lng, *VILOYAT_CENTERS[k]))
