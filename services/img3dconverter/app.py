import gc
import io
import json
import math
from pathlib import Path
import queue
import uuid
import shutil
import os
import re
import subprocess
import sys
import tempfile
import threading
import time
import traceback

BASE = os.path.dirname(os.path.abspath(__file__))
HY = os.path.join(BASE, "Hunyuan3D-2.1")
os.chdir(HY)
sys.path.insert(0, HY)
sys.path.insert(0, os.path.join(HY, "hy3dshape"))
sys.path.insert(0, os.path.join(HY, "hy3dpaint"))

import types

os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")

# bpy (Blender) faqat OBJ->GLB uchun kerak; GLB ni pygltflib bilan o'zimiz yasaymiz
sys.modules.setdefault("bpy", types.ModuleType("bpy"))

import numpy as np
import torch
from flask import Flask, jsonify, render_template_string, request, send_from_directory
from PIL import Image, ImageOps
import furniture_ai
import product_quality
from input_policy import image_roles

try:
    from torchvision_fix import apply_fix

    apply_fix()
except Exception as e:
    print("torchvision fix qo'llanmadi:", e)

from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
from foreground import ForegroundExtractor
from estimate_height import estimate as estimate_height
from scale_model import scale_glb
from hy3dpaint.convert_utils import create_glb_with_pbr_materials
from textureGenPipeline import Hunyuan3DPaintConfig, Hunyuan3DPaintPipeline

OUT_DIR = os.path.join(BASE, "3dfiles")
os.makedirs(OUT_DIR, exist_ok=True)

shape_pipe = None  # Load only the model required by this job.
rembg = ForegroundExtractor()
mv_pipe = None  # ko'p rasmli model: birinchi ishlatilganda yuklanadi, bo'sh turganda CPU da
ROLES = ["front", "back", "left", "right"]
paint_pipe = None  # 12 GB VRAM ga sig'ishi uchun kerak bo'lganda yuklanadi
lock = threading.Lock()


def get_mv_pipe():
    global mv_pipe
    if mv_pipe is None:
        # 2mv modeli Hunyuan3D 2.0 arxitekturasida: hy3dgen paketi kerak (2.1 uni yuklay olmaydi)
        sys.path.append(os.path.join(BASE, "Hunyuan3D-2"))
        from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline as MVPipeline

        mv_pipe = MVPipeline.from_pretrained(
            "tencent/Hunyuan3D-2mv", subfolder="hunyuan3d-dit-v2-mv", device="cpu"
        )
    return mv_pipe


class CpuWhenIdle:
    """DINOv2 har ishda bir marta ishlaydi: faqat chaqirilganda GPU da turadi (~2 GB tejaydi)."""

    def __init__(self, module):
        self.m = module.to("cpu")

    def __call__(self, *a, **k):
        self.m.to("cuda")
        try:
            return self.m(*a, **k)
        finally:
            self.m.to("cpu")
            torch.cuda.empty_cache()


def get_paint_pipe(cfg):
    global paint_pipe
    if paint_pipe is None:
        conf = Hunyuan3DPaintConfig(cfg["texture_views"], cfg["texture_resolution"])
        conf.texture_size = cfg["texture_size"]
        conf.realesrgan_ckpt_path = "hy3dpaint/ckpt/RealESRGAN_x4plus.pth"
        conf.multiview_cfg_path = "hy3dpaint/cfgs/hunyuan-paint-pbr.yaml"
        conf.custom_pipeline = "hy3dpaint/hunyuanpaintpbr"
        paint_pipe = Hunyuan3DPaintPipeline(conf)
        mv = paint_pipe.models["multiview_model"]
        if hasattr(mv, "dino_v2"):
            mv.dino_v2 = CpuWhenIdle(mv.dino_v2)
        free_gpu()
    return paint_pipe


def unload_paint_pipe():
    global paint_pipe
    paint_pipe = None
    free_gpu()


def free_gpu():
    gc.collect()
    torch.cuda.empty_cache()


app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024 * 1024
OWNER = os.environ.get("APP_OWNER", "abdurasulx1@gmail.com")


@app.before_request
def tailscale_guard():
    """Faqat tailscale tarmog'idan va faqat egasidan (devchat bilan bir xil tekshiruv)."""
    ip = request.remote_addr or ""
    if not re.fullmatch(r"100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.\d+\.\d+", ip):
        return "Faqat tailscale", 403
    try:
        out = subprocess.run(["tailscale", "whois", ip], capture_output=True, text=True, timeout=5).stdout
        m = re.search(r"User:\s*\n\s*Name:\s*(\S+)", out)
        if not m or m.group(1) != OWNER:
            return "Ruxsat yo'q", 403
    except Exception:
        return "Tekshirib bo'lmadi", 403


def safe(name):
    name = re.sub(r"[^\w\- ]", "", name, flags=re.UNICODE).strip().replace(" ", "_")
    return name[:60]


def collections():
    return sorted(
        d for d in os.listdir(OUT_DIR) if os.path.isdir(os.path.join(OUT_DIR, d))
    )


@app.get("/")
def index():
    return render_template_string(PAGE, ai_enabled=furniture_ai.enabled())


@app.get("/api/collections")
def api_collections():
    return jsonify(collections())


@app.get("/files/<path:p>")
def files(p):
    return send_from_directory(OUT_DIR, p)


JOBS = product_quality.load_completed()
WAITING = []  # navbatdagi ish id'lari (tartib bilan)
JOBS_LOCK = threading.Lock()
JOB_QUEUE = queue.Queue()
EST = {"mesh": 30.0, "texture": 480.0}  # kutilgan davomiylik (soniya), ishdan keyin yangilanadi


def set_stage(job, stage, lo, hi, expected=None, frac=None):
    job.update(stage=stage, lo=lo, hi=hi, expected=expected, frac=frac, t0=time.time())


def percent(job):
    if job["status"] == "done":
        return 100
    if job["status"] != "running":
        return 0
    lo, hi = job["lo"], job["hi"]
    if job["frac"] is not None:
        f = job["frac"]
    elif job["expected"]:
        f = min(0.95, (time.time() - job["t0"]) / job["expected"])
    else:
        f = 0
    value = int(lo + (hi - lo) * f)
    job["last_percent"] = max(job.get("last_percent", 0), min(99, value))
    return job["last_percent"]


def public(job):
    with JOBS_LOCK:
        pos = WAITING.index(job["id"]) + 1 if job["id"] in WAITING else 0
    return dict(
        id=job["id"],
        name=job["name"],
        collection=job["collection"],
        status=job["status"],
        stage=job["stage"],
        percent=percent(job),
        position=pos,
        textured=job["textured"],
        n_images=job["n_images"],
        error=job["error"],
        result=job["result"],
        ai_analysis=job.get("ai_analysis"),
        reconstruction_scope=job.get("reconstruction_scope", "single"),
    )


def process(job):
    global shape_pipe, mv_pipe
    collection, name = job["collection"], job["name"]
    textured = job["textured"]
    folder = os.path.join(OUT_DIR, collection)
    os.makedirs(folder, exist_ok=True)
    fname = f"{name}.glb"
    if os.path.exists(os.path.join(folder, fname)):
        fname = f"{name}_{int(time.time())}.glb"
    out_path = os.path.join(folder, fname)
    note = ""
    try:
        cfg = product_quality.settings()
    except Exception as exc:
        job.update(status="error", error="Product configuration error: " + str(exc), images=None)
        product_quality.save_completed(JOBS)
        return
    workspace = Path(job["input_dir"])
    quality = {"profile": cfg, "status": "needs_review", "legacy_ground_cut": False, "paint_remesh": False}
    multi = len(job["images"]) > 1
    quality["shape_model"] = "tencent/Hunyuan3D-2mv" if multi else "tencent/Hunyuan3D-2.1"
    lo_shape, hi_shape = (4, 34) if textured else (6, 70)
    if multi:
        lo_shape += 4  # ko'p rasmli modelni yuklash uchun joy
    steps = cfg["shape_steps"]

    def on_step(i, t, outputs):
        job["frac"] = min(1.0, (i + 1) / steps)
        if i + 1 >= steps:
            lo, hi = (hi_shape, 42) if textured else (hi_shape, 96)
            set_stage(job, "Mesh tayyorlanmoqda", lo, hi, expected=EST["mesh"])

    with tempfile.TemporaryDirectory() as tmp:
        try:
            imgs = {}
            loaded = [(role, ImageOps.exif_transpose(Image.open(io.BytesIO(data))).convert("RGBA"))
                      for role, data in job["images"]]
            if job.get("ai_prepare"):
                set_stage(job, "AI mebelni aniqlamoqda va o‘lchamlarni tavsiya qilmoqda", 0, 3, expected=30)
                loaded, analysis = furniture_ai.analyze_and_prepare(loaded, {
                    "height": job.get("height_cm"), "width": job.get("width_cm"), "depth": job.get("depth_cm")},
                    reconstruction_scope=job.get("reconstruction_scope", "single"))
                job["ai_analysis"] = analysis
                for axis in ("height", "width", "depth"):
                    if not job.get(axis + "_cm"):
                        job[axis + "_cm"] = analysis["effective_dimensions_cm"][axis]
                workspace = Path(job["input_dir"])
                for role, prepared in loaded:
                    prepared.save(workspace / (role + "-prepared.png"))
                (workspace / "analysis.json").write_text(json.dumps(analysis, ensure_ascii=False), encoding="utf-8")
                note = "AI: " + analysis["object_type"]
                if analysis["dimension_sources"]["height"] == "ai_estimate":
                    note += f"; bo‘yi {job['height_cm']} sm — AI taxmini, aniq o‘lchov emas"
                if analysis["warnings"]:
                    note += "; " + "; ".join(analysis["warnings"])
            if job["remove_bg"]:
                set_stage(job, "Orqa fon olib tashlanmoqda", 0, lo_shape - (4 if multi else 0), expected=8 * len(job["images"]))
            try:
                for role, im in loaded:
                    has_alpha = im.getchannel("A").getextrema()[0] < 255
                    imgs[role] = rembg(im, model=cfg.get("background_model", "u2net")) if job["remove_bg"] and not has_alpha else im
                    imgs[role].save(workspace / (role + "-mask.png"))
            finally:
                # Foreground ONNX arenas must not compete with the paint model.
                rembg.release()
            img = imgs["front"]
            img_path = os.path.join(tmp, "input.png")
            img.save(img_path)
            auto_h = None
            if not job.get("height_cm"):
                try:
                    auto_h = estimate_height(img)
                    job["height_cm"] = auto_h["height_cm"]
                except Exception:
                    traceback.print_exc()

            if multi:
                set_stage(job, "Ko'p rasmli model yuklanmoqda", lo_shape - 4, lo_shape, expected=45)
                shape_pipe = None
                free_gpu()
                pipe = get_mv_pipe()
                pipe.to("cuda")
                shape_input = imgs
            else:
                mv_pipe = None
                free_gpu()
                if shape_pipe is None:
                    shape_pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
                pipe = shape_pipe
                shape_input = img
            set_stage(job, "Geometriya yaratilmoqda" + (f" ({len(imgs)} rasm)" if multi else ""), lo_shape, hi_shape, frac=0)
            mesh = pipe(
                image=shape_input, num_inference_steps=steps,
                guidance_scale=cfg["shape_guidance"],
                generator=torch.Generator().manual_seed(cfg["seed"]),
                octree_resolution=cfg["shape_resolution"], num_chunks=cfg["shape_chunks"],
                callback=on_step, callback_steps=1,
            )[0]
            # Do not cut arbitrary planes or retain only the largest component:
            # chair seats, legs and casters are real product geometry.
            quality["raw_shape"] = product_quality.mesh_info(mesh)
            mesh.export(str(workspace / "raw-shape.glb"))
            mesh, quality["floor_cleanup"] = product_quality.remove_generated_floor(mesh)
            mesh.export(str(workspace / "clean-shape.glb"))
            shape_path = os.path.join(tmp, "shape.glb")
            mesh.export(shape_path)
            pipe.to("cpu")
            # CPU offload alone still retains both large checkpoints in RAM.
            # Release all references before loading the paint pipeline.
            pipe = None
            shape_pipe = None
            mv_pipe = None
            free_gpu()

            if textured:
                try:
                    obj_path = os.path.join(tmp, "textured.obj")
                    paint_mesh, quality["texture_mesh"] = product_quality.texture_mesh(
                        mesh, cfg["texture_face_limit"])
                    paint_input = os.path.join(tmp, "paint-input.obj")
                    paint_mesh.export(paint_input)
                    paint_mesh.export(str(workspace / "texture-input.glb"))
                    set_stage(job, "Tekstura modeli yuklanmoqda", 42, 50, expected=60)
                    get_paint_pipe(cfg)
                    set_stage(job, "Tekstura yaratilmoqda", 50, 96, expected=EST["texture"])
                    t0 = time.time()
                    paint_pipe(
                        mesh_path=paint_input,
                        image_path=img_path,
                        output_mesh_path=obj_path,
                        save_glb=False,
                        use_remesh=False,
                    )
                    EST["texture"] = time.time() - t0
                    set_stage(job, "GLB saqlanmoqda", 96, 100, expected=10)
                    create_glb_with_pbr_materials(
                        obj_path,
                        {
                            "albedo": obj_path.replace(".obj", ".jpg"),
                            "metallic": obj_path.replace(".obj", "_metallic.jpg"),
                            "roughness": obj_path.replace(".obj", "_roughness.jpg"),
                        },
                        out_path,
                    )
                except Exception as e:
                    traceback.print_exc()
                    note = (note + "\n" if note else "") + f"Teksturani yaratib bo‘lmadi ({type(e).__name__}: {e}), tekstursiz saqlandi"
                    textured = False
                finally:
                    unload_paint_pipe()
            if not textured:
                set_stage(job, "GLB saqlanmoqda", 96, 100, expected=5)
                shutil.copy(shape_path, out_path)
            dims = None
            if job.get("height_cm"):
                try:
                    set_stage(job, "Haqiqiy o'lchamga keltirilmoqda", 98, 100, expected=3)
                    dims = scale_glb(out_path, out_path, job["height_cm"], job.get("width_cm"), job.get("depth_cm"), exact_dimensions=job.get("fit_dimensions", False))
                    if dims["dimension_mismatch"]:
                        note = (note + "\n" if note else "") + "Ogohlantirish: en/chuqurlik kiritilgan qiymatdan 15% dan ko'p farq qiladi"
                except Exception as e:
                    traceback.print_exc()
                    note = (note + "\n" if note else "") + f"Masshtablab bo'lmadi ({type(e).__name__}: {e})"
            if auto_h and dims:
                note = (note + "\n" if note else "") + f"Bo'yi avtomatik taxmin qilindi: {auto_h['type']} ≈ {auto_h['height_cm']} sm (ishonch {auto_h['confidence']})"
            job["result"] = dict(
                dims=dims,
                auto_height=auto_h,
                file=fname,
                path=os.path.join("3dfiles", collection, fname),
                url=f"/files/{collection}/{fname}",
                note=note,
                textured=textured,
                quality=quality,
            )
            job["status"] = "done"
            job["stage"] = "Yaratildi — sifatini tekshiring"
            (workspace / "quality.json").write_text(json.dumps(quality), encoding="utf8")
        except Exception as e:
            traceback.print_exc()
            job["status"] = "error"
            job["error"] = f"{type(e).__name__}: {e}"
        finally:
            job["images"] = None
            try:
                product_quality.save_completed(JOBS)
            except Exception:
                traceback.print_exc()
            try:
                pipe = None
                shape_pipe = None
                mv_pipe = None
                free_gpu()
            except Exception:
                traceback.print_exc()


def worker():
    while True:
        jid = JOB_QUEUE.get()
        job = JOBS[jid]
        with JOBS_LOCK:
            if jid in WAITING:
                WAITING.remove(jid)
        job["status"] = "running"
        set_stage(job, "Boshlanmoqda", 0, 1, expected=1)
        process(job)


threading.Thread(target=worker, daemon=True).start()


@app.get("/api/jobs")
def api_jobs():
    cid = request.args.get("client", "")
    mine = [j for j in JOBS.values() if cid and j.get("client") == cid]
    jobs = sorted(mine, key=lambda j: j["created"])[-50:]
    return jsonify([public(j) for j in jobs])


@app.post("/api/convert")
def convert():
    fs = [f for f in request.files.getlist("image") if f]
    collection = safe(request.form.get("collection", ""))
    if not fs or not collection:
        return jsonify(error="Rasm va kolleksiya nomi kerak"), 400
    if len(fs) > len(ROLES):
        return jsonify(error=f"Eng ko'pi bilan {len(ROLES)} ta rasm"), 400
    try:
        roles = image_roles(len(fs), request.form.get("roles", ""))
    except ValueError as exc:
        return jsonify(error=str(exc)), 400
    def num(k):
        try:
            v = float(request.form.get(k, "") or 0)
        except ValueError:
            return None
        return v if math.isfinite(v) and 0 < v <= 5000 else None

    dimensions = {axis: num(axis + "_cm") for axis in ("height", "width", "depth")}
    for axis, value in dimensions.items():
        if request.form.get(axis + "_cm", "").strip() and value is None:
            return jsonify(error="O‘lchamlar 0 dan katta, 5000 sm dan oshmagan son bo‘lishi kerak"), 400
    ai_prepare = request.form.get("ai_prepare", "1" if furniture_ai.enabled() else "0") == "1"
    reconstruction_scope = request.form.get("reconstruction_scope", "single")
    if reconstruction_scope not in ("single", "set"):
        return jsonify(error="Rekonstruksiya turi single yoki set bo‘lishi kerak"), 400
    if ai_prepare and not furniture_ai.enabled():
        return jsonify(error="AI tahlili serverda sozlanmagan"), 503
    images = []
    for f, role in zip(fs, roles):
        data = f.read()
        try:
            check = Image.open(io.BytesIO(data))
            if check.width * check.height > 25_000_000:
                return jsonify(error="Rasm 25 megapikseldan oshmasligi kerak"), 400
            check.verify()
        except Exception:
            return jsonify(error=f"Rasm o'qib bo'lmadi: {f.filename}"), 400
        images.append((role, data))
    front_name = fs[roles.index("front")].filename
    job_id = uuid.uuid4().hex[:10]
    workspace = Path.home() / ".local/share/imageto3d/jobs" / job_id
    workspace.mkdir(parents=True, mode=0o700)
    for role, data in images:
        source = workspace / (role + "-original.image")
        source.write_bytes(data)
        source.chmod(0o600)
    job = dict(
        id=job_id,
        input_dir=str(workspace),
        ai_prepare=ai_prepare,
        reconstruction_scope=reconstruction_scope,
        ai_analysis=None,
        fit_dimensions=request.form.get("fit_dimensions", "1") == "1" and all(dimensions.values()),
        name=safe(os.path.splitext(front_name or "")[0]) or "model",
        collection=collection,
        client=safe(request.form.get("client", "")),
        remove_bg=request.form.get("remove_bg", "1") == "1",
        textured=request.form.get("textured", "1") == "1",
        images=images,
        height_cm=dimensions["height"], width_cm=dimensions["width"], depth_cm=dimensions["depth"],
        n_images=len(images),
        status="queued",
        stage="Navbatda",
        lo=0, hi=0, frac=None, expected=None, t0=time.time(),
        created=time.time(),
        error=None,
        result=None,
    )
    JOBS[job["id"]] = job
    with JOBS_LOCK:
        WAITING.append(job["id"])
    JOB_QUEUE.put(job["id"])
    return jsonify(public(job))


PAGE = """<!doctype html>
<html lang="uz"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Rasm → 3D</title>
<script type="module" src="https://unpkg.com/@google/model-viewer@3.5.0/dist/model-viewer.min.js"></script>
<style>
:root{--bg:#f6f7f9;--card:#fff;--fg:#1c1f26;--mut:#6b7280;--acc:#4f46e5;--bd:#e5e7eb}
@media(prefers-color-scheme:dark){:root{--bg:#0f1115;--card:#181b22;--fg:#e8eaee;--mut:#9aa1ad;--acc:#818cf8;--bd:#2a2f3a}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px system-ui,sans-serif;padding:24px 16px}
main{max-width:640px;margin:0 auto}
h1{font-size:1.5rem;margin:0 0 16px}
.card{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:16px;margin-bottom:16px}
label{display:block;font-size:.85rem;color:var(--mut);margin:12px 0 4px}
select,input[type=text]{width:100%;padding:10px;border-radius:8px;border:1px solid var(--bd);background:var(--bg);color:var(--fg);font:inherit}
#drop{border:2px dashed var(--bd);border-radius:12px;padding:28px;text-align:center;color:var(--mut);cursor:pointer}
#drop.over{border-color:var(--acc)}
#thumbs{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}
.th{width:calc(50% - 5px);position:relative}
.th img{width:100%;height:130px;object-fit:cover;border-radius:8px;border:1px solid var(--bd);display:block}
.th select{margin-top:4px;padding:6px;font-size:.85rem}
.th .x{position:absolute;top:4px;right:4px;width:24px;height:24px;padding:0;margin:0;border-radius:12px;background:rgba(0,0,0,.6);line-height:24px;font-size:14px}
#clr{background:none;color:var(--acc);width:auto;padding:0;margin:8px 0 0;text-decoration:underline;font-size:.85rem;display:none}
.note{font-size:.8rem;color:var(--mut);margin-top:6px}
button{background:var(--acc);color:#fff;border:0;border-radius:8px;padding:12px 18px;font:inherit;cursor:pointer;width:100%;margin-top:16px}
button:disabled{opacity:.5;cursor:wait}
#status{margin-top:12px;color:var(--mut);white-space:pre-wrap}
.job{border-top:1px solid var(--bd);padding:12px 0}
.job:first-child{border-top:0;padding-top:0}
.jt{display:flex;justify-content:space-between;gap:8px;font-size:.95rem}
.jt small{color:var(--mut)}
.bar{height:10px;background:var(--bg);border:1px solid var(--bd);border-radius:6px;overflow:hidden;margin:8px 0 4px}
.fill{height:100%;background:var(--acc);transition:width .6s ease}
.fill.err{background:#dc2626}
.js{font-size:.85rem;color:var(--mut)}
.job a,.job .lnk{color:var(--acc);cursor:pointer;margin-right:12px;font-size:.9rem;text-decoration:underline;background:none;border:0;padding:0;width:auto;margin-top:0;display:inline}
model-viewer{width:100%;height:360px;border-radius:8px;background:var(--bg)}
.row{display:flex;gap:12px;align-items:center;margin-top:12px;font-size:.9rem}
</style></head><body><main>
<h1>Rasm → 3D</h1>
<div class="card">
  <div id="drop"><span id="hint">Rasm(lar)ni shu yerga tashlang yoki bosib tanlang</span></div>
  <div id="thumbs"></div>
  <div class="note" id="mvnote" style="display:none">Bir nechta rasm = bitta model (ko'p burchakli). Har rasmga rolini tanlang; "Old" majburiy.</div>
  <button id="clr" type="button">Tanlovni tozalash</button>
  <input id="file" type="file" accept="image/*" multiple hidden>
  <label for="col">Kolleksiya</label>
  <select id="col"></select>
  <label for="scope">Nimani yaratish kerak?</label>
  <select id="scope"><option value="single">Bitta mebel</option><option value="set">Butun mebel komplekti — bitta GLB</option></select>
  <input id="newcol" type="text" placeholder="Yangi kolleksiya nomi" style="display:none;margin-top:8px">
  <div class="row"><label style="margin:0">Haqiqiy o'lcham, sm (bo'sh qoldirsangiz, avtomatik taxmin qilinadi):</label>
    <input id="hh" type="number" min="1" placeholder="Bo'yi" style="width:90px"> <input id="hw" type="number" min="1" placeholder="Eni" style="width:90px"> <input id="hd" type="number" min="1" placeholder="Chuqurligi" style="width:100px"></div>
  <div class="row"><input id="ai" type="checkbox" {% if ai_enabled %}checked{% else %}disabled{% endif %}><label for="ai" style="margin:0">AI bilan mebelni ajratish va o‘lchamlarni tavsiya qilish</label></div>
  <div class="note">AI faqat taxmin qiladi. Kiritgan o‘lchamlaringiz ustun; yangi rasm yoki dizayn generatsiya qilinmaydi.</div>
  <div class="row"><input id="fit" type="checkbox" checked><label for="fit" style="margin:0">Uchala o‘lcham kiritilsa aniq moslash (proporsiya o‘zgarishi mumkin)</label></div>
  <div class="row"><input id="tx" type="checkbox" checked><label for="tx" style="margin:0">Tekstura (PBR) yaratish (sekinroq)</label></div>
  <div class="row"><input id="rb" type="checkbox" checked><label for="rb" style="margin:0">Orqa fonni olib tashlash</label></div>
  <button id="go">3D yaratish</button>
  <div id="status"></div>
</div>
<div class="card" id="jobsCard" style="display:none"><div id="jobs"></div></div>
<div class="card" id="result" style="display:none">
  <model-viewer id="mv" camera-controls auto-rotate shadow-intensity="1"></model-viewer>
</div>
</main>
<script>
const $=id=>document.getElementById(id);
let files=[];
const NEW="__new__";
let CID=localStorage.getItem('cid');
if(!CID){CID=Array.from({length:24},()=>Math.floor(Math.random()*16).toString(16)).join('');localStorage.setItem('cid',CID)}
const esc=t=>String(t==null?'':t).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
async function loadCols(keep){
  const cols=await (await fetch('/api/collections')).json();
  $('col').innerHTML=cols.map(c=>`<option>${esc(c)}</option>`).join('')+`<option value="${NEW}">+ Yangi kolleksiya...</option>`;
  if(keep&&[...$('col').options].some(o=>o.value===keep))$('col').value=keep;
  toggle();
}
function toggle(){$('newcol').style.display=$('col').value===NEW?'block':'none'}
$('col').onchange=toggle;
const ROLES=[['front',"Old"],['back','Orqa'],['left','Chap'],['right',"O'ng"]];
let roles=[];
function drawThumbs(){
  $('thumbs').innerHTML=files.map((f,i)=>`<div class="th"><img src="${URL.createObjectURL(f)}"><button class="x" type="button" data-rm="${i}">×</button>${
    files.length>1?`<select data-role="${i}"><option value=""${!roles[i]?' selected':''}>Rakursni tanlang</option>${ROLES.map(r=>`<option value="${r[0]}"${roles[i]===r[0]?' selected':''}>${r[1]}</option>`).join('')}</select>`:''}</div>`).join('');
  $('hint').textContent=files.length?files.length+" ta rasm tanlandi, yana qo'shish mumkin (4 tagacha)":"Rasm(lar)ni shu yerga tashlang yoki bosib tanlang";
  $('mvnote').style.display=files.length>1?'block':'none';
  $('clr').style.display=files.length?'inline':'none';
}
function setFiles(list){
  const fs=[...list].filter(f=>f.type.startsWith('image/'));
  if(!fs.length)return;
  files=[...files,...fs].slice(0,4);
  roles=files.map((_,i)=>roles[i]||'');
  drawThumbs();
}
$('thumbs').addEventListener('change',e=>{const i=e.target.dataset&&e.target.dataset.role;if(i!==undefined)roles[+i]=e.target.value});
$('thumbs').addEventListener('click',e=>{const i=e.target.dataset&&e.target.dataset.rm;if(i!==undefined){files.splice(+i,1);roles.splice(+i,1);drawThumbs()}});
$('clr').onclick=()=>{files=[];roles=[];$('file').value='';drawThumbs()};
$('drop').onclick=()=>$('file').click();
$('file').onchange=e=>{setFiles(e.target.files);$('file').value=''};
$('drop').ondragover=e=>{e.preventDefault();$('drop').classList.add('over')};
$('drop').ondragleave=()=>$('drop').classList.remove('over');
$('drop').ondrop=e=>{e.preventDefault();$('drop').classList.remove('over');setFiles(e.dataTransfer.files)};
window.addEventListener('paste',e=>setFiles(e.clipboardData.files));
$('go').onclick=async()=>{
  const col=$('col').value===NEW?$('newcol').value.trim():$('col').value;
  if(!files.length)return $('status').textContent='Avval rasm tanlang';
  if(!col)return $('status').textContent='Kolleksiya nomini kiriting';
  if(files.length>1){
    if(roles.some(r=>!r))return $('status').textContent='Har rasm uchun rakursni tanlang';
    if(new Set(roles).size!==roles.length)return $('status').textContent='Har rol faqat bir marta tanlanishi mumkin';
    if(!roles.includes('front'))return $('status').textContent="Rollardan biri 'Old' bo'lishi kerak";
  }
  $('go').disabled=true;$('status').textContent='';
  try{
    const fd=new FormData();
    files.forEach(f=>fd.append('image',f));
    fd.append('roles',files.length>1?roles.join(','):'front');
    fd.append('client',CID);fd.append('collection',col);fd.append('reconstruction_scope',$('scope').value);fd.append('ai_prepare',$('ai').checked?'1':'0');fd.append('fit_dimensions',$('fit').checked?'1':'0');fd.append('height_cm',$('hh').value);fd.append('width_cm',$('hw').value);fd.append('depth_cm',$('hd').value);fd.append('textured',$('tx').checked?'1':'0');fd.append('remove_bg',$('rb').checked?'1':'0');
    const r=await fetch('/api/convert',{method:'POST',body:fd});
    const j=await r.json();
    if(!r.ok)throw new Error(j.error||'Xatolik');
    files=[];roles=[];drawThumbs();
    poll();
  }catch(e){$('status').textContent='Xato: '+e.message}
  $('go').disabled=false;
};
let last='',doneSeen=new Set(),first=true;
function line(j){
  if(j.status==='queued')return `Navbatda: ${j.position}-o'rin`;
  if(j.status==='running')return `${esc(j.stage)} · ${j.percent}%`;
  if(j.status==='error')return 'Xato: '+esc(j.error);
  return 'Tayyor'+(j.result&&j.result.dims?' · '+j.result.dims.width_cm+'×'+j.result.dims.height_cm+'×'+j.result.dims.depth_cm+' sm, '+j.result.dims.volume_m3+' m³':'')+(j.result&&j.result.note?' · '+esc(j.result.note):'');
}
function render(jobs){
  $('jobsCard').style.display=jobs.length?'block':'none';
  $('jobs').innerHTML=jobs.slice().reverse().map(j=>`<div class="job">
    <div class="jt"><span>${esc(j.name)}${j.n_images>1?` <small>(${j.n_images} rasm)</small>`:''} <small>→ ${esc(j.collection)}</small></span><small>${j.status==='queued'?'navbatda':j.percent+'%'}</small></div>
    <div class="bar"><div class="fill${j.status==='error'?' err':''}" style="width:${j.status==='error'?100:j.percent}%"></div></div>
    <div class="js">${line(j)}</div>
    ${j.status==='done'&&j.result?`<div class="js" style="margin-top:6px"><button class="lnk" data-url="${esc(j.result.url)}">Ko'rish</button><a href="${esc(j.result.url)}" download>Yuklab olish</a>${esc(j.result.path)}</div>`:''}
  </div>`).join('');
}
async function poll(){
  try{
    const jobs=await (await fetch('/api/jobs?client='+CID)).json();
    const s=JSON.stringify(jobs);
    if(s!==last){last=s;render(jobs)}
    let fresh=false;
    jobs.forEach(j=>{if(j.status==='done'&&!doneSeen.has(j.id)){doneSeen.add(j.id);if(!first){fresh=true;$('mv').src=j.result.url;$('result').style.display='block'}}});
    first=false;
    if(fresh)loadCols($('col').value);
  }catch(e){}
}
$('jobs').addEventListener('click',e=>{const u=e.target.dataset&&e.target.dataset.url;if(u){$('mv').src=u;$('result').style.display='block';$('result').scrollIntoView({behavior:'smooth'})}});
setInterval(poll,1000);poll();
loadCols();
</script></body></html>"""

if __name__ == "__main__":
    ip = subprocess.run(["tailscale", "ip", "-4"], capture_output=True, text=True).stdout.split()[0]
    print(f"http://{ip}:5000", flush=True)
    app.run(host=ip, port=5000, threaded=True)
