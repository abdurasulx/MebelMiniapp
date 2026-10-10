"""GLB tayyor bo'lganda (yoki almashganda) mahsulot rasmlarini render navbatiga qo'yadi."""


def enqueue_render_on_model_save(sender, instance, **kwargs):
    if instance.product_id is None or not instance.glb_file:
        return
    if not instance.glb_file.name.lower().endswith(".glb"):
        return  # FBX/OBJ/ZIP — konvertatsiya GLB yozgach yana save() bo'ladi
    from apps.products.rendering.runner import enqueue

    enqueue(instance.product)  # o'zgarmagan GLB uchun enqueue o'zi e'tibor bermaydi
