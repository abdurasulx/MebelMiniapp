from django.contrib import admin

from .models import Lead, Note


class NoteInline(admin.TabularInline):
    model = Note
    extra = 0


@admin.register(Lead)
class LeadAdmin(admin.ModelAdmin):
    list_display = ("name", "company", "status", "assigned_to", "created_at")
    list_filter = ("status", "source")
    inlines = (NoteInline,)
