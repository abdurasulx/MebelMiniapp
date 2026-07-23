from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.companies.views import user_company

from .models import Lead, Note
from .serializers import LeadSerializer, NoteSerializer


class LeadViewSet(viewsets.ModelViewSet):
    """Firma tomoni: o'z kompaniyasi leadlarini boshqaradi. Admin hammasini ko'radi."""

    serializer_class = LeadSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        qs = Lead.objects.filter(is_deleted=False).select_related(
            "assigned_to", "customer"
        ).prefetch_related("notes")
        user = self.request.user
        if user.role == "platform_admin":
            return qs
        company = user_company(user)
        if company is None:
            raise PermissionDenied("Faqat kompaniya a'zolari leadlarni ko'radi")
        return qs.filter(company=company)

    def perform_create(self, serializer):
        company = user_company(self.request.user)
        if company is None:
            raise PermissionDenied("Faqat kompaniya a'zolari lead yarata oladi")
        serializer.save(company=company)

    def perform_update(self, serializer):
        company = user_company(self.request.user)
        if company is None or serializer.instance.company_id != company.id:
            raise PermissionDenied("Bu lead sizniki emas")
        serializer.save()

    def perform_destroy(self, instance):
        company = user_company(self.request.user)
        if company is None or instance.company_id != company.id:
            raise PermissionDenied("Bu lead sizniki emas")
        instance.is_deleted = True
        instance.save(update_fields=["is_deleted"])

    @action(detail=True, methods=["post"])
    def add_note(self, request, pk=None):
        lead = self.get_object()
        kind = request.data.get("kind", Note.Kind.NOTE)
        text = request.data.get("text", "").strip()
        if not text:
            raise ValidationError("Izoh matni bo'sh bo'lmasin")
        Note.objects.create(lead=lead, author=request.user, kind=kind, text=text)
        return Response(LeadSerializer(lead, context={"request": request}).data)
