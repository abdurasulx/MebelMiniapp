import random
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.companies.models import Company
from apps.orders.models import Order
from apps.products.models import Product

from .models import PhoneOTP
from .serializers import (
    CareerEntrySerializer,
    OTPRequestSerializer,
    OTPVerifySerializer,
    RegisterSerializer,
    UserSerializer,
)

User = get_user_model()


class IsPlatformAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == "platform_admin"


class AdminUserListView(generics.ListAPIView):
    """admin.domen.uz: foydalanuvchilar ro'yxati (qidiruv: ?search=)."""

    serializer_class = UserSerializer
    permission_classes = (IsPlatformAdmin,)

    def get_queryset(self):
        qs = User.objects.order_by("-date_joined")
        search = self.request.query_params.get("search")
        if search:
            qs = qs.filter(email__icontains=search)
        role = self.request.query_params.get("role")
        if role:
            qs = qs.filter(role=role)
        return qs


class AdminStatsView(APIView):
    """admin.domen.uz portali uchun umumiy statistika."""

    permission_classes = (IsPlatformAdmin,)

    def get(self, request):
        return Response(
            {
                "users": User.objects.count(),
                "customers": User.objects.filter(role=User.Role.CUSTOMER).count(),
                "companies": Company.objects.filter(is_deleted=False).count(),
                "active_companies": Company.objects.filter(
                    is_deleted=False, is_active=True
                ).count(),
                "products": Product.objects.filter(is_deleted=False).count(),
                "published_products": Product.objects.filter(
                    is_deleted=False, is_published=True
                ).count(),
                "orders": Order.objects.filter(is_deleted=False).count(),
                "new_orders": Order.objects.filter(
                    is_deleted=False, status=Order.Status.NEW
                ).count(),
            }
        )


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = (permissions.AllowAny,)


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class CareerView(generics.ListAPIView):
    """Foydalanuvchining barcha kompaniyalardagi ish tarixi (karyera)."""

    serializer_class = CareerEntrySerializer

    def get_queryset(self):
        from apps.companies.models import Employee

        return (
            Employee.objects.filter(user=self.request.user, is_deleted=False)
            .select_related("company")
            .order_by("-created_at")
        )


class OTPRequestView(APIView):
    """Telefon raqamga SMS kod yuborish (hozircha SMS provayder yo'q — kod
    javobda `debug_code` sifatida qaytariladi).

    Suiiste'moldan himoya: bir raqamga ketma-ket so'rovlar orasida eng kam
    `RESEND_COOLDOWN_SECONDS`, bir soatda esa ko'pi bilan `MAX_PER_HOUR` marta
    so'rash mumkin — aks holda 429 (Throttled) qaytariladi.
    """

    permission_classes = (permissions.AllowAny,)
    MAX_PER_HOUR = 5

    def post(self, request):
        serializer = OTPRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()

        # `is_used=False`: allaqachon tasdiqlangan (login uchun ishlatilgan) kod
        # cooldownga hisoblanmaydi — aks holda muvaffaqiyatli kirgan foydalanuvchi
        # chiqib darhol qayta kirmoqchi bo'lsa, 60 soniya davomida yangi kod
        # so'rolmay, 400 xatolikka uchraydi.
        last = (
            PhoneOTP.objects.filter(phone=phone, is_used=False)
            .order_by("-created_at")
            .first()
        )
        if last is not None:
            elapsed = (timezone.now() - last.created_at).total_seconds()
            if elapsed < PhoneOTP.RESEND_COOLDOWN_SECONDS:
                wait = round(PhoneOTP.RESEND_COOLDOWN_SECONDS - elapsed)
                raise ValidationError(
                    f"Biroz kuting, {wait} soniyadan so'ng qayta urining"
                )

        recent_count = PhoneOTP.objects.filter(
            phone=phone, created_at__gte=timezone.now() - timedelta(hours=1)
        ).count()
        if recent_count >= self.MAX_PER_HOUR:
            raise ValidationError(
                "Juda ko'p urinish. Bir soatdan so'ng qayta urinib ko'ring"
            )

        code = "".join(random.choices("0123456789", k=6))
        PhoneOTP.objects.create(phone=phone, code=code)
        return Response(
            {
                "detail": "SMS yuborildi",
                "debug_code": code,
                "resend_after": PhoneOTP.RESEND_COOLDOWN_SECONDS,
            }
        )


class OTPVerifyView(APIView):
    """Kodni tasdiqlab kiradi — foydalanuvchi mavjud bo'lmasa avtomatik
    ro'yxatdan o'tkaziladi (customer sifatida).

    Har bir noto'g'ri urinish shu raqamning eng so'nggi faol kodiga
    (`PhoneOTP.attempts`) yoziladi — `MAX_ATTEMPTS`dan oshsa kod bekor
    qilinadi va foydalanuvchi yangi kod so'rashga majbur bo'ladi (brute-force
    himoyasi: kod 6 xonali bo'lgani uchun cheklovsiz taxmin qilib bo'lmaydi).
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()
        code = serializer.validated_data["code"].strip()

        otp = (
            PhoneOTP.objects.filter(phone=phone, is_used=False)
            .order_by("-created_at")
            .first()
        )
        if not otp or timezone.now() - otp.created_at >= timedelta(minutes=5):
            raise ValidationError("Kod muddati o'tgan. Yangi kod so'rang")
        if otp.attempts >= PhoneOTP.MAX_ATTEMPTS:
            otp.is_used = True
            otp.save(update_fields=["is_used"])
            raise ValidationError("Juda ko'p urinish. Yangi kod so'rang")
        if otp.code != code:
            otp.attempts += 1
            otp.save(update_fields=["attempts"])
            remaining = PhoneOTP.MAX_ATTEMPTS - otp.attempts
            raise ValidationError(f"Kod noto'g'ri. {remaining} ta urinish qoldi")

        otp.is_used = True
        otp.save(update_fields=["is_used"])

        user = User.objects.filter(phone=phone).exclude(phone="").first()
        is_new_user = user is None
        if user is None:
            user = User(phone=phone, email=f"{phone}@phone.local", role=User.Role.CUSTOMER)
            user.set_unusable_password()
            user.save()

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "is_new_user": is_new_user,
            }
        )
