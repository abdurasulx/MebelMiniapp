import io

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company

from .imaging import compute_signature, similarity_percent
from .models import Category, Product

User = get_user_model()


def make_test_image(color, size=(40, 40)):
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="PNG")
    buf.seek(0)
    return buf


def make_transparent_image(color, alpha=255):
    """RGBA PNG — 3D-render eksportlarida keng tarqalgan shaffof fon."""
    buf = io.BytesIO()
    Image.new("RGBA", (40, 40), (*color, alpha)).save(buf, format="PNG")
    buf.seek(0)
    return buf


def make_split_image(left_color, right_color, size=(60, 60)):
    """Chapi va o'ngi boshqa rangdagi rasm — dHash (shakl/gradient) signalini
    sinash uchun (bir xil o'rtacha rangda ham chegara joyi farq qiladi)."""
    buf = io.BytesIO()
    img = Image.new("RGB", size, left_color)
    for x in range(size[0] // 2, size[0]):
        for y in range(size[1]):
            img.putpixel((x, y), right_color)
    img.save(buf, format="PNG")
    buf.seek(0)
    return buf


class ImagingTests(APITestCase):
    def test_identical_colors_are_100_percent_similar(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((200, 30, 30)))
        self.assertEqual(similarity_percent(sig_a, sig_b), 100.0)

    def test_different_colors_are_less_similar(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((10, 10, 200)))
        same = similarity_percent(sig_a, sig_a)
        different = similarity_percent(sig_a, sig_b)
        self.assertLess(different, same)

    def test_same_average_color_but_different_layout_is_less_similar(self):
        """Gistogramma yolg'iz o'zi bo'lganda ikkalasi ham "yashil" deb bir
        xil chiqishi mumkin edi — dHash shakl/chegara farqini ushlab, bularni
        ajratishi kerak."""
        split_a = compute_signature(make_split_image((255, 0, 0), (0, 255, 0)))
        split_b = compute_signature(make_split_image((0, 255, 0), (255, 0, 0)))  # teskari
        solid_green = compute_signature(make_test_image((128, 128, 0)))  # o'rtacha rang bir xil

        self.assertLess(similarity_percent(split_a, split_b), 100.0)
        self.assertLess(similarity_percent(split_a, solid_green), 100.0)

    def test_transparent_background_is_composited_onto_white_not_black(self):
        """Regressiya: mebel rasmlari ko'pincha shaffof fonli (3D-render
        eksporti) PNG bo'ladi. `.convert("RGB")` shaffof qismlarni to'g'ridan
        -to'g'ri qora qilib qo'yar edi — natijada bir xil ko'rinadigan (oq
        fonli) ikkita rasm ham (biri shaffof, biri haqiqiy oq) mutlaqo
        boshqa-boshqa signature olardi va qidiruv noto'g'ri natija berardi."""
        opaque_white_sig = compute_signature(make_test_image((255, 255, 255)))
        transparent_sig = compute_signature(make_transparent_image((255, 255, 255), alpha=0))
        self.assertEqual(similarity_percent(opaque_white_sig, transparent_sig), 100.0)
        # Qora bilan chalkashmasligini alohida ham tasdiqlaymiz.
        opaque_black_sig = compute_signature(make_test_image((0, 0, 0)))
        self.assertLess(similarity_percent(opaque_black_sig, transparent_sig), 100.0)

    def test_search_by_image_ranks_closest_first(self):
        owner = User.objects.create_user(email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="Shop", slug="shop")
        category = Category.objects.create(name_uz="Stullar", slug="stullar")

        red = Product.objects.create(
            company=company, category=category, name_uz="Qizil stul", is_published=True,
            image=SimpleUploadedFile("red.png", make_test_image((220, 20, 20)).read(), content_type="image/png"),
        )
        blue = Product.objects.create(
            company=company, category=category, name_uz="Ko'k stul", is_published=True,
            image=SimpleUploadedFile("blue.png", make_test_image((20, 20, 220)).read(), content_type="image/png"),
        )
        self.assertIsNotNone(Product.objects.get(pk=red.pk).image_signature)
        self.assertIsNotNone(Product.objects.get(pk=blue.pk).image_signature)

        query = SimpleUploadedFile(
            "query.png", make_test_image((230, 15, 15)).read(), content_type="image/png"
        )
        client = APIClient()
        resp = client.post(
            "/api/v1/products/search-by-image/", {"image": query, "min_similarity": 0}, format="multipart"
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertGreaterEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]["id"], str(red.id))
