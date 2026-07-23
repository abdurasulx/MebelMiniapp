from datetime import date

from django.utils import timezone
from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.models import Company, Employee
from apps.companies.views import user_company

from .models import Payslip, ProductionTask
from .serializers import PayslipSerializer, ProductionTaskSerializer


def is_manager(user, company):
    return user.role == "platform_admin" or (
        company is not None and Company.objects.filter(id=company.id, owner=user).exists()
    )


class ProductionTaskViewSet(viewsets.ModelViewSet):
    """Firma (ega) vazifa yaratadi/tayinlaydi; xodim faqat o'ziga
    tayinlangan vazifalarni ko'radi va statusini o'zgartiradi."""

    serializer_class = ProductionTaskSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = ProductionTask.objects.filter(is_deleted=False).select_related(
            "assigned_to", "order"
        )
        user = self.request.user
        if user.role == "platform_admin":
            return qs
        company = user_company(user)
        if company is None:
            return qs.none()
        qs = qs.filter(company=company)
        if is_manager(user, company):
            return qs
        # oddiy xodim faqat o'ziga tayinlangan vazifalarni ko'radi
        return qs.filter(assigned_to=user)

    def perform_create(self, serializer):
        company = user_company(self.request.user)
        if company is None or not is_manager(self.request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi vazifa yarata oladi")
        serializer.save(company=company)

    def perform_update(self, serializer):
        instance = serializer.instance
        user = self.request.user
        company = user_company(user)
        manager = is_manager(user, company)
        is_assignee = instance.assigned_to_id == user.id

        if not (manager or is_assignee):
            raise PermissionDenied("Bu vazifa sizniki emas")

        if not manager:
            # oddiy xodim faqat statusini o'zgartira oladi
            allowed_fields = {"status"}
            provided = set(self.request.data.keys())
            if not provided.issubset(allowed_fields):
                raise PermissionDenied("Faqat statusni o'zgartira olasiz")

        extra = {}
        new_status = serializer.validated_data.get("status")
        if new_status == ProductionTask.Status.DONE and instance.status != ProductionTask.Status.DONE:
            extra["completed_at"] = timezone.now()
        elif new_status and new_status != ProductionTask.Status.DONE:
            extra["completed_at"] = None

        serializer.save(**extra)

    def perform_destroy(self, instance):
        company = user_company(self.request.user)
        if not is_manager(self.request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi o'chira oladi")
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class PayslipViewSet(
    mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    """Ishchi oyligini hisoblash: ega har oy uchun "Hisoblash"ni bosadi,
    xodim faqat o'z ish haqini ko'radi."""

    serializer_class = PayslipSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = Payslip.objects.filter(is_deleted=False).select_related("employee__user")
        user = self.request.user
        company = user_company(user)
        if user.role == "platform_admin":
            pass
        elif company is not None and is_manager(user, company):
            qs = qs.filter(company=company)
        elif company is not None:
            emp = Employee.objects.filter(company=company, user=user).first()
            qs = qs.filter(employee=emp) if emp else qs.none()
        else:
            return qs.none()

        period = self.request.query_params.get("period")
        if period:
            qs = qs.filter(period=_parse_period(period))
        return qs

    @action(detail=False, methods=["post"])
    def generate(self, request):
        company = user_company(request.user)
        if company is None or not is_manager(request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi ish haqini hisoblaydi")

        period_raw = request.data.get("period")
        if not period_raw:
            raise ValidationError("period majburiy (masalan 2026-07)")
        period = _parse_period(period_raw)

        results = []
        employees = Employee.objects.filter(
            company=company, is_deleted=False, is_active=True
        ).select_related("user")
        for emp in employees:
            payslip, _ = Payslip.objects.get_or_create(
                company=company, employee=emp, period=period
            )
            if not payslip.is_paid:
                payslip.recompute()
                payslip.save()
            results.append(payslip)

        serializer = self.get_serializer(results, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def mark_paid(self, request, pk=None):
        payslip = self.get_object()
        company = user_company(request.user)
        if not is_manager(request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi to'langan deb belgilaydi")
        payslip.is_paid = True
        payslip.paid_at = timezone.now()
        payslip.save(update_fields=["is_paid", "paid_at"])
        return Response(self.get_serializer(payslip).data)


def _parse_period(raw):
    """'2026-07' yoki '2026-07-01' -> oyning 1-kuni (date)."""
    parts = raw.split("-")
    if len(parts) < 2:
        raise ValidationError("period formati YYYY-MM bo'lishi kerak")
    try:
        return date(int(parts[0]), int(parts[1]), 1)
    except ValueError:
        raise ValidationError("period formati YYYY-MM bo'lishi kerak")
