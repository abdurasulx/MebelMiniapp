from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company
from apps.inventory.models import ManufacturedUnit, ProductMovement, ProductStock, Warehouse
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

    def test_unverified_phone_cannot_create_order(self):
        """Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
        foydalanuvchi (`phone_verified=False`) buyurtma bera olmasligi kerak."""
        self.customer.phone_verified = False
        self.customer.save(update_fields=["phone_verified"])
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
        self.assertEqual(resp.status_code, 403)
        self.assertEqual(Order.objects.count(), 0)

    def test_stranger_cannot_touch_order(self):
        # Boshqa mijozning queryset'ida bu buyurtma umuman ko'rinmaydi, shuning
        # uchun 403 emas 404 qaytadi (mavjudligini ham tasdiqlamaydi).
        order = self._create_order()
        stranger = User.objects.create_user(email="stranger@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.client.force_authenticate(stranger)
        resp = self.client.post(f"/api/v1/orders/{order.id}/set_status/", {"status": "cancelled"}, format="json")
        self.assertEqual(resp.status_code, 404)


class StockOrderFulfillmentTests(APITestCase):
    """"Market buyurtmasi berilishi ≠ ombordan chiqim" tamoyili — buyurtma
    yaratilishi hech qanday holatda ombor qoldig'iga tegmaydi, chiqim
    faqat firma `confirm_sold_from_stock` orqali aniq tasdiqlaganda
    yaratiladi (docs "Market buyurtmasi va ombor prinsipi")."""

    def setUp(self):
        self.owner, self.company, self.product, self.variant, self.customer = make_company_with_product()
        self.client = APIClient()
        self.warehouse = Warehouse.objects.create(
            company=self.company, name="Asosiy", kind=Warehouse.Kind.FINISHED_GOODS, address="Toshkent"
        )

    def _make_units(self, n):
        for _ in range(n):
            ManufacturedUnit.objects.create(
                product=self.product, variant=self.variant, warehouse=self.warehouse,
                material_cost=Decimal("10000"), labor_cost=Decimal("5000"),
            )
        ProductStock.objects.update_or_create(
            warehouse=self.warehouse, product=self.product, variant=self.variant,
            defaults={"quantity": Decimal(n)},
        )

    def _create_order(self, quantity=1):
        self.client.force_authenticate(self.customer)
        resp = self.client.post(
            "/api/v1/orders/",
            {
                "phone": "+998900000000",
                "address": "Toshkent",
                "items": [
                    {"variant": str(self.variant.id), "width": "1", "height": "1", "depth": "1", "quantity": quantity}
                ],
            },
            format="json",
        )
        return Order.objects.get(pk=resp.data["id"])

    def test_order_creation_never_touches_stock(self):
        self._make_units(5)
        self._create_order(quantity=1)
        self.assertEqual(
            ManufacturedUnit.objects.filter(status=ManufacturedUnit.Status.IN_STOCK).count(), 5
        )
        self.assertEqual(ProductMovement.objects.count(), 0)

    def test_confirm_sold_from_stock_deducts_and_links_units(self):
        self._make_units(5)
        order = self._create_order(quantity=2)
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/orders/{order.id}/confirm_sold_from_stock/", format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.READY)
        self.assertEqual(
            ManufacturedUnit.objects.filter(status=ManufacturedUnit.Status.SOLD, order=order).count(), 2
        )
        self.assertEqual(
            ManufacturedUnit.objects.filter(status=ManufacturedUnit.Status.IN_STOCK).count(), 3
        )
        movement = ProductMovement.objects.get()
        self.assertEqual(movement.source_order_id, order.id)
        self.assertEqual(movement.quantity, 2)
        self.assertEqual(movement.movement_type, ProductMovement.Type.OUT)
        stock = ProductStock.objects.get(warehouse=self.warehouse, product=self.product, variant=self.variant)
        self.assertEqual(stock.quantity, Decimal("3"))

    def test_confirm_sold_rejected_when_insufficient_stock(self):
        self._make_units(1)
        order = self._create_order(quantity=3)
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/orders/{order.id}/confirm_sold_from_stock/", format="json")
        self.assertEqual(resp.status_code, 400)
        order.refresh_from_db()
        self.assertEqual(order.status, Order.Status.NEW)
        self.assertEqual(
            ManufacturedUnit.objects.filter(status=ManufacturedUnit.Status.IN_STOCK).count(), 1
        )
        self.assertEqual(ProductMovement.objects.count(), 0)

    def test_customer_cannot_confirm_sold(self):
        self._make_units(5)
        order = self._create_order(quantity=1)
        self.client.force_authenticate(self.customer)
        resp = self.client.post(f"/api/v1/orders/{order.id}/confirm_sold_from_stock/", format="json")
        self.assertEqual(resp.status_code, 403)

    def test_stock_availability_endpoint_reports_per_item(self):
        self._make_units(1)
        order = self._create_order(quantity=3)
        self.client.force_authenticate(self.owner)
        resp = self.client.get(f"/api/v1/orders/{order.id}/stock_availability/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data[0]["available"], 1)
        self.assertEqual(resp.data[0]["requested"], 3)
        self.assertFalse(resp.data[0]["sufficient"])


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
