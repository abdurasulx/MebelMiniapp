import random
from datetime import timedelta
from uuid import UUID

from django.conf import settings
from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.companies.models import Company
from apps.orders.models import Order
from apps.products.models import Product

from . import telegram_bot
from .google_auth import verify_google_credential
from .models import GoogleAccount, PhoneOTP, TelegramAccount, TelegramLoginSession
from .serializers import (
    AdminTokenObtainPairSerializer,
    CareerEntrySerializer,
    CompleteRegistrationSerializer,
    GoogleLoginSerializer,
    OTPRequestSerializer,
    OTPVerifySerializer,
    UserSerializer,
)

User = get_user_model()


class AdminTokenObtainPairView(TokenObtainPairView):
    """Email+parol bilan kirish — faqat platforma admini uchun (qarang
    AdminTokenObtainPairSerializer). Boshqa rollar Google/Telegram orqali kiradi."""

    serializer_class = AdminTokenObtainPairSerializer


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


class AdminUserToggleActiveView(APIView):
    """`/admin/users/<id>/toggle-active/` — platforma admini foydalanuvchini
    bloklaydi/blokdan chiqaradi (`is_active`). O'zini bloklab qo'yishning
    oldi olinadi."""

    permission_classes = (IsPlatformAdmin,)

    def post(self, request, pk):
        try:
            user = User.objects.get(pk=pk)
        except User.DoesNotExist:
            raise ValidationError("Foydalanuvchi topilmadi")
        if user.id == request.user.id:
            raise ValidationError("O'zingizni bloklay olmaysiz")
        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        return Response(UserSerializer(user, context={"request": request}).data)


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


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class CompleteRegistrationView(APIView):
    """Google/Telegram orqali yangi hisob ochilgandan keyingi yakuniy qadam
    — foydalanuvchi rol (mijoz/firma egasi) va profil ma'lumotlarini
    to'ldiradi. Faqat `registration_completed=False` bo'lgan hisob uchun
    BIR MARTA ishlaydi — allaqachon yakunlangan hisobda qayta chaqirilsa
    rad etiladi (bu rol o'zgartirish vositasi emas, faqat ro'yxatdan
    o'tishning davomi)."""

    def post(self, request):
        if request.user.registration_completed:
            raise ValidationError("Ro'yxatdan o'tish allaqachon yakunlangan")

        serializer = CompleteRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        user = request.user
        user.role = data["role"]
        user.first_name = data["first_name"].strip()
        user.last_name = data.get("last_name", "").strip()
        if data.get("phone"):
            user.phone = data["phone"].strip()
        user.registration_completed = True
        user.save(update_fields=["role", "first_name", "last_name", "phone", "registration_completed"])

        if data["role"] == User.Role.COMPANY_OWNER:
            Company.objects.create(owner=user, name=data["company_name"].strip())

        return Response(UserSerializer(user, context={"request": request}).data)


class PhoneVerifyRequestView(APIView):
    """Autentifikatsiyalangan foydalanuvchi telefonini tasdiqlash uchun SMS
    kod so'raydi. Google/Telegram orqali kirib `phone_verified=False`
    bo'lgan foydalanuvchi buyurtma berishdan oldin shu orqali telefonini
    tasdiqlashi kerak (qarang OrderViewSet.perform_create)."""

    def post(self, request):
        serializer = OTPRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()
        return Response(_request_otp(phone))


class PhoneVerifyConfirmView(APIView):
    """Kodni tasdiqlab, joriy foydalanuvchining telefonini bog'laydi va
    `phone_verified=True` qiladi. Boshqa hisobga allaqachon bog'langan
    raqam bilan urinish rad etiladi — bitta raqam bitta hisobga tegishli
    bo'lishi kerak."""

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()
        code = serializer.validated_data["code"].strip()
        _consume_otp(phone, code)

        if User.objects.filter(phone=phone).exclude(phone="").exclude(pk=request.user.pk).exists():
            raise ValidationError("Bu telefon raqami boshqa hisobga bog'langan")

        user = request.user
        user.phone = phone
        user.phone_verified = True
        user.save(update_fields=["phone", "phone_verified"])
        return Response(UserSerializer(user, context={"request": request}).data)


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


class GoogleLoginView(APIView):
    """Google Identity Services'dan kelgan ID token bilan kirish/ro'yxatdan
    o'tish — parol/OTP flow bilan bir xil javob shaklini (`access`/
    `refresh`/`is_new_user`) qaytaradi.

    Bog'lash tartibi:
    1. `google_sub` bo'yicha `GoogleAccount` topilsa — bevosita o'sha user
       bilan kiriladi.
    2. Topilmasa-yu, shu email bilan **allaqachon** `User` mavjud bo'lsa —
       avtomatik bog'lanadi. Bu xavfsiz, chunki `verify_google_credential`
       email mavjud bo'lgan har qanday tokenni faqat `email_verified: true`
       bo'lsagina o'tkazadi (aks holda pastga hech qachon yetib kelmaydi) —
       ya'ni Google email egaligini allaqachon tekshirgan; email/parol
       bilan kirish endi faqat admin uchun qolgani sabab bu yo'l ishonchli.
    3. Ikkalasi ham topilmasa — yangi `User` yaratiladi, `registration_completed
       =False` bilan (frontend uni `/complete-registration`ga yo'naltiradi —
       qarang CompleteRegistrationView).
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = GoogleLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        claims = verify_google_credential(serializer.validated_data["credential"])

        sub = claims["sub"]
        email = (claims.get("email") or "").strip().lower()

        link = GoogleAccount.objects.select_related("user").filter(google_sub=sub).first()
        if link is not None:
            user = link.user
            if not user.is_active:
                raise ValidationError("Hisobingiz bloklangan. Administrator bilan bog'laning")
            is_new_user = False
        else:
            existing = User.objects.filter(email__iexact=email).first() if email else None
            if existing is not None:
                if not existing.is_active:
                    raise ValidationError("Hisobingiz bloklangan. Administrator bilan bog'laning")
                user = existing
                is_new_user = False
            else:
                user = User(
                    email=email or f"google-{sub}@google.local",
                    first_name=(claims.get("given_name") or "").strip(),
                    last_name=(claims.get("family_name") or "").strip(),
                    role=User.Role.CUSTOMER,
                    registration_completed=False,
                    phone_verified=False,
                )
                user.set_unusable_password()
                user.save()
                is_new_user = True
            GoogleAccount.objects.create(user=user, google_sub=sub, email=email)

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "is_new_user": is_new_user,
            }
        )


class TelegramWebhookView(APIView):
    """Telegram bot yuborgan update'larni qabul qiladi (webhook rejimi —
    qarang apps/users/telegram_bot.py: backend ishga tushganda shu
    endpointga avtomatik `setWebhook` qilinadi).

    Faqat `/start <session_id>` ko'rinishidagi deep-link xabarlarini
    qayta ishlaydi — foydalanuvchi botni `https://t.me/<bot>?start=
    <session_id>` orqali ochganda Telegram shu xabarni yuboradi (qarang
    `TelegramSessionCreateView`). Session'ga foydalanuvchining Telegram
    ma'lumotlarini yozib qo'yadi — asosiy login/hisob-bog'lash mantig'i
    `TelegramSessionPollView`da (frontend shu orada so'rab turadi)."""

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        secret = settings.TELEGRAM_WEBHOOK_SECRET
        if secret and request.headers.get("X-Telegram-Bot-Api-Secret-Token") != secret:
            return Response(status=403)

        message = request.data.get("message") or {}
        text = (message.get("text") or "").strip()
        if text.startswith("/start "):
            payload = text[len("/start "):].strip()
            try:
                session_id = UUID(payload)
            except ValueError:
                session_id = None

            if session_id is not None:
                session = TelegramLoginSession.objects.filter(
                    pk=session_id, is_consumed=False
                ).first()
                if session is not None and not session.is_expired():
                    from_user = message.get("from") or {}
                    session.telegram_id = from_user.get("id")
                    session.telegram_first_name = from_user.get("first_name", "")
                    session.telegram_username = from_user.get("username", "")
                    session.save(
                        update_fields=["telegram_id", "telegram_first_name", "telegram_username"]
                    )
                    chat_id = (message.get("chat") or {}).get("id") or from_user.get("id")
                    if chat_id:
                        telegram_bot.send_message(
                            chat_id, "Saytga muvaffaqiyatli ulandingiz — brauzerga qayting."
                        )

        return Response({"ok": True})


class TelegramSessionCreateView(APIView):
    """"Telegram orqali kirish" tugmasi bosilganda chaqiriladi — yangi
    login-sessiya yaratadi, frontend shu `session_id` bilan
    `https://t.me/<bot>?start=<session_id>` ochadi va natijani
    `TelegramSessionPollView`dan so'rab turadi."""

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        session = TelegramLoginSession.objects.create()
        return Response({"session_id": str(session.id)})


class TelegramSessionPollView(APIView):
    """Frontend shu endpointni so'rab turadi (polling) — bot foydalanuvchini
    aniqlaguncha `{"status": "pending"}`, aniqlagach login qilib
    `{"status": "done", "access", "refresh", "is_new_user"}` qaytaradi.

    Bog'lash: `telegram_id` bo'yicha `TelegramAccount` topilsa shu user
    bilan kiriladi; topilmasa yangi `User` yaratiladi (`registration_completed
    =False` — qarang CompleteRegistrationView). Telegram email bermagani
    uchun Google'dagi kabi email-bo'yicha bog'lash bu yerda mavjud emas."""

    permission_classes = (permissions.AllowAny,)

    def get(self, request, session_id):
        session = get_object_or_404(TelegramLoginSession, pk=session_id)
        if session.is_consumed:
            raise ValidationError("Bu sessiya allaqachon ishlatilgan")
        if session.is_expired():
            raise ValidationError("Sessiya muddati o'tgan. Qayta urinib ko'ring")
        if session.telegram_id is None:
            return Response({"status": "pending"})

        link = (
            TelegramAccount.objects.select_related("user")
            .filter(telegram_id=session.telegram_id)
            .first()
        )
        if link is not None:
            user = link.user
            if not user.is_active:
                raise ValidationError("Hisobingiz bloklangan. Administrator bilan bog'laning")
            is_new_user = False
        else:
            user = User(
                email=f"telegram-{session.telegram_id}@telegram.local",
                first_name=session.telegram_first_name,
                role=User.Role.CUSTOMER,
                registration_completed=False,
                phone_verified=False,
            )
            user.set_unusable_password()
            user.save()
            TelegramAccount.objects.create(
                user=user, telegram_id=session.telegram_id, telegram_username=session.telegram_username
            )
            is_new_user = True

        session.is_consumed = True
        session.save(update_fields=["is_consumed"])

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "status": "done",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "is_new_user": is_new_user,
            }
        )


class TelegramBotInfoView(APIView):
    """Frontend deep-link (`https://t.me/<username>?start=...`) yasashi
    uchun bot username'ini so'raydi."""

    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        username = telegram_bot.get_bot_username()
        return Response({"username": username})


MAX_OTP_PER_HOUR = 5


def _request_otp(phone: str) -> dict:
    """SMS kod yaratadi va suiiste'moldan himoya qiladi (rate-limit) — OTP
    orqali kirish (OTPRequestView) va allaqachon autentifikatsiyalangan
    foydalanuvchi telefon tasdiqlashi (PhoneVerifyRequestView) ikkalasi
    ham shu funksiyani ishlatadi."""
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
            raise ValidationError(f"Biroz kuting, {wait} soniyadan so'ng qayta urining")

    recent_count = PhoneOTP.objects.filter(
        phone=phone, created_at__gte=timezone.now() - timedelta(hours=1)
    ).count()
    if recent_count >= MAX_OTP_PER_HOUR:
        raise ValidationError("Juda ko'p urinish. Bir soatdan so'ng qayta urinib ko'ring")

    code = "".join(random.choices("0123456789", k=6))
    PhoneOTP.objects.create(phone=phone, code=code)
    return {
        "detail": "SMS yuborildi",
        "debug_code": code,
        "resend_after": PhoneOTP.RESEND_COOLDOWN_SECONDS,
    }


def _consume_otp(phone: str, code: str) -> None:
    """Kodni tekshiradi va ishlatilgan deb belgilaydi — muvaffaqiyatsiz
    bo'lsa `ValidationError` ko'taradi. Har bir noto'g'ri urinish
    `PhoneOTP.attempts`ga yoziladi — `MAX_ATTEMPTS`dan oshsa kod bekor
    qilinadi (brute-force himoyasi: kod 6 xonali bo'lgani uchun
    cheklovsiz taxmin qilib bo'lmaydi)."""
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


class OTPRequestView(APIView):
    """Telefon raqamga SMS kod yuborish (hozircha SMS provayder yo'q — kod
    javobda `debug_code` sifatida qaytariladi).

    Suiiste'moldan himoya: bir raqamga ketma-ket so'rovlar orasida eng kam
    `RESEND_COOLDOWN_SECONDS`, bir soatda esa ko'pi bilan `MAX_OTP_PER_HOUR`
    marta so'rash mumkin — aks holda 429 (Throttled) qaytariladi.
    """

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = OTPRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()
        return Response(_request_otp(phone))


class OTPVerifyView(APIView):
    """Kodni tasdiqlab kiradi — foydalanuvchi mavjud bo'lmasa avtomatik
    ro'yxatdan o'tkaziladi (customer sifatida)."""

    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"].strip()
        code = serializer.validated_data["code"].strip()
        _consume_otp(phone, code)

        user = User.objects.filter(phone=phone).exclude(phone="").first()
        is_new_user = user is None
        if user is None:
            user = User(
                phone=phone, email=f"{phone}@phone.local", role=User.Role.CUSTOMER,
                phone_verified=True,
            )
            user.set_unusable_password()
            user.save()
        elif not user.is_active:
            raise ValidationError("Hisobingiz bloklangan. Administrator bilan bog'laning")

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "is_new_user": is_new_user,
            }
        )
