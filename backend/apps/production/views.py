from datetime import date
from decimal import Decimal, InvalidOperation

from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.models import Company, Employee
from apps.companies.views import user_company

from .models import Payslip, PayslipPayment
from .serializers import PayslipPaymentSerializer, PayslipSerializer


def is_manager(user, company):
    return user.role == "platform_admin" or (
        company is not None and Company.objects.filter(id=company.id, owner=user).exists()
    )


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
            # Avans/to'lov berilgan (`paid_total > 0`) oylik endi qayta
            # hisoblanmaydi — aks holda summasi to'lovlar ortidan
            # o'zgarib, hisob-kitob buzilib qolardi (qarang
            # Payslip.apply_payment).
            if payslip.paid_total == 0:
                payslip.recompute()
                payslip.save()
            results.append(payslip)

        serializer = self.get_serializer(results, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def set_hours(self, request, pk=None):
        """Soatbay xodim uchun — firma shu oy ishlagan soatni qo'lda
        kiritadi, so'ng jami summa shu asosda qayta hisoblanadi (avtomatik
        vaqt hisoblagich hozircha yo'q)."""
        payslip = self.get_object()
        company = user_company(request.user)
        if not is_manager(request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi soat kiritadi")
        if payslip.paid_total > 0:
            raise ValidationError("Avans/to'lov berilgan ish haqini o'zgartirib bo'lmaydi")
        try:
            hours = float(request.data.get("manual_hours"))
        except (TypeError, ValueError):
            raise ValidationError("manual_hours raqam bo'lishi kerak")
        if hours < 0:
            raise ValidationError("manual_hours manfiy bo'lishi mumkin emas")
        payslip.manual_hours = hours
        payslip.recompute()
        payslip.save()
        return Response(self.get_serializer(payslip).data)

    @action(detail=True, methods=["post"])
    def mark_paid(self, request, pk=None):
        """Butun qoldiqni bir zumda "yakuniy to'lov" sifatida yopadi —
        oldingi (avans yo'q) UI oqimi bilan bir xil, lekin endi ham
        `PayslipPayment` tarixiga real yozuv qoldiradi (qarang
        `Payslip.apply_payment`), shunda "to'landi" belgisi hech qachon
        haqiqiy to'lov tarixidan uzilib qolmaydi."""
        payslip = self.get_object()
        company = user_company(request.user)
        if not is_manager(request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi to'langan deb belgilaydi")
        if payslip.is_paid:
            raise ValidationError("Bu oylik allaqachon to'langan")
        try:
            payslip.apply_payment(
                kind=PayslipPayment.Kind.FINAL,
                amount=payslip.outstanding_amount,
                paid_at=timezone.now().date(),
                recorded_by=request.user,
            )
        except DjangoValidationError as e:
            raise ValidationError(e.message)
        return Response(self.get_serializer(payslip).data)

    @action(detail=True, methods=["get", "post"])
    def payments(self, request, pk=None):
        """GET — shu oylik uchun barcha to'lovlar tarixi (avans + yakuniy),
        xodim ham (o'zinikini) ko'ra oladi. POST — yangi to'lov (avans yoki
        qisman/to'liq yakuniy) qo'shadi, faqat firma egasi/menejer."""
        payslip = self.get_object()
        if request.method == "GET":
            qs = payslip.payments.filter(is_deleted=False)
            return Response(PayslipPaymentSerializer(qs, many=True).data)

        company = user_company(request.user)
        if not is_manager(request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi to'lov qo'sha oladi")
        kind = request.data.get("kind")
        if kind not in PayslipPayment.Kind.values:
            raise ValidationError("kind 'advance' yoki 'final' bo'lishi kerak")
        try:
            amount = Decimal(str(request.data.get("amount")))
        except (TypeError, ValueError, InvalidOperation):
            raise ValidationError("amount raqam bo'lishi kerak")
        paid_at_raw = request.data.get("paid_at")
        paid_at = date.fromisoformat(paid_at_raw) if paid_at_raw else timezone.now().date()
        try:
            payslip.apply_payment(
                kind=kind, amount=amount, paid_at=paid_at,
                note=request.data.get("note", ""), recorded_by=request.user,
            )
        except DjangoValidationError as e:
            raise ValidationError(e.message)
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
