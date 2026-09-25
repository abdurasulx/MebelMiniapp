"""GLB'ni bir tekis (uniform) koeffitsientga kichraytirish/kattalashtirish
(Blender orqali) — noto'g'ri birlikda (masalan millimetrda, metr deb
eksport qilingan) modelni to'g'irlash uchun. Ishlatish:

    blender --background --python scripts/rescale_glb.py -- input.glb output.glb 0.001
"""

import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
glb_path, out_path, factor_str = argv
factor = float(factor_str)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.transform.resize(value=(factor, factor, factor))
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

has_animation = bool(bpy.data.actions) or any(
    getattr(obj.data, "shape_keys", None)
    for obj in bpy.data.objects
    if obj.type == "MESH" and obj.data is not None
)
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    export_apply=not has_animation,
    export_animations=True,
)
print("TAYYOR")
