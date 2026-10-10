"""GLB tayyor bo'lganda (yoki almashganda) mahsulot rasmlarini render navbatiga qo'yadi.
Mahsulot darajasidagi ham, variant darajasidagi (`Model3D.variant`) model ham hisobga olinadi."""


def enqueue_render_on_model_save(sender, instance, **kwargs):
    if not instance.glb_file or not instance.glb_file.name.lower().endswith(".glb"):
        return  # FBX/OBJ/ZIP — konvertatsiya GLB yozgach yana save() bo'ladi
    if instance.product_id is not None:
        product = instance.product
    elif instance.variant_id is not None:
        product = instance.variant.product
    else:
        return  # dizayn versiyasi modeli — mahsulot rasmiga aloqasi yo'q
    from apps.products.rendering.runner import enqueue

    enqueue(product)  # o'zgarmagan GLB'lar uchun enqueue o'zi e'tibor bermaydi
