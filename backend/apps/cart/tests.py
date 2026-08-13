from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from apps.companies.models import Company
from apps.products.models import Category, Product, Variant

from .models import CartItem

User = get_user_model()


class CartItemTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="o@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.customer = User.objects.create_user(email="c@shop.uz", password="pass12345", role=User.Role.CUSTOMER)
        company = Company.objects.create(owner=self.owner, name="Shop", slug="cart-shop")
        category = Category.objects.create(name_uz="Stullar", slug="cart-stullar")
        self.product = Product.objects.create(company=company, category=category, name_uz="Stul", is_published=True)
        self.variant = Variant.objects.create(product=self.product, name="Standart", base_price=100000)
        self.client.force_authenticate(self.customer)

    def test_add_to_cart_and_list(self):
        resp = self.client.post(
            "/api/v1/cart-items/",
            {"product": self.product.id, "variant": self.variant.id, "width": 1, "height": 1, "depth": 1, "quantity": 2},
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        resp = self.client.get("/api/v1/cart-items/")
        self.assertEqual(len(resp.data["results"]), 1)
        self.assertEqual(resp.data["results"][0]["quantity"], 2)

    def test_adding_same_item_twice_merges_quantity(self):
        payload = {"product": self.product.id, "variant": self.variant.id, "width": 1, "height": 1, "depth": 1, "quantity": 1}
        self.client.post("/api/v1/cart-items/", payload)
        self.client.post("/api/v1/cart-items/", payload)
        self.assertEqual(CartItem.objects.filter(user=self.customer, is_deleted=False).count(), 1)
        self.assertEqual(CartItem.objects.get(user=self.customer, is_deleted=False).quantity, 2)

    def test_cannot_see_another_users_cart(self):
        self.client.post(
            "/api/v1/cart-items/",
            {"product": self.product.id, "variant": self.variant.id, "width": 1, "height": 1, "depth": 1, "quantity": 1},
        )
        other = User.objects.create_user(email="other@shop.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.client.force_authenticate(other)
        resp = self.client.get("/api/v1/cart-items/")
        self.assertEqual(len(resp.data["results"]), 0)
