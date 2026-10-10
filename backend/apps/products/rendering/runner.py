"""3D model (GLB) -> standart mahsulot rasmlari (Playwright + model-viewer).

Oqim: GLB'ni vaqtinchalik papkaga yuklash -> tekshirish -> render sahifani
mahalliy HTTP serverda ochish -> `renderAll()` -> PNG'larni standartlash ->
WebP/AVIF (400/800/1600) -> storage'ga content-hash'li kalit bilan saqlash ->
bazaga yozish. Faqat server render qilgan rasmlar xaridorga ko'rinadi."""
import functools
import http.server
import json
import logging
import shutil
import socketserver
import tempfile
import threading
import time
import urllib.parse
from pathlib import Path

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.utils import timezone
from django.utils.text import slugify

from ..models import Product, RenderedImage, RenderJob, Variant
from . import imaging, validate

logger = logging.getLogger(__name__)

SHOTS = ("hero", "front", "side", "back", "top")
CHROMIUM_ARGS = [
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
    "--ignore-gpu-blocklist",
    "--use-gl=angle",
    "--disable-dev-shm-usage",
    "--renderer-process-limit=1",
]
VARIANT_TIMEOUT_S = 120


def render_page_dir() -> Path:
    configured = getattr(settings, "RENDER_PAGE_DIR", "")
    candidates = [Path(configured)] if configured else []
    root = Path(settings.BASE_DIR).parent / "frontend"
    candidates += [root / "dist" / "render", root / "public" / "render"]
    for c in candidates:
        if (c / "index.html").exists():
            return c
    raise RuntimeError("Render sahifa topilmadi (frontend/public/render/index.html).")


class _QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):  # jim
        pass

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


def _serve(directory: Path):
    handler = functools.partial(_QuietHandler, directory=str(directory))
    server = socketserver.ThreadingTCPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, server.server_address[1]


def _variant_payload(product: Product):
    return [
        {"id": str(v.id), "name": v.name, "color": v.color_hex or ""}
        for v in product.variants.filter(is_deleted=False).order_by("created_at")
        if v.color_hex
    ]


def run_browser(glb_path: Path, variants: list, size: int = 1600, shots=SHOTS) -> dict:
    """Playwright orqali `renderAll()` ni ishga tushiradi. Qaytaradi: natija dict."""
    from playwright.sync_api import sync_playwright

    work = Path(tempfile.mkdtemp(prefix="vida-render-"))
    try:
        shutil.copytree(render_page_dir(), work / "render")
        shutil.copy(glb_path, work / "model.glb")
        server, port = _serve(work)
        try:
            query = urllib.parse.urlencode(
                {
                    "src": f"http://127.0.0.1:{port}/model.glb",
                    "size": size,
                    "shots": ",".join(shots),
                    "variants": json.dumps(variants),
                }
            )
            with sync_playwright() as pw:
                browser = pw.chromium.launch(args=CHROMIUM_ARGS)
                try:
                    page = browser.new_page(viewport={"width": 1024, "height": 1024})
                    page.goto(f"http://127.0.0.1:{port}/render/index.html?{query}")
                    page.wait_for_function("window.__ready === true", timeout=30_000)
                    page.evaluate("setTimeout(() => window.renderAll().catch(() => {}), 0)")
                    budget = VARIANT_TIMEOUT_S * 1000 * max(1, len(variants) or 3) + 60_000
                    page.wait_for_function(
                        "window.__renderDone === true || window.__renderError !== null", timeout=budget
                    )
                    error = page.evaluate("window.__renderError")
                    if error:
                        raise RuntimeError(error)
                    return page.evaluate("window.__renderResult")
                finally:
                    browser.close()
        finally:
            server.shutdown()
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _save(key: str, data: bytes) -> str:
    saved = default_storage.save(key, ContentFile(data))
    return default_storage.url(saved)


def _glb_sources(product: Product):
    """Render manbalari: mahsulotning umumiy GLB'i (rang variantlari ustiga tint
    qilinadi) va o'z GLB'iga ega har bir variant (qarang Model3D.variant).
    Qaytaradi: [(label, model3d, variant|None)]."""
    sources = []
    pm = getattr(product, "model3d", None)
    if pm is not None and not pm.is_deleted and pm.glb_file and pm.glb_file.name.lower().endswith(".glb"):
        sources.append(("product", pm, None))
    for v in product.variants.filter(is_deleted=False).order_by("created_at"):
        vm = getattr(v, "model3d", None)
        if vm is not None and not vm.is_deleted and vm.glb_file and vm.glb_file.name.lower().endswith(".glb"):
            sources.append(("variant", vm, v))
    return sources


def source_key(product: Product) -> str:
    """Render manbalarining barqaror imzosi (o'zgarmagan fayllar qayta render qilinmasin)."""
    return "|".join(sorted(m.glb_file.name for _, m, _ in _glb_sources(product)))[:300]


def process_job(job: RenderJob) -> dict:
    """Bitta job'ni bajaradi; natija statistikasini qaytaradi."""
    product = job.product
    sources = _glb_sources(product)
    if not sources:
        raise validate.RenderValidationError(
            "Render uchun GLB model yo'q (model hali GLB'ga aylantirilmagan bo'lishi mumkin)."
        )

    tmp = Path(tempfile.mkdtemp(prefix="vida-glb-"))
    try:
        started = time.monotonic()
        stats = {"triangles": 0, "bytes": 0}
        results = []  # [(variant_db|None, result_dict, is_variant_source)]
        db_variant_payload = _variant_payload(product)
        for i, (kind, model3d, variant) in enumerate(sources):
            glb_path = tmp / f"model-{i}.glb"
            with model3d.glb_file.open("rb") as src, open(glb_path, "wb") as dst:
                shutil.copyfileobj(src, dst)
            st = validate.validate_glb_bytes(glb_path.read_bytes())
            stats["triangles"] += st["triangles"]
            stats["bytes"] += st["bytes"]
            payload = db_variant_payload if kind == "product" else []
            result = run_browser(glb_path, payload)
            d = result["dimensionsCm"]
            validate.validate_dimensions_cm(d["w"], d["h"], d["d"])
            results.append((variant, result, kind == "variant"))
        render_s = time.monotonic() - started

        # Mahsulot o'lchami: umumiy model bo'lsa o'sha, aks holda birinchi variant modeli.
        dims = results[0][1]["dimensionsCm"]

        variants_by_name = {v.name: v for v in product.variants.filter(is_deleted=False)}
        RenderedImage.objects.filter(product=product).delete()
        saved = 0
        hero_png = None
        order = {s: i for i, s in enumerate(SHOTS)}
        seen_slugs = set()
        for owner_variant, result, is_variant_source in results:
            for variant in result["variants"]:
                # O'z modeli bor variantda nom — variantning o'zi; "default" guruh ham shu nom bilan.
                vname = owner_variant.name if is_variant_source else variant["name"]
                db_variant = owner_variant if is_variant_source else variants_by_name.get(vname)
                slug = slugify(vname) or "default"
                while slug in seen_slugs:  # bir xil nomli guruhlar to'qnashmasin
                    slug += "-2"
                seen_slugs.add(slug)
                for shot in sorted(variant["shots"], key=lambda s: order.get(s["key"], 99)):
                    base = imaging.normalize_square(imaging.data_url_to_image(shot["dataUrl"]), 1600)
                    urls = {}
                    for size in imaging.SIZES:
                        urls[str(size)] = {}
                        for fmt in ("webp", "avif"):
                            data = imaging.encode(base, size, fmt)
                            key = f"products/{product.id}/{slug}/{shot['key']}-{size}-{imaging.short_hash(data)}.{fmt}"
                            urls[str(size)][fmt] = _save(key, data)
                    RenderedImage.objects.create(
                        product=product,
                        variant=db_variant,
                        variant_name=vname,
                        variant_slug=slug,
                        shot=shot["key"],
                        sort_order=order.get(shot["key"], 99),
                        urls=urls,
                    )
                    saved += 1
                    if hero_png is None and shot["key"] == "hero":
                        hero_png = imaging.encode(base, 1600, "png")

        product.model_dims_cm = dims
        product.render_status = Product.RenderStatus.READY
        product.render_error = ""
        _check_dimensions(product, dims)
        update = ["model_dims_cm", "render_status", "render_error", "needs_moderation", "moderation_note"]
        if hero_png and (not product.image or product.image_from_render):
            product.image.save(f"render-{product.id}.png", ContentFile(hero_png), save=False)
            product.image_from_render = True
            update += ["image", "image_from_render"]
        product.save(update_fields=update + ["updated_at"])
        n_variants = sum(len(r["variants"]) for _, r, _ in results)
        return {"render_s": round(render_s, 1), "images": saved, "variants": n_variants, **stats}
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _check_dimensions(product: Product, dims: dict) -> None:
    """Sotuvchi kiritgan o'lcham modeldan >10% farq qilsa moderatsiyaga belgilanadi."""
    product.needs_moderation = False
    product.moderation_note = ""
    variant = product.variants.filter(is_deleted=False).order_by("created_at").first()
    if variant is None:
        return
    entered = sorted([float(variant.width) * 100, float(variant.height) * 100, float(variant.depth) * 100])
    if entered == [100.0, 100.0, 100.0]:
        return  # to'ldirilmagan standart qiymat (1x1x1 m)
    actual = sorted([dims["w"], dims["h"], dims["d"]])
    for e, a in zip(entered, actual):
        if a > 0 and abs(e - a) / a > 0.10:
            product.needs_moderation = True
            product.moderation_note = (
                f"Kiritilgan o'lcham ({entered[0]:.0f}×{entered[1]:.0f}×{entered[2]:.0f} sm) modeldan "
                f"({actual[0]:.0f}×{actual[1]:.0f}×{actual[2]:.0f} sm) farq qiladi."
            )
            return


def enqueue(product: Product, force: bool = False):
    """Render navbatiga qo'yadi. `force=False` bo'lsa va xuddi shu GLB'lar to'plami
    allaqachon render qilingan (yoki kutilayotgan) bo'lsa — hech narsa qilmaydi."""
    source = source_key(product)
    if not source:
        return None
    pending = RenderJob.objects.filter(product=product, status=RenderJob.Status.PENDING).first()
    if pending:
        return pending
    if not force and RenderJob.objects.filter(
        product=product, status=RenderJob.Status.DONE, source_name=source
    ).exists():
        return None
    Product.objects.filter(pk=product.pk).update(render_status=Product.RenderStatus.PENDING, render_error="")
    return RenderJob.objects.create(product=product, source_name=source)


def run_one(job: RenderJob, max_attempts: int = 3):
    """Job'ni bajaradi, xatolarni boshqaradi (doimiy xato -> darhol failed;
    vaqtinchalik -> 2 marta qayta urinish, so'ng failed)."""
    job.status = RenderJob.Status.PROCESSING
    job.attempts += 1
    job.started_at = timezone.now()
    job.save(update_fields=["status", "attempts", "started_at", "updated_at"])
    Product.objects.filter(pk=job.product_id).update(render_status=Product.RenderStatus.PROCESSING)
    t0 = time.monotonic()
    stats = None
    try:
        stats = process_job(job)
        job.source_name = source_key(job.product)
        logger.info("render tayyor: %s", stats)
        job.status = RenderJob.Status.DONE
        job.error = ""
    except validate.RenderValidationError as exc:
        job.status = RenderJob.Status.FAILED
        job.error = str(exc)
        Product.objects.filter(pk=job.product_id).update(
            render_status=Product.RenderStatus.FAILED, render_error=str(exc)
        )
    except Exception as exc:  # noqa: BLE001
        logger.exception("Render xatosi (job=%s)", job.id)
        job.error = str(exc)[:1000]
        if job.attempts >= max_attempts:
            job.status = RenderJob.Status.FAILED
            Product.objects.filter(pk=job.product_id).update(
                render_status=Product.RenderStatus.FAILED,
                render_error="Render amalga oshmadi. Keyinroq qayta urinib ko'ring.",
            )
        else:
            job.status = RenderJob.Status.PENDING
            Product.objects.filter(pk=job.product_id).update(render_status=Product.RenderStatus.PENDING)
    finally:
        job.finished_at = timezone.now()
        job.duration_s = round(time.monotonic() - t0, 1)
        job.save(update_fields=["status", "error", "source_name", "finished_at", "duration_s", "updated_at"])
    return stats
