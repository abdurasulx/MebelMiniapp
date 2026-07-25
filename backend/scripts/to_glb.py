"""FBX yoki OBJ -> GLB (Blender orqali).

Firma FBX/OBJ yuklaganda backend buni avtomatik chaqiradi — GLB'ga qo'lda
konvertatsiya qilish shart emas. Ishlatish:

    blender --background --python scripts/to_glb.py -- input.fbx output.glb [texture_dir]

`texture_dir` (ixtiyoriy) — FBX/OBJ ko'pincha tekstura rasmlariga faqat
*havola* saqlaydi (artistning o'z kompyuteridagi yo'l bilan), haqiqiy rasmlar
esa alohida arxivda keladi. Shu papka berilsa, Blender import qilgandan
so'ng "yo'qolgan" (fayl topilmagan) rasmlarni fayl nomi bo'yicha shu papkadan
qidirib qayta ulaydi.
"""

import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
input_path, glb_path = argv[0], argv[1]
texture_dir = Path(argv[2]) if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)

ext = Path(input_path).suffix.lower()
if ext == ".fbx":
    bpy.ops.import_scene.fbx(filepath=input_path)
elif ext == ".obj":
    bpy.ops.wm.obj_import(filepath=input_path)
else:
    raise SystemExit(f"Qo'llab-quvvatlanmaydigan manba format: {ext}")

if texture_dir and texture_dir.is_dir():
    # Nom bo'yicha katta-kichik harfga bog'liq bo'lmagan qidiruv jadvali —
    # arxivlar ko'pincha rasmlarni ichki papkalarga solib qo'yadi, shuning
    # uchun rekursiv qidiriladi.
    available = {p.name.lower(): p for p in texture_dir.rglob("*") if p.is_file()}
    relinked = 0
    for image in bpy.data.images:
        if image.filepath and Path(bpy.path.abspath(image.filepath)).exists():
            continue  # rasm allaqachon to'g'ri topilgan
        match = available.get(Path(image.filepath or image.name).name.lower())
        if match:
            image.filepath = str(match)
            try:
                image.reload()
                relinked += 1
            except Exception as e:
                print(f"Rasmni qayta yuklashda xato ({match.name}): {e}")
    print(f"Qayta ulangan rasmlar: {relinked}/{len(bpy.data.images)}")

bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True)
print("TAYYOR")
