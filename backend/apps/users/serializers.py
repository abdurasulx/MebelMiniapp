from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class AdminTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Email+parol bilan kirish — endi faqat platforma admini uchun (mijoz/
    xodim Google yoki Telegram orqali kiradi, firma egasi esa alohida
    `FirmaTokenObtainPairSerializer` orqali). `self.user` ni
    `super().validate()` autentifikatsiyadan keyin o'rnatadi, shundan
    keyingina rolni tekshiramiz — noto'g'ri parol bilan urinishlarda ham
    "faqat admin uchun" deb emas, oddiy autentifikatsiya xatosi chiqadi."""

    def validate(self, attrs):
        data = super().validate(attrs)
        if self.user.role != User.Role.PLATFORM_ADMIN:
            raise serializers.ValidationError(
                "Bu usul faqat administratorlar uchun. Google yoki Telegram orqali kiring."
            )
        return data


class FirmaTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Email+parol bilan kirish — faqat firma egasi (company_owner) uchun.
    Xodimlar (employee) va boshqa rollar hamon Google/Telegram orqali
    kiradi — bu endpoint faqat firma.qrbite.uz login sahifasida ishlatiladi,
    admin portali bilan aralashmasin deb ataylab alohida serializer/endpoint
    qilingan (qarang AdminTokenObtainPairSerializer)."""

    def validate(self, attrs):
        data = super().validate(attrs)
        if self.user.role != User.Role.COMPANY_OWNER:
            raise serializers.ValidationError(
                "Bu usul faqat firma egalari uchun. Google yoki Telegram orqali kiring."
            )
        return data


class UserSerializer(serializers.ModelSerializer):
    company = serializers.SerializerMethodField()
    positions = serializers.SerializerMethodField()
    has_google = serializers.SerializerMethodField()
    has_telegram = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id", "email", "first_name", "last_name", "phone", "date_of_birth", "role",
            "worker_id", "company", "positions", "is_active", "date_joined",
            "registration_completed", "phone_verified", "has_google", "has_telegram",
        )
        read_only_fields = (
            "id", "email", "role", "worker_id", "company", "positions", "is_active", "date_joined",
            "registration_completed", "phone_verified", "has_google", "has_telegram",
        )

    def get_has_google(self, obj):
        return obj.google_accounts.exists()

    def get_has_telegram(self, obj):
        return obj.telegram_accounts.exists()

    def get_company(self, obj):
        from apps.companies.views import user_company

        company = user_company(obj)
        if company is None:
            return None
        return {"id": str(company.id), "slug": company.slug, "name": company.name}

    def get_positions(self, obj):
        """Xodimning kasblari (multi-role) — kirishda rol tanlash uchun."""
        emp = obj.employments.filter(is_active=True, is_deleted=False).first()
        return emp.positions if emp else []


class GoogleLoginSerializer(serializers.Serializer):
    # Google Identity Services JS SDK / native SDK'dan kelgan ID token (JWT).
    credential = serializers.CharField()


class CompleteRegistrationSerializer(serializers.Serializer):
    """Google/Telegram orqali yangi hisob ochilgandan keyingi yakuniy qadam
    — qarang CompleteRegistrationView. Faqat `registration_completed=False`
    bo'lgan hisob uchun bir marta ishlaydi (rol keyinchalik shu orqali
    o'zgartirib bo'lmaydi — bu ro'yxatdan o'tishning davomi, huquq
    ko'tarish vositasi emas)."""

    role = serializers.ChoiceField(choices=(User.Role.CUSTOMER, User.Role.COMPANY_OWNER))
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    company_name = serializers.CharField(max_length=200, required=False, allow_blank=True)

    def validate(self, attrs):
        if attrs["role"] == User.Role.COMPANY_OWNER and not attrs.get("company_name", "").strip():
            raise serializers.ValidationError({"company_name": "Kompaniya nomini kiriting"})
        return attrs


class OTPRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20)
    code = serializers.CharField(max_length=6)


class CareerEntrySerializer(serializers.Serializer):
    """Foydalanuvchining kompaniyalararo ish tarixi — karyerasiga ta'sir qiladigan
    yozuv (qaysi firmada, qaysi rol(lar)da, qachondan-qachongacha ishlagan)."""

    company_name = serializers.CharField(source="company.name")
    company_slug = serializers.CharField(source="company.slug")
    positions = serializers.ListField()
    is_active = serializers.BooleanField()
    joined_at = serializers.DateTimeField(source="created_at")
    left_at = serializers.DateTimeField(allow_null=True)
