from django.test import TestCase
from rest_framework.test import APIClient

from apps.users.models import User

from .models import ShowcaseProduct


class ShowcaseApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_user(
            email="admin@example.com", password="x", role=User.Role.PLATFORM_ADMIN
        )
        self.customer = User.objects.create_user(
            email="c@example.com", password="x", role=User.Role.CUSTOMER
        )
        self.published = ShowcaseProduct.objects.create(
            name={"uz": "Divan", "ru": "Диван", "en": "Sofa"},
            description={"uz": "Yumshoq divan"},
            price_from=1500000,
        )
        self.draft = ShowcaseProduct.objects.create(name={"uz": "Qoralama"}, is_published=False)

    def _names(self, resp):
        data = resp.json()
        rows = data["results"] if isinstance(data, dict) and "results" in data else data
        return {r["name"] for r in rows}

    def test_public_sees_only_published_in_requested_language(self):
        resp = self.client.get("/api/v1/showcase/products/?lang=ru")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(self._names(resp), {"Диван"})

    def test_falls_back_to_uzbek_when_translation_missing(self):
        resp = self.client.get("/api/v1/showcase/products/?lang=de")
        self.assertEqual(self._names(resp), {"Divan"})
        resp = self.client.get("/api/v1/showcase/products/?lang=xx")
        self.assertEqual(self._names(resp), {"Divan"})

    def test_description_falls_back_per_language(self):
        resp = self.client.get(f"/api/v1/showcase/products/{self.published.id}/?lang=en")
        self.assertEqual(resp.json()["description"], "Yumshoq divan")
        self.assertEqual(resp.json()["name"], "Sofa")

    def test_customer_cannot_write(self):
        self.client.force_authenticate(self.customer)
        resp = self.client.post(
            "/api/v1/showcase/products/",
            {"name_translations": {"uz": "X"}},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_admin_creates_and_sees_drafts(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(
            "/api/v1/showcase/products/",
            {"name_translations": {"uz": "Stol", "ru": "Стол"}, "price_from": "900000"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.content)
        listing = self.client.get("/api/v1/showcase/products/?lang=uz")
        self.assertIn("Qoralama", self._names(listing))

    def test_uzbek_name_required(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(
            "/api/v1/showcase/products/", {"name_translations": {"ru": "Стол"}}, format="json"
        )
        self.assertEqual(resp.status_code, 400)

    def test_unknown_language_code_rejected(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(
            "/api/v1/showcase/products/",
            {"name_translations": {"uz": "Stol", "zz": "?"}},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_delete_hides_product(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.delete(f"/api/v1/showcase/products/{self.published.id}/")
        self.assertEqual(resp.status_code, 204)
        listing = self.client.get("/api/v1/showcase/products/")
        self.assertNotIn("Divan", self._names(listing))
