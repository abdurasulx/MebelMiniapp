from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company
from apps.products.models import Category, Product, Variant

from .models import Order

User = get_user_model()


def make_company_with_product():
    owner = User.objects.create_user(email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
    company = Company.objects.create(owner=owner, name="Shop", slug="shop")
    category = Category.objects.create(name_uz="Stullar", slug="stullar")
    product = Product.objects.create(
        company=company, category=category, name_uz="Stul", is_published=True
    )
    variant = Variant.objects.create(product=product, name="oddiy", base_price=Decimal("100000"))
    customer = User.objects.create_user(email="mijoz@test.uz", password="pass12345", role=User.Role.CUSTOMER)
    return owner, company, product, variant, customer


class OrderFlowTests(APITestCase):
    def setUp(self):
        self.owner, self.company, self.product, self.variant, self.customer = make_company_with_product()
        self.client = APIClient()

    def test_customer_creates_order_with_computed_total(self):
        self.client.force_authenticate(self.customer)
        resp = self.client.post(
            "/api/v1/orders/",
            {
                "phone": "+998900000000",
                "address": "Toshkent",
                "items": [
                    {"variant": str(self.variant.id), "width": "1", "height": "1", "depth": "1", "quantity": 2}
                ],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        order = Order.objects.get(pk=resp.data["id"])
        self.assertEqual(order.total_price, Decimal("200000.00"))
        self.assertEqual(order.status, Order.Status.NEW)

    def _create_order(self):
        self.client.force_authenticate(self.customer)
        resp = self.client.post(
            "/api/v1/orders/",
            {
                "phone": "+998900000000",
                "address": "Toshkent",
                "items": [
                    {"variant": str(self.variant.id), "width": "1", "height": "1", "depth": "1", "quantity": 1}
                ],
            },
            format="json",
        )
        return Order.objects.get(pk=resp.data["id"])

    def test_customer_can_only_cancel_new_order(self):
        order = self._create_order()
        self.client.force_authenticate(self.customer)
        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "accepted"}, format="json")
        self.assertEqual(resp.status_code, 400)

        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "cancelled"}, format="json")
        self.assertEqual(resp.status_code, 200)

    def test_company_owner_follows_transition_graph(self):
        order = self._create_order()
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "ready"}, format="json")
        self.assertEqual(resp.status_code, 400)

        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "accepted"}, format="json")
        self.assertEqual(resp.status_code, 200)

    def test_stranger_cannot_touch_order(self):
        # Boshqa mijozning queryset'ida bu buyurtma umuman ko'rinmaydi, shuning
        # uchun 403 emas 404 qaytadi (mavjudligini ham tasdiqlamaydi).
        order = self._create_order()
        stranger = User.objects.create_user(email="stranger@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.client.force_authenticate(stranger)
        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "cancelled"}, format="json")
        self.assertEqual(resp.status_code, 404)


class FinanceSummaryTests(APITestCase):
    def setUp(self):
        self.owner, self.company, self.product, self.variant, self.customer = make_company_with_product()
        self.client = APIClient()

    def test_owner_sees_company_scope(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/finance/summary/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["scope"], "company")

    def test_platform_admin_sees_platform_scope(self):
        admin = User.objects.create_user(
            email="admin@test.uz", password="pass12345", role=User.Role.PLATFORM_ADMIN
        )
        self.client.force_authenticate(admin)
        resp = self.client.get("/api/v1/finance/summary/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["scope"], "platform")
        self.assertIn("top_companies", resp.data)

    def test_non_company_customer_forbidden(self):
        self.client.force_authenticate(self.customer)
        resp = self.client.get("/api/v1/finance/summary/")
        self.assertEqual(resp.status_code, 403)
