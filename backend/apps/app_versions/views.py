from django.core.exceptions import ValidationError
from django.core.validators import URLValidator
from django.db import transaction
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from . import versioning
from .models import AppVersion, PlatformLink
from .serializers import AppVersionSerializer


class AppVersionCheckView(APIView):
    """`GET /api/v1/app/version/` — login'siz ishlaydi (versiya tekshiruvi
    kirishdan OLDIN bo'ladi), shuning uchun JWT autentifikatsiyasi
    o'chirilgan: muddati o'tgan token ham bu endpointni buzmasligi kerak."""

    authentication_classes = ()
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        platform = request.headers.get("X-App-Platform", "").strip().lower()
        raw = request.headers.get("X-App-Version")
        if not platform or not raw:
            return Response({"code": "MISSING_APP_VERSION_HEADERS"}, status=400)
        current = versioning.parse_version(raw)
        if platform not in versioning.PLATFORMS or current is None:
            return Response({"code": "INVALID_APP_VERSION_HEADERS"}, status=400)
        return Response(versioning.resolve(platform, current).as_dict())


class IsPlatformAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == "platform_admin")


class AppVersionViewSet(viewsets.ModelViewSet):
    """SuperAdmin -> Versiya nazorati. DELETE yo'q: tarix saqlanadi."""

    serializer_class = AppVersionSerializer
    permission_classes = (IsPlatformAdmin,)
    http_method_names = ("get", "post", "put", "patch", "head", "options")
    pagination_class = None
    queryset = AppVersion.objects.all()

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        platform = request.query_params.get("platform")
        status = request.query_params.get("status")
        search = request.query_params.get("version")
        if platform:
            qs = qs.filter(platform=platform)
        if status:
            qs = qs.filter(status=status)
        if search:
            qs = qs.filter(version__icontains=search)
        rows = sorted(qs, key=lambda r: versioning.parse_version(r.version) or (0, 0, 0), reverse=True)
        latest = {}
        for p in versioning.PLATFORMS:
            records = [r for r in AppVersion.objects.filter(platform=p) if versioning.parse_version(r.version)]
            records.sort(key=lambda r: versioning.parse_version(r.version))
            latest[p] = records[-1].version if records else None
        return Response({
            "results": AppVersionSerializer(rows, many=True).data,
            "latest": latest,
        })

    @action(detail=False, methods=["get", "put"], url_path="links")
    def links(self, request):
        """Har platforma uchun bitta yuklab olish havolasi:
        GET -> {android, ios, web}; PUT {android: url, ...} -> saqlaydi."""
        if request.method == "PUT":
            validator = URLValidator(schemes=("http", "https"))
            clean = {}
            for p in versioning.PLATFORMS:
                if p in request.data:
                    url = (request.data.get(p) or "").strip()
                    if url:
                        try:
                            validator(url)
                        except ValidationError:
                            return Response({p: ["To'g'ri URL kiriting"]}, status=400)
                    clean[p] = url
            for p, url in clean.items():
                PlatformLink.objects.update_or_create(platform=p, defaults={"store_url": url})
        data = {p: "" for p in versioning.PLATFORMS}
        data.update({l.platform: l.store_url for l in PlatformLink.objects.all()})
        return Response(data)

    @action(detail=False, methods=["post"], url_path="bulk")
    def bulk(self, request):
        """Bitta versiyani bir nechta platforma uchun BIRDA yaratadi
        (Android + iOS + Web ni alohida-alohida kiritib o'tirmaslik uchun).
        Har platforma o'z store_url'iga ega. Biror platformada xato bo'lsa
        (masalan versiya allaqachon bor) hech narsa yaratilmaydi."""
        platforms = request.data.get("platforms") or []
        if not isinstance(platforms, list) or not platforms:
            return Response({"platforms": ["Kamida bitta platforma tanlang"]}, status=400)
        urls = request.data.get("store_urls") or {}
        common = {
            k: request.data.get(k)
            for k in ("version", "status", "force_update", "orders_enabled", "update_message", "release_date")
            if request.data.get(k) is not None
        }
        serializers_, errors = [], {}
        for platform in dict.fromkeys(platforms):
            ser = AppVersionSerializer(data={**common, "platform": platform, "store_url": urls.get(platform, "")})
            if ser.is_valid():
                serializers_.append(ser)
            else:
                errors[platform] = ser.errors
        if errors:
            return Response({"platform_errors": errors}, status=400)
        with transaction.atomic():
            created = [ser.save() for ser in serializers_]
        return Response({"results": AppVersionSerializer(created, many=True).data}, status=201)
