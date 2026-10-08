from datetime import timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company
from apps.products.models import Category, Product, Variant

from .models import OrderItem

User = get_user_model()


class OrderPriceSnapshotTests(APITestCase):
    def setUp(self):
        owner = User.objects.create_user(email="o@x.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="Shop", slug="shop")
        category = Category.objects.create(name_uz="Stullar", slug="stullar")
        self.product = Product.objects.create(company=company, category=category, name_uz="Stul", is_published=True)
        self.variant = Variant.objects.create(
            product=self.product, name="oddiy", base_price=Decimal("5000000"),
            discount_percent=Decimal("20"), discount_ends_at=timezone.now() + timedelta(days=2),
        )
        self.customer = User.objects.create_user(email="c@x.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.client = APIClient()
        self.client.force_authenticate(self.customer)

    def _order(self, **extra):
        item = {"variant": str(self.variant.id), "width": "1", "height": "1", "depth": "1", "quantity": 2}
        item.update(extra)
        return self.client.post("/api/v1/orders/", {"items": [item], **{k: v for k, v in extra.items() if k.startswith("_")}}, format="json")

    def test_snapshot_fields_are_calculated_by_backend(self):
        resp = self._order()
        self.assertEqual(resp.status_code, 201, resp.data)
        item = OrderItem.objects.get()
        self.assertEqual(item.original_unit_m3_price, Decimal("5000000.00"))
        self.assertEqual(item.unit_m3_price, Decimal("4000000.00"))
        self.assertEqual(item.discount_amount, Decimal("2000000.00"))  # (5M-4M) * 2 dona
        self.assertEqual(item.subtotal, Decimal("8000000.00"))
        self.assertEqual(resp.data["total_price"], "8000000.00")

    def test_client_supplied_prices_are_ignored(self):
        resp = self.client.post(
            "/api/v1/orders/",
            {
                "items": [{
                    "variant": str(self.variant.id), "width": "1", "height": "1", "depth": "1", "quantity": 1,
                    "price": 1, "unit_m3_price": 1, "final_price": 1, "discount_percent": 99, "subtotal": 1,
                }],
                "total_price": 1,
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        item = OrderItem.objects.get()
        self.assertEqual(item.unit_m3_price, Decimal("4000000.00"))
        self.assertEqual(item.subtotal, Decimal("4000000.00"))

    def test_old_order_price_stays_after_product_price_or_discount_changes(self):
        self._order()
        self.variant.base_price = Decimal("9000000")
        self.variant.discount_percent = Decimal("0")
        self.variant.save()
        item = OrderItem.objects.get()
        self.assertEqual(item.unit_m3_price, Decimal("4000000.00"))
        self.assertEqual(item.subtotal, Decimal("8000000.00"))
        # Yangi buyurtma esa yangi narxda
        self._order()
        newest = OrderItem.objects.order_by("-created_at").first()
        self.assertEqual(newest.unit_m3_price, Decimal("9000000.00"))
        self.assertEqual(newest.discount_amount, Decimal("0.00"))

    def test_expired_discount_is_not_applied(self):
        self.variant.discount_ends_at = timezone.now() - timedelta(minutes=1)
        self.variant.save()
        self._order()
        item = OrderItem.objects.get()
        self.assertEqual(item.unit_m3_price, Decimal("5000000.00"))
        self.assertEqual(item.discount_amount, Decimal("0.00"))
