from django.utils import timezone
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company

from .models import AttendanceAction, AttendanceEditLog, AttendanceRecord, Workplace
from .serializers import (
    AttendanceCheckInSerializer,
    AttendanceEditLogSerializer,
    AttendanceRecordSerializer,
    WorkplaceSerializer,
)
from .services import resolve_check_in


class WorkplaceViewSet(viewsets.ModelViewSet):
    """Firma filiallari — faqat kompaniya egasi yarata/tahrirlay oladi,
    xodimlar ro'yxatini o'qishga kirishi mumkin (check-in oldidan qaysi
    filiallar borligini bilishi uchun shart emas, backend o'zi eng
    yaqinini tanlaydi, lekin ro'yxat firma paneli uchun kerak)."""

    serializer_class = WorkplaceSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return Workplace.objects.none()
        return Workplace.objects.filter(company=company, is_deleted=False)

    def _own_company(self):
        company = user_company(self.request.user)
        if company is None or not is_company_owner(self.request.user, company):
            raise PermissionDenied("Faqat kompaniya egasi filiallarni boshqaradi")
        return company

    def perform_create(self, serializer):
        serializer.save(company=self._own_company())

    def perform_update(self, serializer):
        self._own_company()
        serializer.save()

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class AttendanceRecordViewSet(viewsets.ReadOnlyModelViewSet):
    """Davomat yozuvlari — firma egasi barcha xodimlarniki, oddiy xodim
    faqat o'zinikini ko'radi (EmployeeViewSet bilan bir xil naqsh).
    Yaratish faqat `check_in`/`check_out` amallari orqali — to'g'ridan-
    to'g'ri yozib bo'lmaydi (backend qarori shart)."""

    serializer_class = AttendanceRecordSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        user = self.request.user
        company = user_company(user)
        if company is None:
            return AttendanceRecord.objects.none()
        qs = AttendanceRecord.objects.filter(
            employee__company=company, is_deleted=False
        ).select_related("employee__user", "workplace")
        if not is_company_owner(user, company):
            qs = qs.filter(employee__user=user)
        return qs

    def _own_employee(self):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Siz hech qanday firmaga tegishli emassiz")
        employee = Employee.objects.filter(
            company=company, user=self.request.user, is_active=True, is_deleted=False
        ).first()
        if employee is None:
            raise PermissionDenied("Siz shu firmaning faol xodimi emassiz")
        return employee

    def _check(self, request, action_type):
        serializer = AttendanceCheckInSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        employee = self._own_employee()
        record = resolve_check_in(
            employee=employee,
            action=action_type,
            lat=serializer.validated_data["latitude"],
            lng=serializer.validated_data["longitude"],
            accuracy=serializer.validated_data.get("accuracy"),
            is_mock=serializer.validated_data.get("is_mock", False),
            device_timestamp=serializer.validated_data.get("device_timestamp"),
            integrity_token=serializer.validated_data.get("integrity_token"),
            platform=serializer.validated_data.get("platform", "android"),
        )
        return Response(AttendanceRecordSerializer(record).data, status=201)

    @action(detail=False, methods=["post"])
    def check_in(self, request):
        return self._check(request, AttendanceAction.CHECK_IN)

    @action(detail=False, methods=["post"])
    def check_out(self, request):
        return self._check(request, AttendanceAction.CHECK_OUT)

    @action(detail=True, methods=["patch"])
    def manual_edit(self, request, pk=None):
        """Firma egasi (yoki platforma admini) davomat yozuvini qo'lda
        to'g'irlaydi — har bir o'zgarish `AttendanceEditLog`da saqlanadi
        (docs §11, oddiy xodim bu amalni bajara olmaydi)."""
        record = self.get_object()
        user = request.user
        company = user_company(user)
        if not (user.role == "platform_admin" or is_company_owner(user, company)):
            raise PermissionDenied("Faqat firma egasi yoki platforma admini davomatni o'zgartira oladi")

        editable_fields = ("status", "reason", "action")
        old_value = {f: getattr(record, f) for f in editable_fields}
        reason = request.data.get("reason", "")
        changed = False
        for field in editable_fields:
            if field in request.data:
                setattr(record, field, request.data[field])
                changed = True
        if not changed:
            raise ValidationError("O'zgartiriladigan maydon berilmadi")
        record.save(update_fields=list(editable_fields))
        new_value = {f: getattr(record, f) for f in editable_fields}
        AttendanceEditLog.objects.create(
            record=record, changed_by=user, old_value=old_value, new_value=new_value, reason=reason,
        )
        return Response(AttendanceRecordSerializer(record).data)
