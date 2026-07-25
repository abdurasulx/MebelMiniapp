"""FBX yoki OBJ -> GLB (Blender orqali).

Firma FBX/OBJ yuklaganda backend buni avtomatik chaqiradi — GLB'ga qo'lda
konvertatsiya qilish shart emas. Ishlatish:

    blender --background --python scripts/to_glb.py -- input.fbx output.glb
"""

import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
input_path, glb_path = argv

bpy.ops.wm.read_factory_settings(use_empty=True)

ext = Path(input_path).suffix.lower()
if ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=input_path)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=input_path)
else:
    raise SystemExit(f"Qo'llab-quvvatlanmaydigan manba format: {ext}")

bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True)
print("TAYYOR")
