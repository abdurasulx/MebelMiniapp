from django.db.models import Avg, Count, DurationField, ExpressionWrapper, F
from django.utils import timezone
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.views import user_company
from apps.products.models import Product
from apps.products.views import can_manage

from .models import PhotoRequirement, ProgressUpdate, StepStatus, WorkflowStep, WorkflowStepInstance
from .serializers import (
    ProgressUpdateSerializer,
    WorkflowStepInstanceSerializer,
    WorkflowStepSerializer,
)


class WorkflowStepViewSet(viewsets.ModelViewSet):
    """Mahsulot workflow shabloni (`/products/<product_pk>/workflow-steps/`) —
    faqat firma tomonidan (ega/xodim/admin) boshqariladi."""

    serializer_class = WorkflowStepSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return WorkflowStep.objects.filter(
            is_deleted=False, product_id=self.kwargs["product_pk"]
        ).prefetch_related("depends_on")

    def _get_product(self):
        product = Product.objects.select_related("company").get(
            pk=self.kwargs["product_pk"], is_deleted=False
        )
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product

    def perform_create(self, serializer):
        product = self._get_product()
        last_index = (
            WorkflowStep.objects.filter(product=product, is_deleted=False)
            .order_by("-order_index")
            .values_list("order_index", flat=True)
            .first()
        )
        order_index = serializer.validated_data.get("order_index")
        if order_index is None:
            order_index = (last_index + 1) if last_index is not None else 0
        step = serializer.save(product=product, order_index=order_index)
        # depends_on ko'rsatilmagan bo'lsa — oldingi bosqichga avtomatik bog'laymiz
        # (odatiy chiziqli zanjir; DAG kerak bo'lsa keyinroq qo'lda o'zgartiriladi)
        if not serializer.validated_data.get("depends_on"):
            previous = (
                WorkflowStep.objects.filter(
                    product=product, is_deleted=False, order_index__lt=order_index
                )
                .exclude(pk=step.pk)
                .order_by("-order_index")
                .first()
            )
            if previous:
                step.depends_on.set([previous])

    def perform_update(self, serializer):
        self._get_product()
        serializer.save()

    def perform_destroy(self, instance):
        self._get_product()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class WorkflowStepInstanceViewSet(viewsets.ReadOnlyModelViewSet):
    """Buyurtma ishlab chiqarish jarayoni — avtomatik yaratiladi (services.py),
    bu yerda faqat kuzatiladi va progress/complete amallari orqali boshqariladi."""

    serializer_class = WorkflowStepInstanceSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = WorkflowStepInstance.objects.filter(is_deleted=False).select_related(
            "order__company", "order__customer", "employee__user", "completed_by"
        ).prefetch_related("depends_on", "updates")
        user = self.request.user
        if user.role == "platform_admin":
            return qs
        company = user_company(user)
        if company:
            return qs.filter(order__company=company)
        return qs.filter(order__customer=user)

    def _check_company_access(self, instance):
        company = user_company(self.request.user)
        is_company_side = company is not None and company.id == instance.order.company_id
        if not (is_company_side or self.request.user.role == "platform_admin"):
            raise PermissionDenied("Bu bosqichni faqat firma tomoni boshqaradi")

    @action(detail=True, methods=["post"])
    def progress(self, request, pk=None):
        """Ishchi tomonidan cheksiz sonda qoldiriladigan yangilanish (rasm/izoh)."""
        instance = self.get_object()
        self._check_company_access(instance)
        if instance.status == StepStatus.COMPLETED:
            raise ValidationError("Bu bosqich allaqachon yakunlangan")
        instance.activate_if_ready()
        serializer = ProgressUpdateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save(step=instance, employee=request.user, is_completion=False)
        # `get_object()` prefetch qilgan `updates` keshi hali eski — yangi qo'shilgan
        # progress'ni ko'rsatish uchun instansiyani qaytadan olamiz.
        instance = self.get_queryset().get(pk=instance.pk)
        return Response(
            WorkflowStepInstanceSerializer(instance, context={"request": request}).data
        )

    @action(detail=True, methods=["post"])
    def complete(self, request, pk=None):
        """Bosqichni yakunlaydi — talab qilingan bo'lsa rasm shart, keyingi
        bog'liq bosqich(lar) avtomatik ochiladi."""
        instance = self.get_object()
        self._check_company_access(instance)
        if instance.status == StepStatus.COMPLETED:
            raise ValidationError("Bu bosqich allaqachon yakunlangan")
        if not instance.is_available and instance.status != StepStatus.IN_PROGRESS:
            raise ValidationError("Bu bosqich hali boshlanishi mumkin emas — oldingi bosqichlar tugamagan")
        if instance.photo_requirement == PhotoRequirement.REQUIRED and not request.data.get("image"):
            raise ValidationError("Bu bosqichni yakunlash uchun rasm majburiy")

        instance.activate_if_ready()
        serializer = ProgressUpdateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save(step=instance, employee=request.user, is_completion=True)

        instance.status = StepStatus.COMPLETED
        instance.completed_at = timezone.now()
        instance.completed_by = request.user
        instance.save(update_fields=["status", "completed_at", "completed_by", "updated_at"])
        instance.activate_dependents()

        instance = self.get_queryset().get(pk=instance.pk)
        return Response(
            WorkflowStepInstanceSerializer(instance, context={"request": request}).data
        )


class WorkflowStatsView(APIView):
    """Bosqichlar bo'yicha ishlab chiqarish statistikasi (o'rtacha vaqt/narx/soni) —
    firma kompaniyasining yakunlangan bosqichlari tarixidan hisoblanadi."""

    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        company = user_company(request.user)
        if company is None and request.user.role != "platform_admin":
            return Response([])
        qs = WorkflowStepInstance.objects.filter(
            is_deleted=False, status=StepStatus.COMPLETED,
            started_at__isnull=False, completed_at__isnull=False,
        )
        if company is not None:
            qs = qs.filter(order__company=company)
        qs = qs.annotate(
            duration=ExpressionWrapper(F("completed_at") - F("started_at"), output_field=DurationField())
        )
        stats = (
            qs.values("name")
            .annotate(avg_duration=Avg("duration"), avg_cost=Avg("cost"), completed=Count("id"))
            .order_by("-completed")
        )
        data = [
            {
                "name": row["name"],
                "avg_hours": round(row["avg_duration"].total_seconds() / 3600, 1) if row["avg_duration"] else None,
                "avg_cost": round(float(row["avg_cost"]), 2) if row["avg_cost"] is not None else None,
                "completed": row["completed"],
            }
            for row in stats
        ]
        return Response(data)
