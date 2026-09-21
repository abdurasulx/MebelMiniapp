"""FBX, OBJ yoki COLLADA (DAE) -> GLB (Blender orqali).

Firma FBX/OBJ/DAE yuklaganda backend buni avtomatik chaqiradi — GLB'ga
qo'lda konvertatsiya qilish shart emas. Ishlatish:

    blender --background --python scripts/to_glb.py -- input.fbx output.glb [texture_dir]

`texture_dir` (ixtiyoriy) — FBX/OBJ/DAE ko'pincha tekstura rasmlariga faqat
*havola* saqlaydi (artistning o'z kompyuteridagi yo'l bilan), haqiqiy rasmlar
esa alohida arxivda keladi. Shu papka berilsa, Blender import qilgandan
so'ng "yo'qolgan" (fayl topilmagan) rasmlarni fayl nomi bo'yicha shu papkadan
qidirib qayta ulaydi.
"""

import shutil
import subprocess
import sys
import tempfile
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
elif ext == ".dae":
    # Blender 4.x/5.x'da COLLADA (.dae) import/eksport butunlay olib
    # tashlangan (eski OpenCOLLADA integratsiyasi endi qo'llab-quvvatlanmaydi).
    # Shuning uchun avval `assimp` (Open Asset Import Library) CLI orqali
    # DAE'ni oraliq GLB'ga aylantiramiz (u node/material nomlarini to'g'ri
    # saqlaydi), keyin shu GLB'ni Blender'ga import qilib davom etamiz —
    # shu bilan pastdagi umumiy tekstura-ulash mantig'i o'zgarishsiz ishlayveradi.
    assimp_bin = shutil.which("assimp")
    if not assimp_bin:
        raise SystemExit("'assimp' topilmadi (brew install assimp) — DAE konvertatsiyasi uchun kerak")
    intermediate = tempfile.NamedTemporaryFile(suffix=".glb", delete=False).name
    result = subprocess.run(
        [assimp_bin, "export", input_path, intermediate],
        capture_output=True, text=True, errors="replace", timeout=120,
    )
    if result.returncode != 0 or not Path(intermediate).exists():
        raise SystemExit(f"assimp DAE->GLB muvaffaqiyatsiz:\n{result.stdout}\n{result.stderr}")
    bpy.ops.import_scene.gltf(filepath=intermediate)
else:
    raise SystemExit(f"Qo'llab-quvvatlanmaydigan manba format: {ext}")

if texture_dir and texture_dir.is_dir():
    # Nom bo'yicha katta-kichik harfga bog'liq bo'lmagan qidiruv jadvali —
    # arxivlar ko'pincha rasmlarni ichki papkalarga solib qo'yadi, shuning
    # uchun rekursiv qidiriladi.
    available = {p.name.lower(): p for p in texture_dir.rglob("*") if p.is_file()}
    relinked = 0
    for image in list(bpy.data.images):
        if image.filepath and Path(bpy.path.abspath(image.filepath)).exists():
            continue  # rasm allaqachon to'g'ri topilgan
        # MTL fayllar ko'pincha Windows'da eksport qilingani uchun teskari
        # slesh (\) bilan yo'l saqlaydi — POSIX'da pathlib buni ajratmaydi
        # (backslash oddiy belgi hisoblanadi), shuning uchun asl nom
        # qo'lda, ikkala ajratuvchi bo'yicha ham olinadi.
        raw_name = image.filepath or image.name
        basename = raw_name.replace("\\", "/").rsplit("/", 1)[-1]
        match = available.get(basename.lower())
        if match:
            # Mavjud (yuklanmagan) rasmning `filepath`ini o'zgartirib `reload()`
            # qilish Blender 4.0'da rasm piksellarini eksportchiga yetkazmaydi
            # (GLB'da rasmlar 0 ta chiqadi) — shuning uchun rasm yangidan
            # yuklanib, shu rasmni ishlatgan barcha tekstura tugunlariga
            # qayta biriktiriladi.
            try:
                new_image = bpy.data.images.load(str(match), check_existing=False)
                new_image.colorspace_settings.name = image.colorspace_settings.name
                for mat in bpy.data.materials:
                    if not mat.use_nodes:
                        continue
                    for node in mat.node_tree.nodes:
                        if node.type == "TEX_IMAGE" and node.image == image:
                            node.image = new_image
                old_name = image.name
                bpy.data.images.remove(image)
                new_image.name = old_name
                relinked += 1
            except Exception as e:
                print(f"Rasmni qayta yuklashda xato ({match.name}): {e}")
    print(f"Qayta ulangan rasmlar: {relinked}/{len(bpy.data.images)}")

# `export_apply=True` (modifikatorlarni eksportdan oldin qo'llash) Blender
# glTF eksportchisining hujjatlashtirilgan cheklovi bor: shape key'lari
# (masalan eshik/tortma ochilish animatsiyasi ko'pincha shape key orqali
# qilinadi) mavjud bo'lsa, ular JIMGINA eksportdan chiqarib tashlanadi —
# animatsiya modelga "ko'rinmasdan" yo'qolib qolardi. Shuning uchun bu
# yerda avval sahnada animatsiya (action yoki shape key) bor-yo'qligi
# tekshiriladi va bo'lsa `export_apply` o'chiriladi (faqat static
# modellarda modifikatorlarni oldindan qo'llash davom etadi).
has_animation = bool(bpy.data.actions) or any(
    getattr(obj.data, "shape_keys", None)
    for obj in bpy.data.objects
    if obj.type == "MESH" and obj.data is not None
)
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    export_apply=not has_animation,
    export_animations=True,
)
animation_label = "bor" if has_animation else "yo'q"
print(f"TAYYOR (animatsiya: {animation_label})")
