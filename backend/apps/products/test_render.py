"""3D ko'rinishdan skrin olish (sotuvchi brauzeri) -> server qabul qilish/standartlash API testlari."""
import io
import json
import struct

from django.core.files.base import ContentFile
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image
from rest_framework.test import APIClient

from apps.assets.models import Model3D
from apps.companies.models import Company
from apps.users.models import User

from .models import Category, Product, ProductImage, RenderedImage, Variant
from .rendering import imaging, store


def tiny_glb() -> bytes:
    js = json.dumps({"asset": {"version": "2.0"}}).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<I4s", len(js), b"JSON") + js
    return b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body


def png_upload(color="#336699", size=(800, 800), name="shot.png"):
    buf = io.BytesIO()
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    im.paste(Image.new("RGBA", (400, 300), color), (200, 250))
    im.save(buf, "PNG")
    return SimpleUploadedFile(name, buf.getvalue(), content_type="image/png")


class ImagingTests(TestCase):
    def test_normalize_fills_85_percent_and_keeps_alpha(self):
        im = Image.new("RGBA", (800, 800), (0, 0, 0, 0))
        im.paste(Image.new("RGBA", (200, 100), (255, 0, 0, 255)), (100, 300))
        out = imaging.normalize_square(im, 1600)
        self.assertEqual(out.size, (1600, 1600))
        bbox = out.getchannel("A").getbbox()
        self.assertAlmostEqual((bbox[2] - bbox[0]) / 1600, 0.85, delta=0.01)
        self.assertEqual(out.getpixel((5, 5))[3], 0)

    def test_encode_formats(self):
        im = Image.new("RGBA", (1600, 1600), (10, 20, 30, 255))
        for fmt in ("webp", "avif", "png"):
            self.assertGreater(len(imaging.encode(im, 400, fmt)), 50)


class ClientRenderApiTests(TestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@x.uz", password="x", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=owner, name="F", slug="f")
        cat = Category.objects.create(name_uz="Stol", slug="stol")
        self.product = Product.objects.create(company=self.company, category=cat, name_uz="Stol", is_published=True)
        self.v1 = Variant.objects.create(
            product=self.product, name="Oq", base_price=1000, width=0.8, height=0.75, depth=0.4
        )
        self.v2 = Variant.objects.create(product=self.product, name="Qora", base_price=1000)
        self.client = APIClient()
        self.client.force_authenticate(owner)
        self.url = f"/api/v1/products/{self.product.id}"

    def _shot(self, shot, variant=None, name=None, **kw):
        data = {"image": png_upload(**kw), "shot": shot}
        if variant:
            data["variant"] = str(variant.id)
        if name:
            data["variant_name"] = name
        return self.client.post(f"{self.url}/render-image/", data, format="multipart")

    def test_upload_shots_complete_and_expose_renders(self):
        for variant in (self.v1, self.v2):
            for shot in ("front", "hero"):
                resp = self._shot(shot, variant)
                self.assertEqual(resp.status_code, 200, resp.content)
        done = self.client.post(
            f"{self.url}/render-complete/",
            {"dimensions_cm": {"w": 80, "h": 75, "d": 40}},
            format="json",
        )
        self.assertEqual(done.status_code, 200, done.content)
        data = done.json()
        self.assertEqual(data["render_status"], "ready")
        self.assertEqual(data["model_dims_cm"], {"w": 80.0, "h": 75.0, "d": 40.0})
        self.assertFalse(data["needs_moderation"])
        self.assertEqual(sorted(g["variant"] for g in data["renders"]), ["Oq", "Qora"])
        for g in data["renders"]:
            self.assertEqual([s["key"] for s in g["shots"]], ["hero", "front"])  # hero har doim birinchi
            self.assertEqual(set(g["shots"][0]["urls"]), {"400", "800", "1600"})
            self.assertEqual(set(g["shots"][0]["urls"]["400"]), {"webp", "avif"})
        self.product.refresh_from_db()
        self.assertTrue(self.product.image_from_render)  # birinchi variant hero'si asosiy rasm

    def test_resend_replaces_shot(self):
        self._shot("hero", self.v1)
        self._shot("hero", self.v1, color="#aa0000")
        self.assertEqual(RenderedImage.objects.filter(product=self.product, shot="hero").count(), 1)

    def test_old_gallery_is_hidden_on_complete(self):
        gi = ProductImage.objects.create(product=self.product)
        gi.image.save("old.png", ContentFile(png_upload().read()), save=True)
        self._shot("hero", self.v1)
        self.client.post(f"{self.url}/render-complete/", {}, format="json")
        gi.refresh_from_db()
        self.assertTrue(gi.is_deleted)

    def test_dimension_mismatch_flags_moderation(self):
        self._shot("hero", self.v1)
        done = self.client.post(
            f"{self.url}/render-complete/", {"dimensions_cm": {"w": 150, "h": 75, "d": 40}}, format="json"
        )
        self.assertTrue(done.json()["needs_moderation"])
        self.assertIn("farq", done.json()["moderation_note"])

    def test_validation_errors(self):
        self.assertEqual(self._shot("diagonal", self.v1).status_code, 400)
        bad = SimpleUploadedFile("x.png", b"not an image", content_type="image/png")
        resp = self.client.post(
            f"{self.url}/render-image/", {"image": bad, "shot": "hero"}, format="multipart"
        )
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(self.client.post(f"{self.url}/render-complete/", {}, format="json").status_code, 400)

    def test_stranger_cannot_upload(self):
        stranger = User.objects.create_user(email="s@x.uz", password="x", role=User.Role.CUSTOMER)
        self.client.force_authenticate(stranger)
        self.assertEqual(self._shot("hero", self.v1).status_code, 403)

    def test_render_stale_follows_glb_files(self):
        self.assertFalse(self.client.get(f"{self.url}/").json()["render_stale"])  # GLB yo'q
        m = Model3D(variant=self.v1)
        m.glb_file.save("a.glb", ContentFile(tiny_glb()), save=False)
        m.recompute_status()
        m.save()
        self.assertTrue(self.client.get(f"{self.url}/").json()["render_stale"])
        self._shot("hero", self.v1)
        self.client.post(f"{self.url}/render-complete/", {}, format="json")
        self.assertFalse(self.client.get(f"{self.url}/").json()["render_stale"])
        m.glb_file.save("b.glb", ContentFile(tiny_glb()), save=True)  # fayl almashdi
        self.assertTrue(self.client.get(f"{self.url}/").json()["render_stale"])

    def test_stale_when_variant_with_own_model_has_no_render(self):
        """Ikkala variantning modeli bor, lekin render faqat bittasi uchun olingan -> qayta olinadi."""
        for v, fname in ((self.v1, "a.glb"), (self.v2, "b.glb")):
            m = Model3D(variant=v)
            m.glb_file.save(fname, ContentFile(tiny_glb()), save=False)
            m.recompute_status()
            m.save()
        self._shot("hero", self.v1)
        self.client.post(f"{self.url}/render-complete/", {}, format="json")
        self.assertTrue(self.client.get(f"{self.url}/").json()["render_stale"])  # v2 rasmi yo'q
        self._shot("hero", self.v2)
        self.client.post(f"{self.url}/render-complete/", {}, format="json")
        self.assertFalse(self.client.get(f"{self.url}/").json()["render_stale"])

    def test_only_admin_approves_moderation(self):
        self.product.needs_moderation = True
        self.product.save()
        self.assertEqual(self.client.post(f"{self.url}/approve-moderation/").status_code, 403)
        admin = User.objects.create_user(email="a@x.uz", password="x", role=User.Role.PLATFORM_ADMIN)
        self.client.force_authenticate(admin)
        resp = self.client.post(f"{self.url}/approve-moderation/")
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.json()["needs_moderation"])


class AbsoluteUrlTests(ClientRenderApiTests):
    def test_render_urls_are_absolute(self):
        self._shot("hero", self.v1)
        self.client.post(f"{self.url}/render-complete/", {}, format="json")
        data = self.client.get(f"{self.url}/").json()
        url = data["renders"][0]["shots"][0]["urls"]["400"]["webp"]
        self.assertTrue(url.startswith("http"), url)
