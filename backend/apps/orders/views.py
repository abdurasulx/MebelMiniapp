from datetime import timedelta

from django.db.models import Avg, DurationField, ExpressionWrapper, F
from django.utils import timezone
from rest_framework import mixins, permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.views import user_company
from apps.workflow.models import StepStatus, WorkflowStepInstance

from .models import Order
from .serializers import OrderCreateSerializer, OrderSerializer


class OrderViewSet(
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.ListModelMixin,
    viewsets.GenericViewSet,
):
    """Mijoz yaratadi va o'zinikini ko'radi; kompaniya (ega/xodim) o'z
    buyurtmalarini ko'radi va statusini boshqaradi; admin hammasini ko'radi."""

    permission_classes = (permissions.IsAuthenticated,)

    def get_serializer_class(self):
        return OrderCreateSerializer if self.action == "create" else OrderSerializer

    def get_queryset(self):
        qs = Order.objects.filter(is_deleted=False).select_related(
            "company", "customer"
        ).prefetch_related("items")
        user = self.request.user
        if user.role == "platform_admin":
            return qs
        company = user_company(user)
        if company:
            return qs.filter(company=company)
        return qs.filter(customer=user)

    @action(detail=True, methods=["post"])
    def set_status(self, request, pk=None):
        order = self.get_object()
        new_status = request.data.get("status")
        if new_status not in Order.Status.values:
            raise ValidationError("Noto'g'ri status")

        user = request.user
        company = user_company(user)
        is_company_side = company is not None and company.id == order.company_id

        if is_company_side or user.role == "platform_admin":
            allowed = Order.TRANSITIONS.get(order.status, [])
        elif order.customer_id == user.id:
            # mijoz faqat yangi buyurtmasini bekor qila oladi
            allowed = [Order.Status.CANCELLED] if order.status == Order.Status.NEW else []
        else:
            raise PermissionDenied("Bu buyurtma sizniki emas")

        if new_status not in allowed:
            raise ValidationError(
                f"'{order.get_status_display()}' holatidan '{new_status}' ga o'tib bo'lmaydi"
            )
        order.status = new_status
        order.save(update_fields=["status", "updated_at"])
        return Response(OrderSerializer(order, context={"request": request}).data)

    @action(detail=True, methods=["get"])
    def prediction(self, request, pk=None):
        """Tarixiy bosqich davomiyligiga asoslangan taxminiy tugash sanasi
        (docs: Delivery Prediction — statistik taxmin, AI emas)."""
        order = self.get_object()
        pending = order.workflow_steps.filter(
            is_deleted=False, status__in=[StepStatus.PENDING, StepStatus.IN_PROGRESS]
        )
        if not pending.exists():
            if order.workflow_steps.filter(is_deleted=False).exists():
                return Response({"estimated_finish": None, "confidence": None, "detail": "Barcha bosqichlar yakunlangan"})
            return Response({"estimated_finish": None, "confidence": None, "detail": "Workflow mavjud emas"})

        history = WorkflowStepInstance.objects.filter(
            is_deleted=False, order__company_id=order.company_id, status=StepStatus.COMPLETED,
            started_at__isnull=False, completed_at__isnull=False,
        ).annotate(
            duration=ExpressionWrapper(F("completed_at") - F("started_at"), output_field=DurationField())
        )

        total_hours = 0.0
        sample_count = 0
        for step in pending:
            stats = history.filter(name=step.name).aggregate(avg=Avg("duration"))
            if stats["avg"] is not None:
                total_hours += stats["avg"].total_seconds() / 3600
                sample_count += history.filter(name=step.name).count()
            else:
                total_hours += float(step.estimated_hours)

        estimated_finish = timezone.now() + timedelta(hours=total_hours)
        confidence = round(min(0.95, 0.5 + 0.05 * min(sample_count, 9)), 2)
        return Response({
            "estimated_finish": estimated_finish,
            "confidence": confidence,
            "remaining_hours": round(total_hours, 1),
        })
