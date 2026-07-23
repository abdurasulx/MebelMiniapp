import common.models
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("products", "0002_category_storage_mode_product_storage_mode_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="variant",
            name="color_hex",
            field=models.CharField(blank=True, max_length=7),
        ),
        migrations.AddField(
            model_name="variant",
            name="texture",
            field=models.ImageField(blank=True, null=True, upload_to="variants/textures/"),
        ),
        migrations.AddField(
            model_name="variant",
            name="storage_mode",
            field=models.CharField(
                default=common.models.current_storage_mode,
                editable=False,
                max_length=20,
            ),
        ),
    ]
