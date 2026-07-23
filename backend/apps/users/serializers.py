from django.contrib.auth import get_user_model
from rest_framework import serializers

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("id", "email", "password", "first_name", "last_name", "phone", "role")
        read_only_fields = ("id",)

    def validate_role(self, value):
        # ro'yxatdan faqat customer yoki company_owner bo'lib o'tish mumkin
        if value not in (User.Role.CUSTOMER, User.Role.COMPANY_OWNER):
            raise serializers.ValidationError("Bu rol bilan ro'yxatdan o'tib bo'lmaydi")
        return value

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class UserSerializer(serializers.ModelSerializer):
    company = serializers.SerializerMethodField()
    positions = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id", "email", "first_name", "last_name", "phone", "role",
            "worker_id", "company", "positions", "date_joined",
        )
        read_only_fields = ("id", "email", "role", "worker_id", "company", "positions", "date_joined")

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
