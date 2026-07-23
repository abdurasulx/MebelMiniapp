from rest_framework import serializers

from .models import Lead, Note


class NoteSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    kind_display = serializers.CharField(source="get_kind_display", read_only=True)

    class Meta:
        model = Note
        fields = ("id", "kind", "kind_display", "text", "author_name", "created_at")
        read_only_fields = ("id", "author_name", "created_at")

    def get_author_name(self, obj):
        if obj.author is None:
            return None
        return obj.author.first_name or obj.author.email


class LeadSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    source_display = serializers.CharField(source="get_source_display", read_only=True)
    assigned_to_name = serializers.SerializerMethodField()
    notes = NoteSerializer(many=True, read_only=True)
    notes_count = serializers.IntegerField(source="notes.count", read_only=True)

    class Meta:
        model = Lead
        fields = (
            "id", "company", "customer", "name", "phone", "interested_product", "budget",
            "source", "source_display", "status", "status_display",
            "assigned_to", "assigned_to_name", "notes", "notes_count",
            "created_at", "updated_at",
        )
        read_only_fields = ("id", "company", "created_at", "updated_at")

    def get_assigned_to_name(self, obj):
        if obj.assigned_to is None:
            return None
        return obj.assigned_to.first_name or obj.assigned_to.email
