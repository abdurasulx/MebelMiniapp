from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee
from apps.products.models import Category, Product, Variant

from .models import ARCollection, ARCollectionItem

User = get_user_model()


class ARCollectionTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.usta_user = User.objects.create_user(
            email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=self.usta_user, positions=["usta"])
        self.category = Category.objects.create(name_uz="Stullar", slug="stullar")
        self.product = Product.objects.create(
            company=self.company, category=self.category, name_uz="Stul", is_published=True
        )
        self.variant = Variant.objects.create(product=self.product, name="Yong'oq", base_price=Decimal("100000"))
        self.other_product = Product.objects.create(
            company=self.company, category=self.category, name_uz="Stol", is_published=True
        )
        self.client = APIClient()

    def test_create_collection_and_add_item(self):
        self.client.force_authenticate(self.usta_user)
        create_resp = self.client.post("/api/v1/ar-collections/", {"name": "Mijoz A xonasi"}, format="json")
        self.assertEqual(create_resp.status_code, 201, create_resp.data)
        collection_id = create_resp.data["id"]

        add_resp = self.client.post(
            f"/api/v1/ar-collections/{collection_id}/items/",
            {"product_id": str(self.product.id), "variant": str(self.variant.id)},
            format="json",
        )
        self.assertEqual(add_resp.status_code, 201, add_resp.data)
        self.assertEqual(add_resp.data["variant_id"], str(self.variant.id))
        self.assertEqual(add_resp.data["product"]["id"], str(self.product.id))

        detail_resp = self.client.get(f"/api/v1/ar-collections/{collection_id}/")
        self.assertEqual(detail_resp.data["item_count"], 1)
        self.assertEqual(len(detail_resp.data["items"]), 1)

    def test_add_item_without_variant(self):
        self.client.force_authenticate(self.usta_user)
        collection = ARCollection.objects.create(owner=self.usta_user, name="Test")
        resp = self.client.post(
            f"/api/v1/ar-collections/{collection.id}/items/",
            {"product_id": str(self.other_product.id)},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertIsNone(resp.data["variant_id"])

    def test_variant_must_belong_to_product(self):
        self.client.force_authenticate(self.usta_user)
        collection = ARCollection.objects.create(owner=self.usta_user, name="Test")
        resp = self.client.post(
            f"/api/v1/ar-collections/{collection.id}/items/",
            {"product_id": str(self.other_product.id), "variant": str(self.variant.id)},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_cannot_access_other_users_collection(self):
        collection = ARCollection.objects.create(owner=self.usta_user, name="Boshqaniki")
        other_user = User.objects.create_user(
            email="other@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        self.client.force_authenticate(other_user)
        resp = self.client.get(f"/api/v1/ar-collections/{collection.id}/")
        self.assertEqual(resp.status_code, 404)

    def test_remove_item(self):
        self.client.force_authenticate(self.usta_user)
        collection = ARCollection.objects.create(owner=self.usta_user, name="Test")
        item = ARCollectionItem.objects.create(collection=collection, product=self.product, variant=self.variant)
        resp = self.client.delete(f"/api/v1/ar-collections/{collection.id}/items/{item.id}/")
        self.assertEqual(resp.status_code, 204)
        item.refresh_from_db()
        self.assertTrue(item.is_deleted)

    def test_list_only_own_collections(self):
        ARCollection.objects.create(owner=self.usta_user, name="Mine")
        other_user = User.objects.create_user(
            email="other2@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        ARCollection.objects.create(owner=other_user, name="Not mine")
        self.client.force_authenticate(self.usta_user)
        resp = self.client.get("/api/v1/ar-collections/")
        self.assertEqual(resp.data["count"], 1)
        self.assertEqual(resp.data["results"][0]["name"], "Mine")

    def test_unauthenticated_blocked(self):
        resp = self.client.get("/api/v1/ar-collections/")
        self.assertEqual(resp.status_code, 401)

    def test_delete_collection_soft_deletes(self):
        self.client.force_authenticate(self.usta_user)
        collection = ARCollection.objects.create(owner=self.usta_user, name="Test")
        resp = self.client.delete(f"/api/v1/ar-collections/{collection.id}/")
        self.assertEqual(resp.status_code, 204)
        collection.refresh_from_db()
        self.assertTrue(collection.is_deleted)
        list_resp = self.client.get("/api/v1/ar-collections/")
        self.assertEqual(list_resp.data["count"], 0)
