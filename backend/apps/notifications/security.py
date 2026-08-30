"""Mobil ilova so'rovlari uchun qo'shimcha xavfsizlik qatlami (nwupdate.md
spetsifikatsiyasi): HMAC-SHA256 imzo + `day_delta` + `timesnap` + `nonce`.

MUHIM — asosiy xavfsizlik BARIBIR JWT (Access/Refresh Token) orqali
ta'minlanadi; bu qatlam FAQAT qo'shimcha (reverse-engineering'ni
qiyinlashtirish, replay'ga qarshi, eski app versiyalarini bloklash).

Web frontend BU HEADERLARNI YUBORMAYDI — shuning uchun middleware faqat
`X-Device-Id` headeri mavjud so'rovlarga qo'llanadi (qarang
`DeviceSignatureMiddleware._applies`), web'ga tegmaydi.
"""
import hashlib
import hmac
import time

from django.conf import settings
from django.core.cache import cache
from django.http import JsonResponse
from django.utils import timezone

from .models import PushDevice

TIMESNAP_WINDOW_SECONDS = 300  # 5 daqiqa (spetsifikatsiya §7)
NONCE_TTL_SECONDS = 15 * 60  # timesnap oynasi (±1) dan biroz uzunroq
DEVICE_HEADER = "X-Device-Id"


def current_timesnap() -> int:
    return int(time.time() // TIMESNAP_WINDOW_SECONDS)


def compute_signature(*, device_id, dev_name, vcode, day_delta, timesnap, nonce) -> str:
    """Spetsifikatsiya §5: `device_id:dev_name:vcode:day_delta:timesnap:nonce`
    HMAC-SHA256 bilan `DEVICE_HMAC_SECRET` sirini ishlatib imzolanadi."""
    payload = f"{device_id}:{dev_name}:{vcode}:{day_delta}:{timesnap}:{nonce}"
    secret = settings.DEVICE_HMAC_SECRET.encode()
    return hmac.new(secret, payload.encode(), hashlib.sha256).hexdigest()


class DeviceSignatureError(Exception):
    def __init__(self, code, status=401):
        self.code = code
        self.status = status


def validate_request(request) -> PushDevice:
    """Header'larni o'qib, hammasini tekshiradi; muvaffaqiyatli bo'lsa
    tegishli `PushDevice`ni qaytaradi (va uning `last_seen`/`updated_at`
    — ya'ni "last_updated"ni — yangilaydi). Har qanday nomuvofiqlikda
    `DeviceSignatureError` ko'taradi."""
    headers = request.headers
    device_id = headers.get(DEVICE_HEADER)
    dev_name = headers.get("X-Dev-Name", "")
    vcode_raw = headers.get("X-Vcode")
    day_delta_raw = headers.get("X-Day-Delta")
    timesnap_raw = headers.get("X-Timesnap")
    nonce = headers.get("X-Nonce")
    signature = headers.get("X-Signature")

    if not all([device_id, vcode_raw, timesnap_raw, nonce, signature]):
        raise DeviceSignatureError("MISSING_DEVICE_HEADERS", status=400)

    try:
        vcode = int(vcode_raw)
        timesnap = int(timesnap_raw)
        # `day_delta`ni mijoz yuborgan bo'lishi shart (imzo shu qiymat bilan
        # hisoblangan), lekin QIYMATNING O'ZIGA ishonilmaydi — pastda server
        # o'z hisoblagan qiymati bilan almashtiradi.
        int(day_delta_raw)
    except (TypeError, ValueError):
        raise DeviceSignatureError("INVALID_DEVICE_HEADERS", status=400)

    if vcode < settings.MOBILE_MIN_VCODE:
        raise DeviceSignatureError("UPDATE_REQUIRED", status=403)

    if abs(timesnap - current_timesnap()) > 1:
        raise DeviceSignatureError("TIMESNAP_INVALID")

    # Replay himoyasi: bir xil nonce ikkinchi marta qabul qilinmaydi.
    # `cache.add` faqat kalit MAVJUD BO'LMASA yozadi (atomik) — shu bilan
    # bir vaqtda kelgan ikkita so'rov ham to'g'ri rad etiladi.
    if not cache.add(f"device-nonce:{nonce}", "1", timeout=NONCE_TTL_SECONDS):
        raise DeviceSignatureError("NONCE_REUSED")

    device = PushDevice.objects.filter(device_id=device_id, is_deleted=False).first()
    if device is None or not device.is_active or device.revoked_at:
        raise DeviceSignatureError("DEVICE_REVOKED")

    # Server day_delta'ni O'ZI hisoblaydi — mijoz nima yuborgani muhim emas,
    # imzo shu (server hisoblagan) qiymat bilan mos kelishi kerak.
    reference = device.last_seen or device.updated_at
    server_day_delta = (timezone.now().date() - reference.date()).days

    expected = compute_signature(
        device_id=device_id, dev_name=dev_name, vcode=vcode,
        day_delta=server_day_delta, timesnap=timesnap, nonce=nonce,
    )
    if not hmac.compare_digest(expected, signature):
        raise DeviceSignatureError("SIGNATURE_INVALID")

    device.vcode = vcode
    if dev_name:
        device.device_name = dev_name
    device.last_seen = timezone.now()
    device.save(update_fields=["vcode", "device_name", "last_seen", "updated_at"])
    return device


#: `register_device` — qurilmani ENG BIRINCHI marta ro'yxatdan o'tkazadigan
#: endpoint. Bu paytda `PushDevice` yozuvi hali MAVJUD EMAS, shuning uchun
#: imzo tekshirilishi mumkin emas ("tuxum-tovuq" muammosi) — bu endpoint
#: allaqachon `IsAuthenticated` (Access Token) bilan himoyalangan, shuning
#: uchun signature qatlamidan istisno qilinadi.
EXEMPT_PATHS = ("/notifications/register_device/",)


class DeviceSignatureMiddleware:
    """Faqat `X-Device-Id` headeri mavjud so'rovlarga qo'llanadi — mobil
    ilova doim shu headerlar to'plamini yuboradi, veb frontend esa umuman
    yubormaydi, shuning uchun veb tomon bu qatlamdan mustaqil ishlayveradi."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        applies = (
            request.path.startswith("/api/")
            and DEVICE_HEADER in request.headers
            and not any(request.path.rstrip("/").endswith(p.rstrip("/")) for p in EXEMPT_PATHS)
        )
        if applies:
            try:
                request.mobile_device = validate_request(request)
            except DeviceSignatureError as exc:
                return JsonResponse({"code": exc.code}, status=exc.status)
        return self.get_response(request)
