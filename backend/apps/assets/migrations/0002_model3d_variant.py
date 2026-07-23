import django.db.models.deletion
from django.db import migrations, models


def move_to_first_variant(apps, schema_editor):
    Model3D = apps.get_model("assets", "Model3D")
    for m in Model3D.objects.all():
        variant = m.product.variants.order_by("name").first() if m.product_id else None
        if variant is None:
            m.delete()
            continue
        m.variant = variant
        m.save(update_fields=["variant"])


class Migration(migrations.Migration):

    dependencies = [
        ("assets", "0001_initial"),
        ("products", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="model3d",
            name="variant",
            field=models.OneToOneField(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="model3d",
                to="products.variant",
            ),
        ),
        migrations.RunPython(move_to_first_variant, migrations.RunPython.noop),
        migrations.RemoveField(model_name="model3d", name="product"),
        migrations.AlterField(
            model_name="model3d",
            name="variant",
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="model3d",
                to="products.variant",
            ),
        ),
    ]
