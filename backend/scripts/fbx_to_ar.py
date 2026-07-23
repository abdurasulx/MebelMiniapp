"""FBX (yoki OBJ/DAE — Blender import qila oladigan format) -> GLB + USDZ.

Ishlatish (Blender o'rnatilgan bo'lishi kerak: brew install --cask blender):
    blender --background --python scripts/fbx_to_ar.py -- input.fbx output.glb output.usdz

Natijadagi GLB/USDZ fayllar keyin firma panelidan (Mahsulotlar > variant > 🧊 3D)
yoki to'g'ridan-to'g'ri /api/v1/models3d/ ga multipart POST bilan yuklanadi.
"""

import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
fbx_path, glb_path, usdz_path = argv

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx_path)

bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True)
print(f"GLB yozildi: {glb_path}")

try:
    bpy.ops.wm.usd_export(filepath=usdz_path)
    print(f"USDZ yozildi: {usdz_path}")
except Exception as e:
    print(f"USDZ eksport xatosi: {e}")

print("TAYYOR")
