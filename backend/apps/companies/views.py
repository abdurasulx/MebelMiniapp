from django.utils import timezone
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from .models import Branch, Company, Employee, EmployeeInvitation, Review
from .serializers import (
    BranchSerializer,
    CompanySerializer,
    EmployeeInvitationSerializer,
    EmployeeSerializer,
    ReviewSerializer,
)


def user_company(user):
    """Foydalanuvchi boshqaradigan kompaniya: egasi yoki faol xodimi bo'lgan."""
    if not user.is_authenticated:
        return None
    company = Company.objects.filter(owner=user, is_deleted=False).first()
    if company:
        return company
    emp = (
        Employee.objects.filter(user=user, is_active=True, is_deleted=False)
        .select_related("company")
        .first()
    )
    return emp.company if emp and not emp.company.is_deleted else None


def is_company_owner(user, company):
    return bool(company) and company.owner_id == user.id


def user_has_position(user, company, position):
    """Firma egasi har doim ruxsatga ega; xodim bo'lsa, faqat shu `position`
    (masalan "omborchi") unga tayinlangan bo'lsa."""
    if is_company_owner(user, company):
        return True
    if not company:
        return False
    return Employee.objects.filter(
        company=company, user=user, is_active=True, is_deleted=False, positions__contains=[position]
    ).exists()


class IsOwnerOrPlatformAdmin(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        if request.user.is_authenticated and request.user.role == "platform_admin":
            return True
        return obj.owner_id == request.user.id


class CompanyViewSet(viewsets.ModelViewSet):
    serializer_class = CompanySerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly, IsOwnerOrPlatformAdmin)
    lookup_field = "slug"

    def get_queryset(self):
        qs = Company.objects.filter(is_deleted=False)
        user = self.request.user
        # platforma admini hammasini (bloklanganlarni ham) ko'radi
        if user.is_authenticated and user.role == "platform_admin":
            return qs
        return qs.filter(is_active=True)

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class EmployeeViewSet(viewsets.ModelViewSet):
    """Firma portali: kompaniya egasi xodimlarini boshqaradi.

    Yangi xodim to'g'ridan-to'g'ri shu yerda YARATILMAYDI — yagona yo'l
    `EmployeeInvitationViewSet` orqali (worker_id bilan taklif, foydalanuvchi
    o'zi qabul qilgach `Employee` yozuvi hosil bo'ladi). Shuning uchun "create"
    metodi ataylab o'chirilgan — bu yerda faqat mavjud xodimlarni ko'rish,
    tahrirlash (lavozim/maosh) va "ishdan bo'shatish" (soft-delete) mumkin.
    """

    serializer_class = EmployeeSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "patch", "delete", "head", "options")

    def _own_company(self):
        company = Company.objects.filter(
            owner=self.request.user, is_deleted=False
        ).first()
        if company is None:
            raise PermissionDenied("Faqat kompaniya egasi xodimlarni boshqaradi")
        return company

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Employee.objects.none()
        return Employee.objects.filter(
            company=company, is_deleted=False
        ).select_related("user")

    def perform_update(self, serializer):
        self._own_company()
        was_active = serializer.instance.is_active
        instance = serializer.save()
        # Karyera tarixi: faol xodim ishdan bo'shatilsa (is_active True->False)
        # chiqib ketgan sana muhrlanadi; qayta faollashtirilsa tozalanadi.
        if was_active and not instance.is_active:
            instance.left_at = timezone.now()
            instance.save(update_fields=["left_at"])
        elif not was_active and instance.is_active:
            instance.left_at = None
            instance.save(update_fields=["left_at"])

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.is_active = False
        instance.left_at = instance.left_at or timezone.now()
        instance.save(update_fields=["is_deleted", "is_active", "left_at"])


class EmployeeInvitationViewSet(viewsets.ModelViewSet):
    """Firma xodimni `worker_id` orqali ishga taklif qiladi; foydalanuvchi
    qabul/rad qiladi (docs: ish tarixi/karyera oqimi)."""

    serializer_class = EmployeeInvitationSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "delete", "head", "options")

    def get_queryset(self):
        user = self.request.user
        qs = EmployeeInvitation.objects.filter(is_deleted=False).select_related(
            "company", "invited_user"
        )
        company = user_company(user)
        if company:
            return qs.filter(company=company)
        return qs.filter(invited_user=user)

    def perform_create(self, serializer):
        company = Company.objects.filter(owner=self.request.user, is_deleted=False).first()
        if company is None:
            raise PermissionDenied("Faqat kompaniya egasi xodim taklif qila oladi")
        serializer.save(company=company)

    @action(detail=True, methods=["post"])
    def accept(self, request, pk=None):
        invitation = self.get_object()
        if invitation.invited_user_id != request.user.id:
            raise PermissionDenied("Bu taklif sizga emas")
        if invitation.status != EmployeeInvitation.Status.PENDING:
            raise ValidationError("Bu taklifga allaqachon javob berilgan")

        existing = Employee.objects.filter(
            company=invitation.company, user=invitation.invited_user
        ).first()
        if existing:
            existing.is_active = True
            existing.is_deleted = False
            existing.positions = invitation.positions
            existing.base_salary = invitation.base_salary
            existing.bonus_per_task = invitation.bonus_per_task
            existing.left_at = None
            existing.save()
        else:
            Employee.objects.create(
                company=invitation.company,
                user=invitation.invited_user,
                positions=invitation.positions,
                base_salary=invitation.base_salary,
                bonus_per_task=invitation.bonus_per_task,
            )
        if invitation.invited_user.role == "customer":
            invitation.invited_user.role = "employee"
            invitation.invited_user.save(update_fields=["role"])

        invitation.status = EmployeeInvitation.Status.ACCEPTED
        invitation.responded_at = timezone.now()
        invitation.save(update_fields=["status", "responded_at"])
        return Response(EmployeeInvitationSerializer(invitation, context={"request": request}).data)

    @action(detail=True, methods=["post"])
    def decline(self, request, pk=None):
        invitation = self.get_object()
        if invitation.invited_user_id != request.user.id:
            raise PermissionDenied("Bu taklif sizga emas")
        if invitation.status != EmployeeInvitation.Status.PENDING:
            raise ValidationError("Bu taklifga allaqachon javob berilgan")
        invitation.status = EmployeeInvitation.Status.DECLINED
        invitation.responded_at = timezone.now()
        invitation.save(update_fields=["status", "responded_at"])
        return Response(EmployeeInvitationSerializer(invitation, context={"request": request}).data)

    def perform_destroy(self, instance):
        # Faqat firma egasi hali javob berilmagan taklifni bekor qila oladi —
        # qabul/rad qilingan taklif tarix sifatida saqlanib qoladi.
        company = Company.objects.filter(owner=self.request.user, is_deleted=False).first()
        if company is None or instance.company_id != company.id:
            raise PermissionDenied("Faqat kompaniya egasi taklifni bekor qila oladi")
        if instance.status != EmployeeInvitation.Status.PENDING:
            raise ValidationError("Javob berilgan taklifni bekor qilib bo'lmaydi")
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class BranchViewSet(viewsets.ModelViewSet):
    """Firma egasi o'z filiallarini (har biri bitta viloyatga tegishli)
    boshqaradi — mahsulotlar shu filiallarga bog'lanadi va katalog
    foydalanuvchi viloyatiga qarab filtrlanadi."""

    serializer_class = BranchSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        qs = Branch.objects.filter(is_deleted=False).select_related("company")
        company_slug = self.request.query_params.get("company")
        if company_slug:
            qs = qs.filter(company__slug=company_slug)
        return qs

    def _own_company(self):
        company = Company.objects.filter(owner=self.request.user, is_deleted=False).first()
        if company is None:
            raise PermissionDenied("Faqat kompaniya egasi filiallarni boshqaradi")
        return company

    def perform_create(self, serializer):
        company = self._own_company()
        is_main = serializer.validated_data.get("is_main", False)
        if is_main or not company.branches.filter(is_deleted=False).exists():
            Branch.objects.filter(company=company, is_deleted=False).update(is_main=False)
            serializer.save(company=company, is_main=True)
        else:
            serializer.save(company=company)

    def perform_update(self, serializer):
        company = self._own_company()
        if serializer.instance.company_id != company.id:
            raise PermissionDenied("Bu filial sizga tegishli emas")
        if serializer.validated_data.get("is_main"):
            Branch.objects.filter(company=company, is_deleted=False).exclude(
                pk=serializer.instance.pk
            ).update(is_main=False)
        serializer.save()

    def perform_destroy(self, instance):
        company = self._own_company()
        if instance.company_id != company.id:
            raise PermissionDenied("Bu filial sizga tegishli emas")
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ReviewViewSet(viewsets.ModelViewSet):
    """Mijozlar do'kon sahifasida kompaniyaga baho qoldiradi (1 mijoz — 1 baho)."""

    serializer_class = ReviewSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)
    http_method_names = ("get", "post", "head", "options")

    def get_queryset(self):
        qs = Review.objects.filter(is_deleted=False).select_related("customer")
        company = self.request.query_params.get("company")
        if company:
            qs = qs.filter(company__slug=company)
        return qs
