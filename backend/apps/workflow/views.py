from django.db import transaction
from django.db.models import Avg, Case, Count, DurationField, ExpressionWrapper, F, IntegerField, Value, When
from django.utils import timezone
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.models import Employee
from apps.companies.views import is_company_owner, user_company
from common.pagination import ConfigurablePageSizePagination
from apps.notifications.services import (
    notify_application_rejected,
    notify_pool_open,
    notify_task_assigned,
    notify_task_available,
)
from apps.products.models import Product
from apps.products.views import can_manage

from .bazis_import import parse_bazis_project
from .models import (
    ApplicationStatus,
    PhotoRequirement,
    ProgressUpdate,
    Stage,
    StepApplication,
    StepStatus,
    WorkflowStep,
    WorkflowStepInstance,
    WorkType,
)
from .serializers import (
    ProgressUpdateSerializer,
    StepApplicationSerializer,
    WorkflowStepInstanceSerializer,
    WorkflowStepSerializer,
    WorkTypeSerializer,
)
from .services import (
    approve_step_and_credit_payroll,
    cancel_step,
    consume_material_on_completion,
    credit_payroll,
    sync_order_status_on_step_completion,
)


class WorkTypeViewSet(viewsets.ModelViewSet):
    """Ish turlari katalogi (`/work-types/`) — firma egasi/menejer
    boshqaradi, xodimlar faqat ko'radi (mahsulot bosqichini yaratishda
    tanlash uchun)."""

    serializer_class = WorkTypeSerializer
    permission_classes = (permissions.IsAuthenticated,)
    http_method_names = ("get", "post", "patch", "delete", "head", "options")

    def get_queryset(self):
        company = user_company(self.request.user)
        if company is None:
            return WorkType.objects.none()
        return WorkType.objects.filter(company=company, is_deleted=False)

    def _own_company(self):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Faqat firma a'zolari ish turlarini boshqaradi")
        return company

    def perform_create(self, serializer):
        serializer.save(company=self._own_company())

    def perform_update(self, serializer):
        self._own_company()
        serializer.save()

    def perform_destroy(self, instance):
        self._own_company()
        instance.is_deleted = True
        instance.is_active = False
        instance.save(update_fields=["is_deleted", "is_active"])


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


class WorkflowStepBazisImportView(APIView):
    """Bazis (mebel CAD) eksport faylidan (`.project`, XML) mahsulot uchun
    workflow bosqichlari shablonini avtomatik tuzadi
    (`/products/<product_pk>/workflow-steps/import-bazis/`).

    Uchta guruh yaratiladi: kesish (varaq materiali bo'yicha), kromkalash
    (lenta turi bo'yicha) va TESHISH — diametr bo'yicha guruhlangan, aynan
    shu maqsad uchun (masalan "Teshish Ø8mm"): har bir guruh o'z `WorkType`
    yozuviga bog'lanadi (firma katalogida topilmasa — narxi 0 bilan
    avtomatik yaratiladi). Narx 0 bo'lsa `WorkflowStep.cost` ham 0 bo'lib
    qoladi — ya'ni admin "Ish turlari" bo'limida narx qo'ymaguncha, bu
    bosqich uchun hech kimga ish haqi yozilmaydi (qarang WorkType.save() /
    Payslip.recompute). Bosqichlar bir-biriga BOG'LANMAYDI (depends_on bo'sh
    qoladi) — turli diametrdagi teshiklar odatda parallel/bir xil operatorda
    bajariladi, admin kerak bo'lsa keyin qo'lda ketma-ketlik belgilaydi."""

    permission_classes = (permissions.IsAuthenticated,)

    def _get_product(self, product_pk):
        product = Product.objects.select_related("company").get(pk=product_pk, is_deleted=False)
        if not can_manage(self.request.user, product.company):
            raise PermissionDenied("Bu mahsulot sizniki emas")
        return product

    def _get_or_create_work_type(self, company, name, unit, stage):
        work_type, _ = WorkType.objects.get_or_create(
            company=company, name=name, defaults={"unit": unit, "stage": stage}
        )
        return work_type

    def post(self, request, product_pk):
        product = self._get_product(product_pk)
        upload = request.FILES.get("file")
        if not upload:
            raise ValidationError("Fayl yuborilmadi")
        try:
            parsed = parse_bazis_project(upload.read())
        except Exception:
            raise ValidationError(
                "Faylni o'qib bo'lmadi — bu Bazis'dan eksport qilingan to'g'ri .project fayli ekanini tekshiring"
            )

        last_index = (
            WorkflowStep.objects.filter(product=product, is_deleted=False)
            .order_by("-order_index")
            .values_list("order_index", flat=True)
            .first()
        )
        next_index = (last_index + 1) if last_index is not None else 0
        created = []

        with transaction.atomic():
            for sheet_name, count in parsed.sheet_usage.items():
                work_type = self._get_or_create_work_type(
                    product.company, f"Kesish: {sheet_name}", "dona", Stage.CUTTING
                )
                step = WorkflowStep.objects.create(
                    product=product, order_index=next_index, name=work_type.name,
                    work_type=work_type, quantity=count,
                    cut_note=f"Bazis import — \"{parsed.product_name}\"",
                )
                created.append(step)
                next_index += 1

            for band_name, count in parsed.band_usage.items():
                work_type = self._get_or_create_work_type(
                    product.company, f"Kromkalash: {band_name}", "dona", Stage.EDGE_PROCESSING
                )
                step = WorkflowStep.objects.create(
                    product=product, order_index=next_index, name=work_type.name,
                    work_type=work_type, quantity=count,
                )
                created.append(step)
                next_index += 1

            for hole_label, count in parsed.hole_groups.items():
                work_type = self._get_or_create_work_type(
                    product.company, f"Teshish {hole_label}", "dona", Stage.OTHER
                )
                step = WorkflowStep.objects.create(
                    product=product, order_index=next_index, name=work_type.name,
                    work_type=work_type, quantity=count,
                )
                created.append(step)
                next_index += 1

        return Response(
            {
                "product_name": parsed.product_name,
                "parts_count": len(parsed.parts),
                "holes_total": sum(parsed.hole_groups.values()),
                "steps": WorkflowStepSerializer(created, many=True, context={"request": request}).data,
            },
            status=201,
        )


class WorkflowStepInstanceViewSet(viewsets.ModelViewSet):
    """Ishlab chiqarish vazifalari — ikki manba: buyurtma qabul qilinganda
    mahsulot retseptidan avtomatik yaratiladigan bosqichlar (bu yerda faqat
    `progress`/`complete` orqali boshqariladi), va firma egasi qo'lda
    yaratadigan vazifalar (avvalgi `ProductionTask`, endi shu yerga
    birlashtirilgan — oddiy CRUD + status).
    """

    serializer_class = WorkflowStepInstanceSerializer
    permission_classes = (permissions.IsAuthenticated,)
    pagination_class = ConfigurablePageSizePagination
    http_method_names = ("get", "post", "patch", "delete", "head", "options")

    def get_queryset(self):
        qs = WorkflowStepInstance.objects.filter(is_deleted=False).select_related(
            "company", "order__customer", "employee__user", "completed_by"
        ).prefetch_related("depends_on", "updates", "applications__employee__user")
        user = self.request.user
        if user.role == "platform_admin":
            return qs
        company = user_company(user)
        if company:
            qs = qs.filter(company=company)
            if is_company_owner(user, company):
                # Firma egasi — butun kompaniyaning barcha vazifalarini ko'radi
                # (rejalashtirish/pipeline uchun), tartib o'zgarmaydi.
                return qs
            # Oddiy xodim ("usta" va h.k.) — faqat o'ziga biriktirilgan
            # vazifalarni ko'radi, boshqa xodimlarnikini emas. Ustaning
            # sahifasida "hozir nima qilishim kerak" ustuvor bo'lishi uchun:
            # jarayonda/kutilayotganlar (bajarilishi mumkin) birinchi, ular
            # ichida muddati yaqinroqlari birinchi, muddatsizlar oxirida.
            qs = qs.filter(employee__user=user)
            return qs.annotate(
                _urgency=Case(
                    When(status=StepStatus.IN_PROGRESS, then=Value(0)),
                    When(status=StepStatus.PENDING, then=Value(1)),
                    default=Value(2),
                    output_field=IntegerField(),
                )
            ).order_by("_urgency", F("deadline").asc(nulls_last=True), "order_index", "created_at")
        # Kompaniya a'zosi bo'lmasa — faqat o'ziga tegishli buyurtmalarning
        # bosqichlarini (masalan mijoz o'z buyurtmasi jarayonini kuzatishi uchun).
        return qs.filter(order__customer=user)

    def _own_company(self):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Faqat firma a'zolari ishlab chiqarishni boshqaradi")
        return company

    def _check_company_access(self, instance):
        company = user_company(self.request.user)
        is_company_side = company is not None and company.id == instance.company_id
        if not (is_company_side or self.request.user.role == "platform_admin"):
            raise PermissionDenied("Bu bosqichni faqat firma tomoni boshqaradi")

    def perform_create(self, serializer):
        """Qo'lda vazifa yaratish — faqat firma egasi (retsept bosqichlari
        buyurtma yaratilganda `services.create_workflow_instances` orqali
        avtomatik hosil bo'ladi, bu yerdan emas). Bu endpoint orqali
        yaratilgan HAR BIR vazifa "erkin" hisoblanadi — shuning uchun
        admin/operator `requires_approval`ni ANIQ tanlashi shart (docs
        "Buyurtmalar va topshiriqlar tizimi" §3.2) — jim qoldirilsa
        (model default'iga sukut bilan tayanish) xato qaytadi."""
        company = self._own_company()
        if not is_company_owner(self.request.user, company):
            raise PermissionDenied("Faqat firma egasi vazifa yarata oladi")
        order = serializer.validated_data.get("order")
        if order is not None and order.company_id != company.id:
            raise ValidationError("Bu buyurtma sizning kompaniyangizga tegishli emas")
        if "requires_approval" not in self.request.data:
            raise ValidationError(
                {"requires_approval": "Erkin topshiriq uchun tasdiqlash shartmi-yo'qmi aniq tanlanishi kerak"}
            )
        instance = serializer.save(company=company)
        if instance.employee_id:
            notify_task_assigned(instance)

    def perform_update(self, serializer):
        instance = serializer.instance
        user = self.request.user
        company = user_company(user)
        manager = company is not None and is_company_owner(user, company)
        is_assignee = instance.employee_id is not None and instance.employee.user_id == user.id

        if not (manager or is_assignee or user.role == "platform_admin"):
            raise PermissionDenied("Bu vazifa sizniki emas")

        if instance.template_step_id is not None:
            raise ValidationError(
                "Retsept bosqichi to'g'ridan-to'g'ri tahrirlanmaydi — 'progress'/'complete' orqali boshqaring"
            )

        if not manager and user.role != "platform_admin":
            # oddiy xodim faqat statusini o'zgartira oladi
            allowed_fields = {"status"}
            provided = set(self.request.data.keys())
            if not provided.issubset(allowed_fields):
                raise PermissionDenied("Faqat statusni o'zgartira olasiz")

        extra = {}
        new_status = serializer.validated_data.get("status")
        if new_status == StepStatus.COMPLETED and instance.status != StepStatus.COMPLETED:
            extra["completed_at"] = timezone.now()
            extra["completed_by"] = user
        elif new_status == StepStatus.IN_PROGRESS and instance.status == StepStatus.PENDING:
            extra["started_at"] = timezone.now()
        elif new_status and new_status != StepStatus.COMPLETED:
            extra["completed_at"] = None

        previous_employee_id = instance.employee_id
        updated = serializer.save(**extra)
        if updated.employee_id and updated.employee_id != previous_employee_id:
            notify_task_assigned(updated)
        if new_status == StepStatus.COMPLETED and updated.order_id:
            sync_order_status_on_step_completion(updated.order)

    def perform_destroy(self, instance):
        company = self._own_company()
        if not is_company_owner(self.request.user, company) and self.request.user.role != "platform_admin":
            raise PermissionDenied("Faqat firma egasi o'chira oladi")
        if instance.template_step_id is not None:
            raise ValidationError("Retsept bosqichi alohida o'chirilmaydi")
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])

    def _get_step_or_404(self, pk):
        try:
            return WorkflowStepInstance.objects.select_related("company").get(pk=pk, is_deleted=False)
        except WorkflowStepInstance.DoesNotExist:
            raise ValidationError("Bosqich topilmadi")

    @action(detail=False, methods=["get"], url_path="open")
    def open_pool(self, request):
        """Xodimi hali biriktirilmagan, boshlanishga tayyor (bog'liq
        bosqichlar tugagan) bosqichlar — "erkin topshiriqlar hovuzi". Usta
        uchun o'z lavozimiga mos bosqichlar bilan cheklanadi (zayavka
        yuborish uchun); firma egasi/menejer uchun BARCHASI ko'rsatiladi
        (kerak bo'lsa bekor qilish uchun, qarang `cancel`)."""
        company = user_company(request.user)
        if company is None:
            return Response([])
        qs = WorkflowStepInstance.objects.filter(
            is_deleted=False, company=company, employee__isnull=True, status=StepStatus.PENDING,
        ).exclude(depends_on__status__in=[StepStatus.PENDING, StepStatus.IN_PROGRESS])
        if not is_company_owner(request.user, company):
            employee = Employee.objects.filter(
                company=company, user=request.user, is_active=True, is_deleted=False
            ).first()
            if employee is None or not employee.positions:
                return Response([])
            qs = qs.filter(role__in=employee.positions)
        qs = (
            qs.select_related("company", "order__customer", "completed_by")
            .prefetch_related("depends_on", "updates", "applications__employee__user")
            .distinct()
            .order_by("order_index", "created_at")
        )
        page = self.paginate_queryset(qs)
        target = page if page is not None else qs
        serializer = self.get_serializer(target, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data)

    @action(detail=True, methods=["post"])
    def apply(self, request, pk=None):
        """Usta "erkin" bosqichni QABUL QILADI — firma egasi/menejer
        tasdig'i SHART EMAS, shu zahoti bosqichga biriktiriladi. Bir nechta
        usta bir vaqtda urinsa ham, faqat birinchisi ulguradi — shu
        sabab tekshiruv+biriktirish bitta qulflangan tranzaksiya ichida."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id:
            raise PermissionDenied("Bu bosqich sizning kompaniyangizga tegishli emas")
        employee = Employee.objects.filter(
            company=company, user=request.user, is_active=True, is_deleted=False
        ).first()
        if employee is None:
            raise PermissionDenied("Siz bu kompaniya xodimi emassiz")
        if instance.role and instance.role not in (employee.positions or []):
            raise ValidationError("Bu bosqich sizning lavozimingizga mos emas")
        now = timezone.now()
        with transaction.atomic():
            locked = WorkflowStepInstance.objects.select_for_update().get(pk=instance.pk)
            if locked.employee_id:
                raise ValidationError("Bu bosqich allaqachon boshqa ustaga biriktirilgan")
            if not locked.is_available:
                raise ValidationError("Bu bosqich hali boshlanishi mumkin emas — oldingi bosqichlar tugamagan")
            locked.employee = employee
            locked.save(update_fields=["employee", "updated_at"])
            StepApplication.objects.update_or_create(
                step=locked, employee=employee,
                defaults={"status": ApplicationStatus.APPROVED, "decided_at": now},
            )
            instance = locked
        notify_task_assigned(instance)
        instance = self.get_queryset().filter(pk=instance.pk).first() or instance
        return Response(WorkflowStepInstanceSerializer(instance, context={"request": request}).data)

    @action(detail=True, methods=["post"])
    def release(self, request, pk=None):
        """Usta avval o'zi qabul qilgan bosqichni O'TKAZIB YUBORADI — yana
        ustasiz ("erkin") holatga qaytadi, boshqa mos lavozimdagi ustalar
        hovuzida qayta ko'rinadi. Faqat hali TUGALLANMAGAN (pending yoki
        in_progress) bosqich uchun — material/ish haqiga hali ta'sir
        qilmagan, shuning uchun oddiy qaytarish yetarli. Shu bosqichga
        biriktirilgan ustaning o'zi yoki firma egasi/menejer chaqira oladi."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id:
            raise PermissionDenied("Bu bosqich sizning kompaniyangizga tegishli emas")
        employee = Employee.objects.filter(
            company=company, user=request.user, is_active=True, is_deleted=False
        ).first()
        if not is_company_owner(request.user, company) and (
            employee is None or instance.employee_id != employee.id
        ):
            raise PermissionDenied("Faqat shu bosqichga biriktirilgan usta yoki firma egasi o'tkazib yubora oladi")
        if not instance.employee_id:
            raise ValidationError("Bu bosqich hech kimga biriktirilmagan")
        if instance.status not in (StepStatus.PENDING, StepStatus.IN_PROGRESS):
            raise ValidationError("Bu bosqichni faqat hali tugallanmagan holatda o'tkazib yuborish mumkin")
        with transaction.atomic():
            StepApplication.objects.filter(
                step=instance, employee_id=instance.employee_id, status=ApplicationStatus.APPROVED
            ).update(status=ApplicationStatus.REJECTED, decided_at=timezone.now())
            instance.employee = None
            instance.status = StepStatus.PENDING
            instance.started_at = None
            instance.save(update_fields=["employee", "status", "started_at", "updated_at"])
        notify_pool_open(instance)
        instance = self.get_queryset().filter(pk=instance.pk).first() or instance
        return Response(WorkflowStepInstanceSerializer(instance, context={"request": request}).data)

    @action(detail=True, methods=["get"])
    def applications(self, request, pk=None):
        """Bosqichga yuborilgan zayavkalar ro'yxati — faqat firma egasi/menejer."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id or not is_company_owner(request.user, company):
            raise PermissionDenied("Faqat firma tomoni zayavkalarni ko'radi")
        qs = instance.applications.filter(is_deleted=False).select_related("employee__user").order_by("created_at")
        return Response(StepApplicationSerializer(qs, many=True).data)

    @action(detail=True, methods=["post"], url_path="approve-application")
    def approve_application(self, request, pk=None):
        """Zayavkalardan bittasini tanlaydi — shu usta bosqichga
        biriktiriladi, qolgan barcha kutilayotgan zayavkalar avtomatik rad
        etiladi (va endi hech kimning ilovasida ko'rinmaydi, chunki
        `open_pool` faqat `employee__isnull=True` bosqichlarni qaytaradi)."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id or not is_company_owner(request.user, company):
            raise PermissionDenied("Faqat firma tomoni tasdiqlaydi")
        if instance.employee_id:
            raise ValidationError("Bu bosqich allaqachon biriktirilgan")
        application_id = request.data.get("application_id")
        if not application_id:
            raise ValidationError("application_id kerak")
        try:
            application = instance.applications.get(
                pk=application_id, is_deleted=False, status=ApplicationStatus.PENDING
            )
        except StepApplication.DoesNotExist:
            raise ValidationError("Zayavka topilmadi yoki allaqachon hal qilingan")

        now = timezone.now()
        with transaction.atomic():
            instance.employee = application.employee
            instance.save(update_fields=["employee", "updated_at"])
            application.status = ApplicationStatus.APPROVED
            application.decided_at = now
            application.save(update_fields=["status", "decided_at", "updated_at"])
            rejected = list(
                instance.applications.filter(is_deleted=False, status=ApplicationStatus.PENDING).exclude(
                    pk=application.pk
                )
            )
            instance.applications.filter(is_deleted=False, status=ApplicationStatus.PENDING).exclude(
                pk=application.pk
            ).update(status=ApplicationStatus.REJECTED, decided_at=now)

        instance.activate_if_ready()
        notify_task_assigned(instance)
        for r in rejected:
            notify_application_rejected(r)

        instance = self.get_queryset().get(pk=instance.pk)
        return Response(WorkflowStepInstanceSerializer(instance, context={"request": request}).data)

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
        bog'liq bosqich(lar) avtomatik ochiladi. Ish haqi (agar xodim
        biriktirilgan bo'lsa) odatda DARHOL kreditlanadi — firma egasi/
        menejer tasdiqlashini (`approve()`) kutmaydi (avval faqat approve
        kreditlagan, endi "kutilmoqda" summasi usta "Bajardim" bosishi
        bilanoq yangilanadi). ISTISNO: `requires_approval=True` bo'lgan
        (odatda erkin) topshiriqlarda — bu yerda hali kreditlanmaydi,
        status "Bajarildi" bo'lib ko'rinsa ham (frontend `awaiting_approval`
        bayrog'i orqali "Admin tasdig'ini kutmoqda" deb ko'rsatishi kerak) —
        faqat `approve()` chaqirilganda kreditlanadi (docs §4.1)."""
        instance = self.get_object()
        self._check_company_access(instance)
        if instance.status in (StepStatus.COMPLETED, StepStatus.APPROVED):
            raise ValidationError("Bu bosqich allaqachon yakunlangan")
        if instance.status == StepStatus.CANCELLED:
            raise ValidationError("Bu bosqich bekor qilingan")
        if not instance.is_available and instance.status != StepStatus.IN_PROGRESS:
            raise ValidationError("Bu bosqich hali boshlanishi mumkin emas — oldingi bosqichlar tugamagan")
        if instance.photo_requirement == PhotoRequirement.REQUIRED and not request.data.get("image"):
            raise ValidationError("Bu bosqichni yakunlash uchun rasm majburiy")
        if instance.comment_requirement == PhotoRequirement.REQUIRED and not request.data.get("comment"):
            raise ValidationError("Bu bosqichni yakunlash uchun izoh majburiy")

        instance.activate_if_ready()
        serializer = ProgressUpdateSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            serializer.save(step=instance, employee=request.user, is_completion=True)
            instance.status = StepStatus.COMPLETED
            instance.completed_at = timezone.now()
            instance.completed_by = request.user
            instance.save(update_fields=["status", "completed_at", "completed_by", "updated_at"])
            consume_material_on_completion(instance, request.user)
            if instance.employee_id and not instance.requires_approval:
                credit_payroll(instance)

        activated, newly_open = instance.activate_dependents()
        for activated_step in activated:
            if activated_step.employee_id:
                notify_task_available(activated_step)
        for open_step in newly_open:
            notify_pool_open(open_step)
        if instance.order_id:
            sync_order_status_on_step_completion(instance.order)

        instance = self.get_queryset().get(pk=instance.pk)
        return Response(
            WorkflowStepInstanceSerializer(instance, context={"request": request}).data
        )

    @action(detail=True, methods=["post"])
    def approve(self, request, pk=None):
        """Firma egasi/menejer yakunlangan bosqichni tekshirib tasdiqlaydi —
        faqat shu daqiqada xodimning ish haqi (`Payslip`) kreditlanadi
        (usta "Bajardim" bosgani bilanoq emas). Ombordan ayirish esa
        `complete()`da allaqachon sodir bo'lgan."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id or not is_company_owner(request.user, company):
            raise PermissionDenied("Faqat firma egasi/menejer tasdiqlaydi")
        if instance.status != StepStatus.COMPLETED:
            raise ValidationError("Faqat yakunlangan bosqichni tasdiqlash mumkin")

        approve_step_and_credit_payroll(instance, request.user)

        instance = self.get_queryset().get(pk=instance.pk)
        return Response(
            WorkflowStepInstanceSerializer(instance, context={"request": request}).data
        )

    @action(detail=True, methods=["post"])
    def cancel(self, request, pk=None):
        """Firma egasi/menejer bosqichni bekor qiladi — allaqachon ombordan
        ayirilgan material (agar bo'lsa) qaytariladi, kreditlangan ish haqi
        (agar tasdiqlangan edi) chiqarib tashlanadi."""
        instance = self._get_step_or_404(pk)
        company = user_company(request.user)
        if company is None or company.id != instance.company_id or not is_company_owner(request.user, company):
            raise PermissionDenied("Faqat firma egasi/menejer bekor qiladi")

        cancel_step(instance, request.user)

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
            qs = qs.filter(company=company)
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


class WorkflowCapacityView(APIView):
    """Xodimlar bandligi — ishlab chiqarish rejalashtirish uchun: har faol
    xodimning hozirgi navbatida (pending/in_progress) qancha soatlik ish
    borligi. Yangi buyurtma/vazifa tayinlashda kim band, kim bo'sh ekanini
    ko'rish uchun (firma egasi qo'lda rejalashtiradi, tizim taxmin beradi)."""

    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        company = user_company(request.user)
        if company is None:
            if request.user.role == "platform_admin":
                return Response([])
            raise PermissionDenied("Faqat firma a'zolari ishlab chiqarish quvvatini ko'radi")

        from apps.companies.models import Employee

        employees = Employee.objects.filter(
            company=company, is_deleted=False, is_active=True
        ).select_related("user")

        backlog = WorkflowStepInstance.objects.filter(
            is_deleted=False, company=company,
            status__in=[StepStatus.PENDING, StepStatus.IN_PROGRESS],
            employee__isnull=False,
        )

        data = []
        for employee in employees:
            steps = [s for s in backlog if s.employee_id == employee.id]
            pending_hours = sum(float(s.estimated_hours) for s in steps)
            in_progress = sum(1 for s in steps if s.status == StepStatus.IN_PROGRESS)
            data.append({
                "employee": str(employee.id),
                "employee_name": employee.user.first_name or employee.user.email,
                "positions": employee.positions,
                "total_count": len(steps),
                "in_progress_count": in_progress,
                "pending_hours": round(pending_hours, 1),
            })
        data.sort(key=lambda row: -row["pending_hours"])
        return Response(data)
