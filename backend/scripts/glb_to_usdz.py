"""GLB -> USDZ (Blender orqali).

Firma GLB'ni (tekstura bilan) yuklaganda backend buni avtomatik chaqiradi —
kompaniya iOS AR uchun alohida USDZ'ni qo'lda (Reality Converter'da) tayyorlashi
shart emas. Ishlatish:

    blender --background --python scripts/glb_to_usdz.py -- input.glb output.usdz
"""

import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
glb_path, usdz_path = argv

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)
bpy.ops.wm.usd_export(filepath=usdz_path)
print("TAYYOR")
