from django.contrib.auth import get_user_model
from rest_framework import serializers

from common.serializers import StorageStampMixin, visible_file_url

from .models import Company, Employee, EmployeeInvitation, Review

User = get_user_model()


class CompanySerializer(StorageStampMixin, serializers.ModelSerializer):
    file_fields = ("logo",)
    logo = serializers.ImageField(write_only=True, required=False, allow_null=True)
    logo_url = serializers.SerializerMethodField()
    tier = serializers.SerializerMethodField()

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
            "logo",
            "logo_url",
            "is_active",
            "tier",
            "created_at",
        )
        read_only_fields = ("id", "owner", "slug", "created_at")


class EmployeeSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(write_only=True)
    user_id = serializers.UUIDField(source="user.id", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_name = serializers.CharField(source="user.first_name", read_only=True)
    positions = serializers.ListField(
        child=serializers.ChoiceField(choices=Employee.Position.choices),
        allow_empty=False,
    )

    class Meta:
        model = Employee
        fields = (
            "id", "email", "user_id", "user_email", "user_name",
            "positions", "is_active", "base_salary", "bonus_per_task", "created_at",
        )
        read_only_fields = ("id", "created_at")

    def validate_email(self, value):
        try:
            self._user = User.objects.get(email__iexact=value)
        except User.DoesNotExist:
            raise serializers.ValidationError(
                "Bu email bilan foydalanuvchi topilmadi. Xodim avval saytda ro'yxatdan o'tsin."
            )
        return value

    def create(self, validated_data):
        validated_data.pop("email")
        company = validated_data["company"]
        user = self._user
        if user.id == company.owner_id:
            raise serializers.ValidationError("Kompaniya egasini xodim qilib qo'shib bo'lmaydi")
        existing = Employee.objects.filter(company=company, user=user).first()
        if existing:
            existing.is_active = True
            existing.is_deleted = False
            existing.positions = validated_data.get("positions", existing.positions)
            existing.base_salary = validated_data.get("base_salary", existing.base_salary)
            existing.bonus_per_task = validated_data.get("bonus_per_task", existing.bonus_per_task)
            existing.save()
            return existing
        if user.role == User.Role.CUSTOMER:
            user.role = User.Role.EMPLOYEE
            user.save(update_fields=["role"])
        return Employee.objects.create(user=user, **validated_data)


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
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    positions = serializers.ListField(
        child=serializers.ChoiceField(choices=Employee.Position.choices),
        allow_empty=False,
    )

    class Meta:
        model = EmployeeInvitation
        fields = (
            "id", "company", "company_name", "worker_id", "invited_user_name", "invited_worker_id",
            "positions", "base_salary", "bonus_per_task", "status", "status_display",
            "responded_at", "created_at",
        )
        read_only_fields = (
            "id", "company", "company_name", "invited_user_name", "invited_worker_id",
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
