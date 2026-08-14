from django.contrib.auth import get_user_model
from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Company, Employee, EmployeeInvitation, PositionPayStandard, Review

User = get_user_model()


class CompanySerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("logo",)
    logo = serializers.ImageField(write_only=True, required=False, allow_null=True)
    logo_url = serializers.SerializerMethodField()
    tier = serializers.SerializerMethodField()
    viloyat_display = serializers.CharField(source="get_viloyat_display", read_only=True, default=None)

    def get_logo_url(self, obj):
        return visible_file_url(obj, "logo", self.context.get("request"))

    def get_tier(self, obj):
        return obj.tier

    class Meta:
        model = Company
        fields = (
            "id",
            "owner",
            "name",
            "slug",
            "description",
            "phone",
            "address",
            "viloyat",
            "viloyat_display",
            "latitude",
            "longitude",
            "service_radius_km",
            "logo",
            "logo_url",
            "instagram_url",
            "telegram_url",
            "facebook_url",
            "website_url",
            "is_active",
            "tier",
            "employment_contract_template",
            "created_at",
        )
        read_only_fields = ("id", "owner", "slug", "created_at")


class EmployeeSerializer(serializers.ModelSerializer):
    """Mavjud xodimni ko'rish/tahrirlash uchun — yangi xodim bu orqali
    yaratilmaydi (qarang: `EmployeeInvitationSerializer`, worker_id bilan
    taklif + qabul qilish oqimi)."""

    user_id = serializers.UUIDField(source="user.id", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_name = serializers.CharField(source="user.first_name", read_only=True)
    user_worker_id = serializers.CharField(source="user.worker_id", read_only=True)
    positions = serializers.ListField(
        child=serializers.ChoiceField(choices=Employee.Position.choices),
        allow_empty=False,
    )

    pay_type_display = serializers.CharField(source="get_pay_type_display", read_only=True)

    class Meta:
        model = Employee
        fields = (
            "id", "user_id", "user_email", "user_name", "user_worker_id",
            "positions", "is_active", "pay_type", "pay_type_display",
            "base_salary", "bonus_per_task", "commission_percent", "hourly_rate", "created_at",
        )
        read_only_fields = ("id", "created_at")


class PositionPayStandardSerializer(serializers.ModelSerializer):
    """`company=None` — platforma admini sozlaydigan global standart;
    `company=<id>` — firma o'ziga moslashtirgan override (qarang
    PositionPayStandardViewSet: kim qaysi turini yarata olishini u
    cheklaydi)."""

    position_display = serializers.CharField(source="get_position_display", read_only=True)
    pay_type_display = serializers.CharField(source="get_pay_type_display", read_only=True)
    is_platform_default = serializers.SerializerMethodField()

    def get_is_platform_default(self, obj):
        return obj.company_id is None

    class Meta:
        model = PositionPayStandard
        fields = (
            "id", "company", "position", "position_display", "pay_type", "pay_type_display",
            "min_salary", "max_salary", "default_bonus_per_task", "default_commission_percent",
            "default_hourly_rate", "kpi_target_tasks_per_month", "kpi_target_on_time_percent",
            "kpi_bonus_multiplier", "is_platform_default", "created_at",
        )
        read_only_fields = ("id", "created_at")


class ReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.first_name", read_only=True)

    class Meta:
        model = Review
        fields = ("id", "company", "customer_name", "rating", "comment", "created_at")
        read_only_fields = ("id", "customer_name", "created_at")

    def validate_rating(self, value):
        if not 1 <= value <= 5:
            raise serializers.ValidationError("Baho 1 dan 5 gacha bo'lishi kerak")
        return value

    def validate_company(self, company):
        from apps.orders.models import Order

        request = self.context["request"]
        has_completed = Order.objects.filter(
            company=company, customer=request.user, status=Order.Status.COMPLETED, is_deleted=False
        ).exists()
        if not has_completed:
            raise serializers.ValidationError(
                "Faqat shu kompaniyadan yakunlangan buyurtmangiz bo'lsa, baho qoldira olasiz"
            )
        return company

    def create(self, validated_data):
        customer = self.context["request"].user
        company = validated_data["company"]
        existing = Review.objects.filter(company=company, customer=customer).first()
        if existing:
            existing.rating = validated_data["rating"]
            existing.comment = validated_data.get("comment", existing.comment)
            existing.save()
            return existing
        return Review.objects.create(customer=customer, **validated_data)


class EmployeeInvitationSerializer(serializers.ModelSerializer):
    worker_id = serializers.CharField(write_only=True)
    invited_user_name = serializers.CharField(source="invited_user.first_name", read_only=True)
    invited_worker_id = serializers.CharField(source="invited_user.worker_id", read_only=True)
    company_name = serializers.CharField(source="company.name", read_only=True)
    company_contract = serializers.CharField(source="company.employment_contract_template", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    positions = serializers.ListField(
        child=serializers.ChoiceField(choices=Employee.Position.choices),
        allow_empty=False,
    )

    class Meta:
        model = EmployeeInvitation
        fields = (
            "id", "company", "company_name", "company_contract", "worker_id",
            "invited_user_name", "invited_worker_id",
            "positions", "pay_type", "base_salary", "bonus_per_task",
            "commission_percent", "hourly_rate", "status", "status_display",
            "responded_at", "created_at",
        )
        read_only_fields = (
            "id", "company", "company_name", "company_contract", "invited_user_name", "invited_worker_id",
            "status", "status_display", "responded_at", "created_at",
        )

    def validate_worker_id(self, value):
        try:
            self._invited_user = User.objects.get(worker_id=value)
        except User.DoesNotExist:
            raise serializers.ValidationError("Bu ID bilan foydalanuvchi topilmadi")
        return value

    def create(self, validated_data):
        validated_data.pop("worker_id")
        company = validated_data["company"]
        if self._invited_user.id == company.owner_id:
            raise serializers.ValidationError("Kompaniya egasini taklif qilib bo'lmaydi")
        existing = EmployeeInvitation.objects.filter(
            company=company, invited_user=self._invited_user, status=EmployeeInvitation.Status.PENDING
        ).first()
        if existing:
            return existing
        return EmployeeInvitation.objects.create(invited_user=self._invited_user, **validated_data)
