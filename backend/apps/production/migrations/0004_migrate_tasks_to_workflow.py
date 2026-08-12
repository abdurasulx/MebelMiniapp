from django.db import migrations

STATUS_MAP = {"todo": "pending", "in_progress": "in_progress", "done": "completed"}


def migrate_tasks(apps, schema_editor):
    ProductionTask = apps.get_model("production", "ProductionTask")
    WorkflowStepInstance = apps.get_model("workflow", "WorkflowStepInstance")
    Employee = apps.get_model("companies", "Employee")

    for task in ProductionTask.objects.all():
        employee = None
        if task.assigned_to_id:
            employee = Employee.objects.filter(
                company_id=task.company_id, user_id=task.assigned_to_id
            ).first()

        WorkflowStepInstance.objects.create(
            company_id=task.company_id,
            order_id=task.order_id,
            template_step=None,
            name=task.title,
            description=task.description,
            stage=task.stage,
            role="",
            employee=employee,
            estimated_hours=1,
            cost=0,
            required_materials="",
            photo_requirement="optional",
            status=STATUS_MAP.get(task.status, "pending"),
            deadline=task.deadline,
            completed_at=task.completed_at,
            is_deleted=task.is_deleted,
            created_at=task.created_at,
            updated_at=task.updated_at,
        )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("production", "0003_payslip_workflow_earnings"),
        ("workflow", "0003_backfill_instance_company"),
    ]

    operations = [
        migrations.RunPython(migrate_tasks, noop),
    ]
