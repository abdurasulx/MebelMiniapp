"""Versiya taqqoslash va siyosat qarori. MUHIM: versiyalar satr sifatida
EMAS, (major, minor, patch) butun sonlar kortejlari sifatida solishtiriladi
(`"2.10.0" > "2.9.0"`)."""
import re
from dataclasses import dataclass

from django.core.cache import cache
from django.db.models import Q
from django.utils import timezone

from .models import AppVersion

_LOOSE_RE = re.compile(r"^\d+(\.\d+){0,2}$")
_STRICT_RE = re.compile(r"^\d+\.\d+\.\d+$")

CACHE_KEY = "app-version-policy:{platform}"
CACHE_TTL = 60

ACTIVE, UPDATE_REQUIRED, BLOCKED = "ACTIVE", "UPDATE_REQUIRED", "BLOCKED"

MSG_AVAILABLE = "Yangi versiya mavjud."
MSG_UPDATE = "Ilovani yangilang."
MSG_BLOCKED = "Ushbu ilova versiyasi qo‘llab-quvvatlanmaydi. Ilovani yangilang."


def parse_version(raw, strict=False):
    """`"2.4.0"` -> (2, 4, 0). Mijoz tomonda `"1.0"` (iOS) yoki
    `"2.4.0+24"` (Flutter) ham uchrashi mumkin — `strict=False`da qisqa
    shakl nollar bilan to'ldiriladi va `+build` qismi tashlanadi.
    Noto'g'ri format -> None."""
    if raw is None:
        return None
    text = str(raw).strip().lstrip("vV").split("+", 1)[0]
    if not (_STRICT_RE if strict else _LOOSE_RE).match(text):
        return None
    parts = [int(p) for p in text.split(".")]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def format_version(t):
    return ".".join(str(n) for n in t)


def compare_versions(a, b):
    """-1 / 0 / 1 (a < b / a == b / a > b); noto'g'ri format -> ValueError."""
    ta, tb = parse_version(a), parse_version(b)
    if ta is None or tb is None:
        raise ValueError("Noto'g'ri versiya formati")
    return (ta > tb) - (ta < tb)


@dataclass
class Policy:
    platform: str
    current_version: str
    latest_version: str
    minimum_supported_version: str
    status: str
    update_available: bool
    force_update: bool
    store_url: str
    message: str

    def as_dict(self):
        return self.__dict__.copy()


def _load_records(platform):
    key = CACHE_KEY.format(platform=platform)
    cached = cache.get(key)
    if cached is not None:
        return cached
    now = timezone.now()
    qs = AppVersion.objects.filter(platform=platform).filter(
        Q(release_date__isnull=True) | Q(release_date__lte=now)
    )
    records = []
    for r in qs:
        t = parse_version(r.version)
        if t is None:
            continue
        records.append({
            "t": t, "status": r.status, "force_update": r.force_update,
            "store_url": r.store_url, "update_message": r.update_message,
        })
    records.sort(key=lambda r: r["t"])
    cache.set(key, records, CACHE_TTL)
    return records


def invalidate_cache(platform=None):
    for p in ([platform] if platform else [AppVersion.PLATFORM_ANDROID, AppVersion.PLATFORM_IOS]):
        cache.delete(CACHE_KEY.format(platform=p))


def resolve(platform, current):
    """Mijoz versiyasi (`current`, tuple) uchun siyosat. Platforma uchun
    umuman yozuv sozlanmagan bo'lsa — hech kimni bloklamaymiz (ACTIVE).

    Noma'lum versiya (bazada aniq yozuvi yo'q):
      * eng yangisidan katta -> ACTIVE (yangi build / hotfix);
      * minimum qo'llab-quvvatlanadigandan kichik -> BLOCKED;
      * oralig'ida -> o'zidan pastroq eng yaqin yozuvning holati."""
    records = _load_records(platform)
    cur_str = format_version(current)
    if not records:
        return Policy(platform, cur_str, cur_str, "", ACTIVE, False, False, "", "")

    latest = records[-1]
    supported = [r for r in records if r["status"] != AppVersion.STATUS_BLOCKED]
    minimum = supported[0]["t"] if supported else None

    exact = next((r for r in records if r["t"] == current), None)
    base = exact
    if exact is None:
        if current > latest["t"]:
            base = None
            status = ACTIVE
        elif minimum is None or current < minimum:
            base = None
            status = BLOCKED
        else:
            base = [r for r in records if r["t"] <= current][-1]
    if base is not None:
        status = {
            AppVersion.STATUS_ACTIVE: ACTIVE,
            AppVersion.STATUS_UPDATE_REQUIRED: UPDATE_REQUIRED,
            AppVersion.STATUS_BLOCKED: BLOCKED,
        }[base["status"]]

    update_available = current < latest["t"]
    if status == BLOCKED:
        force = True
    elif status == UPDATE_REQUIRED:
        force = bool(base and base["force_update"])
    else:
        force = False

    store_url = latest["store_url"] or (base["store_url"] if base else "") or next(
        (r["store_url"] for r in reversed(records) if r["store_url"]), ""
    )
    if status == BLOCKED:
        message = (base and base["update_message"]) or MSG_BLOCKED
    elif status == UPDATE_REQUIRED:
        message = (base and base["update_message"]) or MSG_UPDATE
    elif update_available:
        message = latest["update_message"] or MSG_AVAILABLE
    else:
        message = ""

    return Policy(
        platform=platform,
        current_version=cur_str,
        latest_version=format_version(latest["t"]),
        minimum_supported_version=format_version(minimum) if minimum else "",
        status=status,
        update_available=update_available,
        force_update=force,
        store_url=store_url,
        message=message,
    )
