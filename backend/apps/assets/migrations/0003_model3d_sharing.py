import uuid

from django.db import migrations, models


def assign_unique_tokens(apps, schema_editor):
    Model3D = apps.get_model("assets", "Model3D")
    for m in Model3D.objects.all():
        m.share_token = uuid.uuid4()
        m.save(update_fields=["share_token"])


class Migration(migrations.Migration):

    dependencies = [
        ("assets", "0002_model3d_variant"),
    ]

    operations = [
        migrations.AddField(
            model_name="model3d",
            name="share_token",
            field=models.UUIDField(default=uuid.uuid4, editable=False, null=True),
        ),
        migrations.RunPython(assign_unique_tokens, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="model3d",
            name="share_token",
            field=models.UUIDField(default=uuid.uuid4, editable=False, unique=True),
        ),
        migrations.AddField(
            model_name="model3d",
            name="visibility",
            field=models.CharField(
                choices=[
                    ("private", "Yopiq (faqat firma a'zolari)"),
                    ("restricted", "Cheklangan (faqat ro'yxatdagi shaxslar)"),
                    ("public", "Ochiq (havola bilan hamma)"),
                ],
                default="private",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="model3d",
            name="allowed_emails",
            field=models.JSONField(blank=True, default=list),
        ),
    ]
