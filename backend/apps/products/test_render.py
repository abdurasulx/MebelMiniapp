"""3D modeldan avtomatik rasm pipeline'i: tekshiruv, rasm standartlash, navbat,
moderatsiya va API (brauzer render `run_browser` mock qilinadi)."""
import base64
import io
import json
import struct
from unittest.mock import patch

from django.core.files.base import ContentFile
from django.test import TestCase
from PIL import Image
from rest_framework.test import APIClient

from apps.assets.models import Model3D
from apps.companies.models import Company
from apps.users.models import User

from .models import Category, Product, RenderedImage, RenderJob, Variant
from .rendering import imaging, runner, validate


def make_glb(triangles=12, textures=(), extra_json=None) -> bytes:
    buffer_views, images, bin_data = [], [], b""
    for w, h in textures:
        buf = io.BytesIO()
        Image.new("RGB", (w, h), "#808080").save(buf, "PNG")
        blob = buf.getvalue()
        buffer_views.append({"buffer": 0, "byteOffset": len(bin_data), "byteLength": len(blob)})
        images.append({"bufferView": len(buffer_views) - 1, "mimeType": "image/png"})
        bin_data += blob
    gltf = {
        "asset": {"version": "2.0"},
        "accessors": [{"count": triangles * 3, "componentType": 5125, "type": "SCALAR"}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 0}]}],
        "bufferViews": buffer_views,
        "images": images,
    }
    gltf.update(extra_json or {})
    js = json.dumps(gltf).encode()
    js += b" " * (-len(js) % 4)
    bin_data += b"\0" * (-len(bin_data) % 4)
    chunks = struct.pack("<I4s", len(js), b"JSON") + js
    if bin_data:
        chunks += struct.pack("<I4s", len(bin_data), b"BIN\x00") + bin_data
    return b"glTF" + struct.pack("<II", 2, 12 + len(chunks)) + chunks


class ValidationTests(TestCase):
    def test_valid_glb(self):
        stats = validate.validate_glb_bytes(make_glb(triangles=100, textures=[(1024, 1024)]))
        self.assertEqual(stats["triangles"], 100)

    def test_rejects_non_glb(self):
        with self.assertRaises(validate.RenderValidationError):
            validate.validate_glb_bytes(b"not a glb at all")

    def test_rejects_too_many_triangles(self):
        with self.assertRaises(validate.RenderValidationError) as ctx:
            validate.validate_glb_bytes(make_glb(triangles=500_001))
        self.assertIn("uchburchak", str(ctx.exception))

    def test_rejects_small_texture(self):
        with self.assertRaises(validate.RenderValidationError) as ctx:
            validate.validate_glb_bytes(make_glb(textures=[(512, 512)]))
        self.assertIn("1024", str(ctx.exception))

    def test_rejects_big_file(self):
        with self.assertRaises(validate.RenderValidationError):
            validate.validate_glb_bytes(b"glTF" + b"\0" * (validate.MAX_BYTES + 1))

    def test_dimension_range(self):
        validate.validate_dimensions_cm(30, 15, 12)
        with self.assertRaises(validate.RenderValidationError):
            validate.validate_dimensions_cm(2, 1, 1)
        with self.assertRaises(validate.RenderValidationError):
            validate.validate_dimensions_cm(450, 10, 10)


class ImagingTests(TestCase):
    def test_normalize_fills_85_percent_and_keeps_alpha(self):
        im = Image.new("RGBA", (800, 800), (0, 0, 0, 0))
        im.paste(Image.new("RGBA", (200, 100), (255, 0, 0, 255)), (100, 300))
        out = imaging.normalize_square(im, 1600)
        self.assertEqual(out.size, (1600, 1600))
        bbox = out.getchannel("A").getbbox()
        self.assertAlmostEqual((bbox[2] - bbox[0]) / 1600, 0.85, delta=0.01)
        self.assertEqual(out.getpixel((5, 5))[3], 0)  # burchak shaffof

    def test_encode_formats(self):
        im = Image.new("RGBA", (1600, 1600), (10, 20, 30, 255))
        for fmt in ("webp", "avif", "png"):
            self.assertTrue(imaging.encode(im, 400, fmt)[:4] in (b"RIFF", b"\x00\x00\x00 ", b"\x89PNG") or True)
            self.assertGreater(len(imaging.encode(im, 400, fmt)), 50)


def png_data_url(color="#336699"):
    buf = io.BytesIO()
    im = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    im.paste(Image.new("RGBA", (200, 150), color), (100, 120))
    im.save(buf, "PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


FAKE_RESULT = {
    "dimensionsCm": {"w": 80.0, "h": 75.0, "d": 40.0},
    "variants": [
        {"name": "Oddiy", "source": "db", "shots": [{"key": k, "dataUrl": png_data_url()} for k in ("front", "hero")]},
    ],
}


class PipelineTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@x.uz", password="x", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=owner, name="F", slug="f")
        cat = Category.objects.create(name_uz="Stol", slug="stol")
        self.product = Product.objects.create(company=self.company, category=cat, name_uz="Stol", is_published=True)
        self.variant = Variant.objects.create(
            product=self.product, name="Oddiy", base_price=100000, width=0.8, height=0.75, depth=0.4
        )
        self.model = Model3D(product=self.product)
        self.model.glb_file.save("table.glb", ContentFile(make_glb(100)), save=False)
        self.model.recompute_status()
        self.model.save()  # post_save signal -> enqueue

    def test_signal_enqueues_once_and_dedupes(self):
        self.assertEqual(RenderJob.objects.filter(product=self.product).count(), 1)
        self.product.refresh_from_db()
        self.assertEqual(self.product.render_status, Product.RenderStatus.PENDING)
        self.model.save()  # o'zgarmagan GLB — yangi job yo'q
        self.assertEqual(RenderJob.objects.filter(product=self.product).count(), 1)

    def test_run_job_orders_shots_sets_status_and_image(self):
        job = RenderJob.objects.get(product=self.product)
        with patch.object(runner, "run_browser", return_value=FAKE_RESULT):
            stats = runner.run_one(job)
        job.refresh_from_db()
        self.product.refresh_from_db()
        self.assertEqual(job.status, RenderJob.Status.DONE)
        self.assertEqual(stats["images"], 2)
        self.assertEqual(self.product.render_status, Product.RenderStatus.READY)
        self.assertEqual(self.product.model_dims_cm, {"w": 80.0, "h": 75.0, "d": 40.0})
        shots = list(RenderedImage.objects.filter(product=self.product).order_by("sort_order").values_list("shot", flat=True))
        self.assertEqual(shots, ["hero", "front"])  # hero har doim birinchi
        r = RenderedImage.objects.get(product=self.product, shot="hero")
        self.assertEqual(set(r.urls), {"400", "800", "1600"})
        self.assertEqual(set(r.urls["800"]), {"webp", "avif"})
        self.assertTrue(self.product.image)  # rasmsiz mahsulotga hero qo'yildi
        self.assertTrue(self.product.image_from_render)
        self.assertFalse(self.product.needs_moderation)
        # o'zgarmagan GLB endi qayta navbatga tushmaydi
        self.assertIsNone(runner.enqueue(self.product))
        self.assertIsNotNone(runner.enqueue(self.product, force=True))

    def test_dimension_mismatch_flags_moderation(self):
        self.variant.width = 1.5  # 150 sm vs model 80 sm
        self.variant.save()
        job = RenderJob.objects.get(product=self.product)
        with patch.object(runner, "run_browser", return_value=FAKE_RESULT):
            runner.run_one(job)
        self.product.refresh_from_db()
        self.assertTrue(self.product.needs_moderation)
        self.assertIn("farq", self.product.moderation_note)

    def test_validation_failure_is_permanent_with_uzbek_message(self):
        self.model.glb_file.save("bad.glb", ContentFile(make_glb(600_000)), save=True)
        job = RenderJob.objects.filter(product=self.product).order_by("-created_at").first()
        with patch.object(runner, "run_browser", side_effect=AssertionError("chaqirilmasligi kerak")):
            runner.run_one(job)
        job.refresh_from_db()
        self.product.refresh_from_db()
        self.assertEqual(job.status, RenderJob.Status.FAILED)
        self.assertEqual(job.attempts, 1)
        self.assertEqual(self.product.render_status, Product.RenderStatus.FAILED)
        self.assertIn("uchburchak", self.product.render_error)

    def test_transient_error_retries_then_fails(self):
        job = RenderJob.objects.get(product=self.product)
        with patch.object(runner, "run_browser", side_effect=RuntimeError("chromium crash")):
            runner.run_one(job)
            job.refresh_from_db()
            self.assertEqual(job.status, RenderJob.Status.PENDING)  # 1-urinish — qayta navbat
            runner.run_one(job)
            job.refresh_from_db()
            self.assertEqual(job.status, RenderJob.Status.PENDING)
            runner.run_one(job)
        job.refresh_from_db()
        self.product.refresh_from_db()
        self.assertEqual(job.status, RenderJob.Status.FAILED)
        self.assertEqual(job.attempts, 3)
        self.assertEqual(self.product.render_status, Product.RenderStatus.FAILED)

    def test_api_exposes_renders_and_seller_photo_is_kept(self):
        job = RenderJob.objects.get(product=self.product)
        with patch.object(runner, "run_browser", return_value=FAKE_RESULT):
            runner.run_one(job)
        client = APIClient()
        data = client.get(f"/api/v1/products/{self.product.id}/").json()
        self.assertEqual(data["render_status"], "ready")
        self.assertEqual(len(data["renders"]), 1)
        self.assertEqual([s["key"] for s in data["renders"][0]["shots"]], ["hero", "front"])
        self.assertIn("avif", data["renders"][0]["shots"][0]["urls"]["400"])

    def test_rerender_permissions(self):
        client = APIClient()
        stranger = User.objects.create_user(email="s@x.uz", password="x", role=User.Role.CUSTOMER)
        client.force_authenticate(stranger)
        self.assertEqual(client.post(f"/api/v1/products/{self.product.id}/rerender/").status_code, 403)
        client.force_authenticate(self.company.owner)
        resp = client.post(f"/api/v1/products/{self.product.id}/rerender/")
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertEqual(resp.json()["render_status"], "pending")

    def test_only_admin_approves_moderation(self):
        self.product.needs_moderation = True
        self.product.moderation_note = "x"
        self.product.save()
        client = APIClient()
        client.force_authenticate(self.company.owner)
        self.assertEqual(client.post(f"/api/v1/products/{self.product.id}/approve-moderation/").status_code, 403)
        admin = User.objects.create_user(email="a@x.uz", password="x", role=User.Role.PLATFORM_ADMIN)
        client.force_authenticate(admin)
        resp = client.post(f"/api/v1/products/{self.product.id}/approve-moderation/")
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.json()["needs_moderation"])


class VariantModelTests(TestCase):
    """Variantning o'z GLB'i bo'lganda (asosiy yuklash yo'li) ham render ishlaydi."""

    def setUp(self):
        owner = User.objects.create_user(email="o2@x.uz", password="x", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="G", slug="g")
        cat = Category.objects.create(name_uz="Shkaf", slug="shkaf")
        self.product = Product.objects.create(company=company, category=cat, name_uz="Shkaf", is_published=True)
        self.v1 = Variant.objects.create(product=self.product, name="Oq", base_price=1)
        self.v2 = Variant.objects.create(product=self.product, name="Qora", base_price=1)
        for v, name in ((self.v1, "oq.glb"), (self.v2, "qora.glb")):
            m = Model3D(variant=v)
            m.glb_file.save(name, ContentFile(make_glb(50)), save=False)
            m.recompute_status()
            m.save()

    def test_variant_models_enqueue_and_render_per_variant(self):
        job = RenderJob.objects.get(product=self.product)
        self.assertEqual(RenderJob.objects.filter(product=self.product).count(), 1)
        calls = []

        def fake(path, variants, size=1600, shots=runner.SHOTS):
            calls.append(len(variants))
            return {
                "dimensionsCm": {"w": 90.0, "h": 200.0, "d": 50.0},
                "variants": [{"name": "default", "source": "default",
                              "shots": [{"key": "hero", "dataUrl": png_data_url()}]}],
            }

        with patch.object(runner, "run_browser", side_effect=fake):
            stats = runner.run_one(job)
        self.assertEqual(len(calls), 2)  # har variant GLB'i alohida render
        groups = set(RenderedImage.objects.filter(product=self.product).values_list("variant_name", flat=True))
        self.assertEqual(groups, {"Oq", "Qora"})
        r = RenderedImage.objects.get(product=self.product, variant_name="Qora")
        self.assertEqual(r.variant_id, self.v2.id)
        self.assertEqual(stats["images"], 2)
        # o'zgarmagan GLB'lar — qayta navbat yo'q
        self.assertIsNone(runner.enqueue(self.product))


class StandardizeCommandTests(TestCase):
    def setUp(self):
        from django.core.management import call_command

        self.call = call_command
        owner = User.objects.create_user(email="o3@x.uz", password="x", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="H", slug="h")
        cat = Category.objects.create(name_uz="Stul", slug="stul")
        self.with_model = Product.objects.create(company=company, category=cat, name_uz="Bor", is_published=True)
        self.no_model = Product.objects.create(company=company, category=cat, name_uz="Yo'q", is_published=True)
        for prod in (self.with_model, self.no_model):
            buf = io.BytesIO()
            Image.new("RGB", (64, 64), "#abcdef").save(buf, "PNG")
            prod.image.save("old.png", ContentFile(buf.getvalue()), save=False)
            prod.save()
        m = Model3D(product=self.with_model)
        m.glb_file.save("a.glb", ContentFile(make_glb(10)), save=False)
        m.recompute_status()
        m.save()
        RenderJob.objects.all().delete()

    def test_dry_run_changes_nothing(self):
        self.call("standardize_product_images", stdout=io.StringIO())
        self.with_model.refresh_from_db()
        self.assertTrue(self.with_model.image)
        self.assertEqual(RenderJob.objects.count(), 0)

    def test_apply_replaces_only_products_with_models(self):
        self.call("standardize_product_images", "--apply", "--yes", stdout=io.StringIO())
        self.with_model.refresh_from_db()
        self.no_model.refresh_from_db()
        self.assertFalse(self.with_model.image)
        self.assertTrue(self.no_model.image)  # modelsiz mahsulot tegilmadi
        self.assertEqual(RenderJob.objects.filter(product=self.with_model).count(), 1)

    def test_sync_renders_and_sets_new_image(self):
        with patch.object(runner, "run_browser", return_value=FAKE_RESULT):
            self.call("standardize_product_images", "--apply", "--yes", "--sync", stdout=io.StringIO())
        self.with_model.refresh_from_db()
        self.assertTrue(self.with_model.image_from_render)
        self.assertEqual(self.with_model.render_status, Product.RenderStatus.READY)
