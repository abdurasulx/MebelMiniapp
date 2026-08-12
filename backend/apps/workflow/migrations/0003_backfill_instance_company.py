from django.db import migrations


def backfill_company(apps, schema_editor):
    WorkflowStepInstance = apps.get_model("workflow", "WorkflowStepInstance")
    for instance in WorkflowStepInstance.objects.filter(
        company__isnull=True, order__isnull=False
    ).select_related("order"):
        instance.company_id = instance.order.company_id
        instance.save(update_fields=["company"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("workflow", "0002_workflowstepinstance_company_and_more"),
    ]

    operations = [
        migrations.RunPython(backfill_company, noop),
    ]
