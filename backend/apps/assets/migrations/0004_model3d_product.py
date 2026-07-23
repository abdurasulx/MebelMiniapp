import django.db.models.deletion
from django.db import migrations, models


def move_to_product(apps, schema_editor):
    """Har mahsulot uchun bitta Model3D qoldiramiz (birinchi variantniki, name
    bo'yicha tartiblangan) — geometriya endi mahsulot darajasida bitta marta
    saqlanadi, boshqa variantlar ustidagi qo'shimcha modellar o'chiriladi
    (rang farqini endi Variant.color_hex/texture bilan runtime'da beramiz)."""
    Model3D = apps.get_model("assets", "Model3D")
    Product = apps.get_model("products", "Product")
    for product in Product.objects.all():
        models_qs = Model3D.objects.filter(variant__product=product).order_by(
            "variant__name", "created_at"
        )
        canonical = models_qs.first()
        if canonical is None:
            continue
        canonical.product = product
        canonical.save(update_fields=["product"])
        models_qs.exclude(pk=canonical.pk).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("assets", "0003_model3d_sharing"),
        ("products", "0003_variant_color_texture"),
    ]

    operations = [
        migrations.AddField(
            model_name="model3d",
            name="product",
            field=models.OneToOneField(
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name="model3d",
                to="products.product",
            ),
        ),
        migrations.RunPython(move_to_product, migrations.RunPython.noop),
        migrations.RemoveField(model_name="model3d", name="variant"),
        migrations.AlterField(
            model_name="model3d",
            name="product",
            field=models.OneToOneField(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="model3d",
                to="products.product",
            ),
        ),
    ]
