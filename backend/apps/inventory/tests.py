from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee

from .models import Material, MaterialStock, Warehouse

User = get_user_model()


class InventoryPermissionTests(APITestCase):
    """Regressiya: ombor yaratish faqat firma egasiga, kirim/chiqim faqat
    omborchi (yoki ega)ga ruxsat berilishi kerak — avvalroq qo'shilgan
    cheklovlar."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.plain_employee_user = User.objects.create_user(
            email="ishchi@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=self.plain_employee_user, positions=["usta"])
        self.omborchi_user = User.objects.create_user(
            email="ombor@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=self.omborchi_user, positions=["omborchi"])
        self.material = Material.objects.create(company=self.company, name="Bo'yoq", unit="litr", unit_cost=10000)
        self.client = APIClient()

    def test_owner_can_create_warehouse_with_address(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/warehouses/",
            {"name": "Bosh ombor", "kind": "raw_material", "address": "Chilonzor"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)

    def test_warehouse_requires_address(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/warehouses/", {"name": "Bosh ombor", "kind": "raw_material"}, format="json"
        )
        self.assertEqual(resp.status_code, 400)

    def test_plain_employee_cannot_create_warehouse(self):
        self.client.force_authenticate(self.plain_employee_user)
        resp = self.client.post(
            "/api/v1/warehouses/",
            {"name": "Bosh ombor", "kind": "raw_material", "address": "Chilonzor"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_plain_employee_cannot_create_movement(self):
        warehouse = Warehouse.objects.create(
            company=self.company, name="Ombor", kind=Warehouse.Kind.RAW_MATERIAL, address="Chilonzor"
        )
        self.client.force_authenticate(self.plain_employee_user)
        resp = self.client.post(
            f"/api/v1/warehouses/{warehouse.id}/material-movements/",
            {"material": str(self.material.id), "movement_type": "in", "quantity": "5"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_omborchi_can_create_movement_and_stock_updates(self):
        warehouse = Warehouse.objects.create(
            company=self.company, name="Ombor", kind=Warehouse.Kind.RAW_MATERIAL, address="Chilonzor"
        )
        self.client.force_authenticate(self.omborchi_user)
        resp = self.client.post(
            f"/api/v1/warehouses/{warehouse.id}/material-movements/",
            {"material": str(self.material.id), "movement_type": "in", "quantity": "5"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        stock = MaterialStock.objects.get(warehouse=warehouse, material=self.material)
        self.assertEqual(stock.quantity, Decimal("5"))

    def test_out_movement_blocked_when_insufficient_stock(self):
        warehouse = Warehouse.objects.create(
            company=self.company, name="Ombor", kind=Warehouse.Kind.RAW_MATERIAL, address="Chilonzor"
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            f"/api/v1/warehouses/{warehouse.id}/material-movements/",
            {"material": str(self.material.id), "movement_type": "out", "quantity": "1"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
