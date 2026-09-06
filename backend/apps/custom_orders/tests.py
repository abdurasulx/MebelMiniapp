from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee, PayType
from apps.orders.models import Order
from apps.products.models import Category, Product, Variant

from .models import Design

User = get_user_model()


def make_company_with_usta():
    owner = User.objects.create_user(email="owner@custom.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
    company = Company.objects.create(owner=owner, name="Custom Shop", slug="custom-shop")
    usta_user = User.objects.create_user(
        email="usta@custom.uz", password="pass12345", role=User.Role.EMPLOYEE, worker_id="USTA001"
    )
    Employee.objects.create(
        company=company, user=usta_user, positions=["usta"], pay_type=PayType.FIXED, base_salary=Decimal("1000000")
    )
    customer = User.objects.create_user(
        email="mijoz@custom.uz", password="pass12345", role=User.Role.CUSTOMER, worker_id="MIJOZ001"
    )
    category = Category.objects.create(name_uz="Oshxona", slug="oshxona")
    product = Product.objects.create(company=company, category=category, name_uz="Oshxona to'plami", is_published=True)
    Variant.objects.create(product=product, name="oddiy", base_price=Decimal("100000"))
    return owner, company, usta_user, customer, product


class CreateCustomOrderOnSiteTests(APITestCase):
    def setUp(self):
        self.owner, self.company, self.usta_user, self.customer, self.product = make_company_with_usta()
        self.client = APIClient()

    def _payload(self, **overrides):
        payload = {
            "items": [{"product": str(self.product.id), "width": "1", "height": "1", "depth": "1", "quantity": 1}],
            "customer_worker_id": "MIJOZ001",
            "address": "Toshkent, Chilonzor",
            "latitude": "41.311081",
            "longitude": "69.240562",
            "is_mock": False,
        }
        payload.update(overrides)
        return payload

    def test_usta_creates_custom_order_directly(self):
        self.client.force_authenticate(self.usta_user)
        resp = self.client.post("/api/v1/custom-orders/create/", self._payload(), format="json")
        self.assertEqual(resp.status_code, 201, resp.data)
        order = Order.objects.get(pk=resp.data["id"])
        self.assertEqual(order.order_type, Order.OrderType.CUSTOM_PROJECT)
        self.assertEqual(order.customer_id, self.customer.id)
        self.assertFalse(order.location_flagged)
        self.assertTrue(Design.objects.filter(order=order).exists())

    def test_mock_location_flags_order_but_still_creates_it(self):
        self.client.force_authenticate(self.usta_user)
        resp = self.client.post("/api/v1/custom-orders/create/", self._payload(is_mock=True), format="json")
        self.assertEqual(resp.status_code, 201, resp.data)
        order = Order.objects.get(pk=resp.data["id"])
        self.assertTrue(order.location_flagged)
        self.assertTrue(order.location_flag_reason)

    def test_unknown_customer_worker_id_rejected(self):
        self.client.force_authenticate(self.usta_user)
        resp = self.client.post(
            "/api/v1/custom-orders/create/", self._payload(customer_worker_id="NOPE"), format="json"
        )
        self.assertEqual(resp.status_code, 400)

    def test_non_usta_employee_forbidden(self):
        other_user = User.objects.create_user(email="sotuvchi@custom.uz", password="pass12345", role=User.Role.EMPLOYEE)
        Employee.objects.create(company=self.company, user=other_user, positions=["sotuvchi"])
        self.client.force_authenticate(other_user)
        resp = self.client.post("/api/v1/custom-orders/create/", self._payload(), format="json")
        self.assertEqual(resp.status_code, 403)

    def test_owner_can_also_create(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post("/api/v1/custom-orders/create/", self._payload(), format="json")
        self.assertEqual(resp.status_code, 201, resp.data)
