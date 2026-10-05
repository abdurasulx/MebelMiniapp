"""Backend tomonidagi MAJBURLASH qatlami: Flutter/iOS yangilash ekrani
faqat UX — eski yoki o'zgartirilgan ilova uni chetlab o'tolmasligi uchun
`X-App-Version` + `X-App-Platform` headerlari bo'yicha server tekshiradi."""
import logging

from django.conf import settings
from django.http import JsonResponse

from . import versioning

logger = logging.getLogger(__name__)

PLATFORM_HEADER = "X-App-Platform"
VERSION_HEADER = "X-App-Version"
MOBILE_MARKER_HEADER = "X-Device-Id"  # mavjud mobil-mijoz belgisi (security.py)

#: Hech qachon bloklanmaydigan yo'llar (yakuniy qismi bo'yicha).
#: Buyurtma yaratadigan endpointlar (POST) — versiyada orders_enabled=False bo'lsa yopiladi.
ORDER_CREATE_PATHS = ("/api/v1/orders", "/api/v1/custom-orders/create")

EXEMPT_SUFFIXES = ("/app/version", "/health", "/healthcheck")


def _is_exempt(path):
    stripped = path.rstrip("/")
    return any(stripped.endswith(s) for s in EXEMPT_SUFFIXES)


class AppVersionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if (
            request.method != "OPTIONS"
            and request.path.startswith("/api/")
            and not _is_exempt(request.path)
        ):
            platform = request.headers.get(PLATFORM_HEADER, "").strip().lower()
            raw_version = request.headers.get(VERSION_HEADER)
            if not platform and not raw_version:
                # Veb frontend bu headerlarni yubormaydi. Mobil (X-Device-Id)
                # so'rovda ular yo'q bo'lsa — faqat sozlama yoqilgan bo'lsa rad
                # etamiz (eski o'rnatilgan ilovalar birdaniga yopilib qolmasin).
                if MOBILE_MARKER_HEADER in request.headers:
                    if getattr(settings, "APP_VERSION_REQUIRE_HEADERS", False):
                        return JsonResponse({"code": "MISSING_APP_VERSION_HEADERS"}, status=400)
                    logger.warning("Mobil so'rov versiya headerlarisiz: %s", request.path)
            else:
                current = versioning.parse_version(raw_version)
                if platform not in versioning.PLATFORMS or current is None:
                    return JsonResponse({"code": "INVALID_APP_VERSION_HEADERS"}, status=400)
                policy = versioning.resolve(platform, current)
                request.app_version_policy = policy
                if policy.status == versioning.BLOCKED or (
                    policy.status == versioning.UPDATE_REQUIRED and policy.force_update
                ):
                    body = {"code": "APP_UPDATE_REQUIRED", **policy.as_dict()}
                    return JsonResponse(body, status=426)
                if (
                    not policy.orders_enabled
                    and request.method == "POST"
                    and request.path.rstrip("/") in ORDER_CREATE_PATHS
                ):
                    return JsonResponse(
                        {"code": "ORDERS_RESTRICTED", "detail": versioning.MSG_ORDERS_RESTRICTED},
                        status=403,
                    )
        return self.get_response(request)
