from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.assets.models import Model3D
from apps.companies.models import Company, Employee, TariffPlan
from apps.products.models import Category, Product

User = get_user_model()


class TariffPlanTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            email="admin@platform.uz", password="pass12345", role=User.Role.PLATFORM_ADMIN
        )
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.plan = TariffPlan.objects.create(
            name="Standart", price_per_employee=Decimal("1.00"), price_per_product=Decimal("1.00")
        )
        self.client = APIClient()

    def test_owner_cannot_create_tariff_plan(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/tariff-plans/",
            {"name": "Firma o'zi", "price_per_employee": "5.00", "price_per_product": "5.00"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_admin_can_create_and_owner_can_list(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(
            "/api/v1/tariff-plans/",
            {"name": "Premium", "price_per_employee": "2.00", "price_per_product": "2.00"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)

        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/tariff-plans/")
        self.assertEqual(resp.status_code, 200)
        names = {p["name"] for p in resp.data["results"]}
        self.assertIn("Standart", names)
        self.assertIn("Premium", names)

    def test_inactive_plan_hidden_from_owner_but_visible_to_admin(self):
        TariffPlan.objects.create(name="Eskirgan", is_active=False)

        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/tariff-plans/")
        names = {p["name"] for p in resp.data["results"]}
        self.assertNotIn("Eskirgan", names)

        self.client.force_authenticate(self.admin)
        resp = self.client.get("/api/v1/tariff-plans/")
        names = {p["name"] for p in resp.data["results"]}
        self.assertIn("Eskirgan", names)

    def test_owner_selects_plan_for_own_company(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.patch(f"/api/v1/companies/{self.company.slug}/", {"tariff_plan": str(self.plan.id)})
        self.assertEqual(resp.status_code, 200, resp.data)
        self.company.refresh_from_db()
        self.assertEqual(self.company.tariff_plan_id, self.plan.id)

    def test_billing_summary_counts_employees_and_products_with_3d(self):
        self.company.tariff_plan = self.plan
        self.company.save(update_fields=["tariff_plan"])

        worker = User.objects.create_user(email="worker@shop.uz", password="pass12345")
        Employee.objects.create(company=self.company, user=worker, positions=["usta"], is_active=True)

        category = Category.objects.create(name_uz="Stullar", slug="stullar")
        product_with_3d = Product.objects.create(company=self.company, category=category, name_uz="3D li stul")
        Product.objects.create(company=self.company, category=category, name_uz="3D siz stol")
        Model3D.objects.create(product=product_with_3d, status="ready")

        summary = self.company.billing_summary
        self.assertEqual(summary["employee_count"], 1)
        self.assertEqual(summary["product_count"], 1)
        self.assertEqual(summary["total"], Decimal("2.00"))
        self.assertEqual(summary["plan"]["name"], "Standart")

    def test_billing_summary_without_plan_has_no_total(self):
        summary = self.company.billing_summary
        self.assertIsNone(summary["plan"])
        self.assertIsNone(summary["total"])
