from decimal import Decimal

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from rest_framework.test import APIClient, APITestCase

from apps.products.models import Category, Product, Variant

from .models import Company, CompanyDeliverySettings

User = get_user_model()


class CompanyFixtureMixin:
    def setUp(self):
        self.owner = User.objects.create_user(email="own@x.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.other_owner = User.objects.create_user(email="own2@x.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.admin = User.objects.create_user(email="adm@x.uz", password="pass12345", role=User.Role.PLATFORM_ADMIN)
        self.customer = User.objects.create_user(email="cus@x.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.company = Company.objects.create(owner=self.owner, name="Mebel House", slug="mebel-house")
        self.client = APIClient()


class CompanyVerificationTests(CompanyFixtureMixin, APITestCase):
    def url(self):
        return f"/api/v1/companies/{self.company.slug}/verify/"

    def test_default_not_verified_and_exposed_read_only(self):
        self.assertFalse(self.company.is_verified)
        self.assertIsNone(self.company.verified_at)
        data = self.client.get(f"/api/v1/companies/{self.company.slug}/").json()
        self.assertIs(data["is_verified"], False)
        self.assertIsNone(data["verified_at"])

    def test_admin_verifies_and_unverifies(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(self.url(), {"is_verified": True}, format="json")
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertIs(resp.json()["is_verified"], True)
        self.company.refresh_from_db()
        self.assertTrue(self.company.is_verified)
        self.assertIsNotNone(self.company.verified_at)

        resp = self.client.post(self.url(), {"is_verified": False}, format="json")
        self.assertEqual(resp.status_code, 200)
        self.company.refresh_from_db()
        self.assertFalse(self.company.is_verified)
        self.assertIsNone(self.company.verified_at)

    def test_non_admins_cannot_verify(self):
        for user in (self.owner, self.other_owner, self.customer):
            self.client.force_authenticate(user)
            resp = self.client.post(self.url(), {"is_verified": True}, format="json")
            self.assertEqual(resp.status_code, 403, user.email)
        self.client.force_authenticate(None)
        self.assertIn(self.client.post(self.url(), {"is_verified": True}, format="json").status_code, (401, 403))
        self.company.refresh_from_db()
        self.assertFalse(self.company.is_verified)

    def test_is_verified_cannot_be_changed_through_normal_update(self):
        for user in (self.owner, self.admin):
            self.client.force_authenticate(user)
            resp = self.client.patch(
                f"/api/v1/companies/{self.company.slug}/",
                {"is_verified": True, "verified_at": "2020-01-01T00:00:00Z", "description": "yangi"},
                format="json",
            )
            self.assertEqual(resp.status_code, 200, resp.content)
        self.company.refresh_from_db()
        self.assertEqual(self.company.description, "yangi")
        self.assertFalse(self.company.is_verified)
        self.assertIsNone(self.company.verified_at)

    def test_model_keeps_verified_at_in_sync(self):
        self.company.is_verified = True
        self.company.save()
        self.assertIsNotNone(self.company.verified_at)
        self.company.is_verified = False
        self.company.save()
        self.assertIsNone(self.company.verified_at)

    def test_product_payload_exposes_company_verification(self):
        category = Category.objects.create(name_uz="Divanlar", slug="d")
        product = Product.objects.create(company=self.company, category=category, name_uz="X", is_published=True)
        Variant.objects.create(product=product, name="o", base_price=Decimal("1000"))
        self.company.set_verified(True)
        data = self.client.get(f"/api/v1/products/{product.id}/").json()
        self.assertIs(data["company_is_verified"], True)


class CompanyDeliveryTests(CompanyFixtureMixin, APITestCase):
    def url(self):
        return f"/api/v1/companies/{self.company.slug}/delivery/"

    def test_unconfigured_company_returns_null_not_fake_defaults(self):
        self.assertIsNone(self.client.get(self.url()).json())
        self.assertIsNone(self.client.get(f"/api/v1/companies/{self.company.slug}/").json()["delivery"])

    def test_owner_sets_valid_delivery_settings(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.put(
            self.url(), {"free": False, "price": "30000", "min_days": 2, "max_days": 4}, format="json"
        )
        self.assertEqual(resp.status_code, 200, resp.content)
        self.assertEqual(resp.json(), {"free": False, "price": 30000.0, "min_days": 2, "max_days": 4})
        # Hamma o'qiy oladi
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(self.url()).json()["price"], 30000.0)
        self.assertEqual(
            self.client.get(f"/api/v1/companies/{self.company.slug}/").json()["delivery"]["max_days"], 4
        )

    def test_free_delivery_forces_price_zero(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.put(self.url(), {"free": True, "price": "50000", "min_days": 1, "max_days": 2}, format="json")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {"free": True, "price": 0.0, "min_days": 1, "max_days": 2})
        self.assertEqual(CompanyDeliverySettings.objects.get().delivery_price, 0)

    def test_negative_price_is_rejected(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.put(self.url(), {"price": "-1", "min_days": 1, "max_days": 2}, format="json")
        self.assertEqual(resp.status_code, 400)

    def test_min_days_greater_than_max_days_is_rejected(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.put(self.url(), {"price": "1000", "min_days": 5, "max_days": 2}, format="json")
        self.assertEqual(resp.status_code, 400)
        self.assertFalse(CompanyDeliverySettings.objects.exists())

    def test_model_level_validation(self):
        bad = CompanyDeliverySettings(company=self.company, delivery_price=Decimal("-5"), delivery_min_days=3, delivery_max_days=1)
        with self.assertRaises(ValidationError):
            bad.full_clean()

    def test_only_owner_or_admin_can_write(self):
        payload = {"price": "1000", "min_days": 1, "max_days": 2}
        for user in (self.other_owner, self.customer):
            self.client.force_authenticate(user)
            self.assertEqual(self.client.put(self.url(), payload, format="json").status_code, 403, user.email)
        self.client.force_authenticate(None)
        self.assertIn(self.client.put(self.url(), payload, format="json").status_code, (401, 403))
        self.assertFalse(CompanyDeliverySettings.objects.exists())
        self.client.force_authenticate(self.admin)
        self.assertEqual(self.client.put(self.url(), payload, format="json").status_code, 200)

    def test_partial_update_keeps_other_fields(self):
        self.client.force_authenticate(self.owner)
        self.client.put(self.url(), {"price": "30000", "min_days": 2, "max_days": 4}, format="json")
        resp = self.client.patch(self.url(), {"price": "45000"}, format="json")
        self.assertEqual(resp.json(), {"free": False, "price": 45000.0, "min_days": 2, "max_days": 4})
        # patch bilan min > max qilib bo'lmaydi
        self.assertEqual(self.client.patch(self.url(), {"min_days": 9}, format="json").status_code, 400)

    def test_product_payload_includes_company_delivery(self):
        category = Category.objects.create(name_uz="Divanlar", slug="d")
        product = Product.objects.create(company=self.company, category=category, name_uz="X", is_published=True)
        Variant.objects.create(product=product, name="o", base_price=Decimal("1000"))
        self.assertIsNone(self.client.get(f"/api/v1/products/{product.id}/").json()["delivery"])
        CompanyDeliverySettings.objects.create(
            company=self.company, delivery_price=Decimal("30000"), delivery_min_days=2, delivery_max_days=4
        )
        data = self.client.get(f"/api/v1/products/{product.id}/").json()
        self.assertEqual(data["delivery"], {"free": False, "price": 30000.0, "min_days": 2, "max_days": 4})
