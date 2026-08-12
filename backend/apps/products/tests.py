import io

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company

from .imaging import compute_signature, distance
from .models import Category, Product

User = get_user_model()


def make_test_image(color):
    buf = io.BytesIO()
    Image.new("RGB", (40, 40), color).save(buf, format="PNG")
    buf.seek(0)
    return buf


class ImagingTests(APITestCase):
    def test_identical_colors_have_zero_distance(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((200, 30, 30)))
        self.assertEqual(distance(sig_a, sig_b), 0)

    def test_different_colors_have_positive_distance(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((10, 10, 200)))
        self.assertGreater(distance(sig_a, sig_b), 0)

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
        resp = client.post("/api/v1/products/search-by-image/", {"image": query}, format="multipart")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertGreaterEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]["id"], str(red.id))
