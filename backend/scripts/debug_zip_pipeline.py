"""Zip/rar'dagi OBJ/FBX modelni haqiqiy process_model3d oqimi bilan (DB'ga
yozmasdan) qayta ishlab, natija GLB/USDZ'dagi teksturalarni ko'rsatadi.

    ZIP=/to'liq/yo'l/model.zip python manage.py shell < scripts/debug_zip_pipeline.py
"""

import json
import os
import shutil
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path

from apps.assets.management.commands.process_model3d import SCRIPTS_DIR, Command

zip_path = Path(os.environ["ZIP"])
blender = shutil.which("blender")
cmd = Command()


def run(script, args):
    r = subprocess.run(
        [blender, "--background", "--python", str(SCRIPTS_DIR / script), "--", *map(str, args)],
        capture_output=True, text=True, errors="replace", timeout=300,
    )
    print(f"--- {script} (kod {r.returncode}) ---")
    print(r.stdout[-2500:])
    if r.stderr.strip():
        print("STDERR:", r.stderr[-1500:])
    return r.returncode == 0


def glb_report(path):
    d = Path(path).read_bytes()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    mats = j.get("materials", [])
    print(f"GLB: rasmlar={len(j.get('images', []))} teksturalar={len(j.get('textures', []))} materiallar={len(mats)}")
    for m in mats:
        pbr = m.get("pbrMetallicRoughness", {})
        print("  material:", m.get("name"), "| baseColorTexture:", "baseColorTexture" in pbr,
              "| baseColorFactor:", pbr.get("baseColorFactor"))


with tempfile.TemporaryDirectory() as tmp:
    extract_dir = Path(tmp) / "source_archive"
    extract_dir.mkdir()
    print("Arxiv ochildi:", cmd._extract_archive(zip_path, extract_dir))
    found = cmd._find_model_file(extract_dir)
    print("Model fayli:", found)

    source = found
    if found.suffix.lower() == ".obj":
        work = Path(tmp) / "obj_source"
        work.mkdir()
        source = cmd._prepare_obj_source(found, extract_dir, work)
        print("OBJ manbasi:", source)
        for line in Path(source).read_bytes().split(b"\n")[:8]:
            print("   obj>", line[:100])
        mtl = next(iter(work.glob("*.mtl")), None)
        if mtl:
            print("MTL mazmuni:")
            print(mtl.read_text(errors="replace"))

    glb = Path(tmp) / "out.glb"
    if found.suffix.lower() in (".fbx", ".obj", ".dae"):
        ok = run("to_glb.py", [source, glb, extract_dir])
        if ok and glb.exists():
            glb_report(glb)
    else:
        glb = found
        glb_report(glb)

    usdz = Path(tmp) / "out.usdz"
    if glb.exists() and run("glb_to_usdz.py", [glb, usdz]) and usdz.exists():
        print("USDZ ichida:", zipfile.ZipFile(usdz).namelist())
