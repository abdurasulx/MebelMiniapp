from django.contrib import admin

from .models import ProgressUpdate, StepApplication, WorkflowStep, WorkflowStepInstance


@admin.register(WorkflowStep)
class WorkflowStepAdmin(admin.ModelAdmin):
    list_display = ("product", "order_index", "name", "role", "cost")
    list_filter = ("role",)


@admin.register(WorkflowStepInstance)
class WorkflowStepInstanceAdmin(admin.ModelAdmin):
    list_display = ("order", "order_index", "name", "status", "cost")
    list_filter = ("status",)


@admin.register(ProgressUpdate)
class ProgressUpdateAdmin(admin.ModelAdmin):
    list_display = ("step", "employee", "is_completion", "created_at")


@admin.register(StepApplication)
class StepApplicationAdmin(admin.ModelAdmin):
    list_display = ("step", "employee", "status", "created_at", "decided_at")
    list_filter = ("status",)
