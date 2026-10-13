"""Sharh/izohlar uchun oddiy kontent filtri (Apple 1.2 — nomaqbul kontentni filtrlash).

Bu to'liq moderatsiya emas, balki ochiq-oydin haqorat/so'kinishlarni va spam
(havola/telefon) ni kiritishda to'xtatadigan birinchi qatlam; qolganini foydalanuvchi
shikoyati va admin ko'rib chiqadi. Qo'shimcha so'zlar: env `OBJECTIONABLE_WORDS`."""
import re

from django.conf import settings

# Ochiq-oydin so'kinish ildizlari (lotin/kirill translit). Bahsli so'zlar kiritilmagan.
_BUILTIN = {
    "fuck", "shit", "bitch", "asshole", "cunt", "nigger",
    "blyat", "blyad", "pizd", "ebat", "ebal", "suka", "huy", "xuy", "mudak",
    "бля", "пизд", "ебат", "ебал", "сука", "хуй", "мудак",
    "jalab", "qanjiq", "tirmiz", "sikaman", "skay",
}
_URL = re.compile(r"(https?://|www\.|t\.me/|\b[a-z0-9-]+\.(com|uz|ru|net|org|me)\b)", re.I)
_PHONE = re.compile(r"(\+?\d[\s\-()]*){9,}")


def _words():
    extra = getattr(settings, "OBJECTIONABLE_WORDS", []) or []
    return _BUILTIN | {w.strip().lower() for w in extra if w.strip()}


def contains_objectionable(text: str) -> bool:
    t = (text or "").lower()
    if not t.strip():
        return False
    return any(w in t for w in _words())


def looks_like_spam(text: str) -> bool:
    t = text or ""
    return bool(_URL.search(t) or _PHONE.search(t))
