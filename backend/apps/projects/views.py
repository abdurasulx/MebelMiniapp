from django.db.models import Q
from django.utils import timezone
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.companies.views import user_company

from .models import DetailAsset, Project, ProjectItem
from .serializers import DetailAssetSerializer, ProjectItemSerializer, ProjectSerializer


class DetailAssetViewSet(viewsets.ModelViewSet):
    """Umumiy dekorativ elementlar kutubxonasi — platforma standartlari
    (`company=None`) hammaga ko'rinadi, firma o'zinikini qo'shishi mumkin va
    faqat o'zi (undan foydalanuvchi mijozlar bilan birga) ko'radi."""

    serializer_class = DetailAssetSerializer
    permission_classes = (permissions.IsAuthenticatedOrReadOnly,)

    def get_queryset(self):
        qs = DetailAsset.objects.filter(is_deleted=False).select_related("company")
        user = self.request.user
        company = user_company(user) if user.is_authenticated else None
        if company:
            qs = qs.filter(Q(company__isnull=True) | Q(company=company))
        else:
            qs = qs.filter(company__isnull=True)
        category = self.request.query_params.get("category")
        if category:
            qs = qs.filter(category=category)
        return qs

    def perform_create(self, serializer):
        user = self.request.user
        if user.role == "platform_admin" and str(self.request.data.get("public")).lower() == "true":
            serializer.save(company=None)
            return
        company = user_company(user)
        if company is None:
            raise PermissionDenied("Avval kompaniya yarating yoki xodim bo'ling")
        serializer.save(company=company)

    def _check_owner(self, instance):
        user = self.request.user
        if instance.company_id is None:
            if user.role != "platform_admin":
                raise PermissionDenied("Standart elementni faqat platforma admini boshqaradi")
            return
        company = user_company(user)
        if company is None or company.id != instance.company_id:
            raise PermissionDenied("Bu element sizniki emas")

    def perform_update(self, serializer):
        self._check_owner(serializer.instance)
        serializer.save()

    def perform_destroy(self, instance):
        self._check_owner(instance)
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ProjectViewSet(viewsets.ModelViewSet):
    """Mijozning shaxsiy loyihalari — faqat egasi ko'radi/boshqaradi.

    Loyiha yaratish faqat xaridor (customer) uchun — firma egasi/xodimi
    o'z nomidan "xona loyihasi" yaratmaydi (bu mijoz tomonidagi funksiya;
    firma tomonidagi "loyiha mahsuloti" alohida — oddiy Product + Model3D
    orqali, ko'rinuvchanlik/ulashish shu joyda allaqachon bor)."""

    serializer_class = ProjectSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return Project.objects.filter(
            customer=self.request.user, is_deleted=False
        ).prefetch_related("items__product__model3d", "items__variant", "items__detail_asset")

    def perform_create(self, serializer):
        if self.request.user.role != "customer":
            raise PermissionDenied("Loyiha faqat xaridor hisobida yaratiladi")
        serializer.save(customer=self.request.user)

    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])

    @action(detail=True, methods=["post"])
    def pay(self, request, pk=None):
        """Dev rejim: haqiqiy to'lov integratsiyasi hali yo'q — shu action
        loyihani "to'landi" deb belgilaydi (keyinchalik Payme/Click webhook
        shu joyni almashtiradi, front tomoni o'zgarmaydi)."""
        project = self.get_object()
        project.is_paid = True
        project.paid_at = timezone.now()
        project.save(update_fields=["is_paid", "paid_at"])
        return Response(ProjectSerializer(project, context={"request": request}).data)


class ProjectItemViewSet(viewsets.ModelViewSet):
    """Loyiha ichidagi joylashtirilgan obyektlar — faqat to'lov qilingan
    loyihada joylashtirish/harakatlantirish mumkin."""

    serializer_class = ProjectItemSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def _get_project(self):
        try:
            project = Project.objects.get(pk=self.kwargs["project_pk"], is_deleted=False)
        except Project.DoesNotExist:
            raise NotFound("Loyiha topilmadi")
        if project.customer_id != self.request.user.id:
            raise PermissionDenied("Bu loyiha sizniki emas")
        return project

    def get_queryset(self):
        return ProjectItem.objects.filter(
            project_id=self.kwargs["project_pk"], is_deleted=False
        ).select_related("product__model3d", "variant", "detail_asset")

    def perform_create(self, serializer):
        project = self._get_project()
        if not project.is_paid:
            raise ValidationError("Avval loyiha uchun to'lovni amalga oshiring")
        serializer.save(project=project)

    def perform_update(self, serializer):
        project = self._get_project()
        if not project.is_paid:
            raise ValidationError("Avval loyiha uchun to'lovni amalga oshiring")
        serializer.save()

    def perform_destroy(self, instance):
        self._get_project()
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])


class ProjectViewerView(APIView):
    """Mustaqil ulashish havolasi: `/viewer/project/<share_token>/` — Model3D
    bilan bir xil naqsh (bazissoft.ru uslubi)."""

    permission_classes = (permissions.AllowAny,)

    def get(self, request, token):
        try:
            project = Project.objects.prefetch_related(
                "items__product__model3d", "items__variant", "items__detail_asset"
            ).get(share_token=token, is_deleted=False)
        except Project.DoesNotExist:
            raise NotFound("Havola topilmadi")
        if not project.is_public and (
            not request.user.is_authenticated or request.user.id != project.customer_id
        ):
            return Response(
                {
                    "detail": "Bu loyihani ko'rish huquqingiz yo'q.",
                    "requires_login": not request.user.is_authenticated,
                },
                status=403,
            )
        return Response(ProjectSerializer(project, context={"request": request}).data)
