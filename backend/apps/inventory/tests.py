from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee

from .models import Material, MaterialStock, PurchaseOrder, Supplier, Warehouse

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


class ProcurementTests(APITestCase):
    """Xom ashyo ta'minoti: yetkazib beruvchi, kam-qoldiq ogohlantirishi,
    xarid buyurtmasi qabul qilinganda ombor avtomatik to'lishi."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.omborchi_user = User.objects.create_user(
            email="ombor@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=self.omborchi_user, positions=["omborchi"])
        self.supplier = Supplier.objects.create(company=self.company, name="Yog'och Baza")
        self.material = Material.objects.create(
            company=self.company, name="Bo'yoq", unit="litr", unit_cost=10000, min_stock=10
        )
        self.warehouse = Warehouse.objects.create(
            company=self.company, name="Ombor", kind=Warehouse.Kind.RAW_MATERIAL, address="Chilonzor"
        )
        self.client = APIClient()

    def test_low_stock_lists_material_below_threshold(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/materials/low-stock/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]["id"], str(self.material.id))
        self.assertEqual(resp.data[0]["current_stock"], 0)

    def test_low_stock_excludes_material_with_enough_stock(self):
        MaterialStock.objects.create(warehouse=self.warehouse, material=self.material, quantity=Decimal("50"))
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/materials/low-stock/")
        self.assertEqual(resp.data, [])

    def test_plain_employee_cannot_create_purchase_order(self):
        plain_user = User.objects.create_user(
            email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=plain_user, positions=["usta"])
        self.client.force_authenticate(plain_user)
        resp = self.client.post(
            "/api/v1/purchase-orders/",
            {
                "supplier": str(self.supplier.id),
                "warehouse": str(self.warehouse.id),
                "items": [{"material": str(self.material.id), "quantity": "20", "unit_cost": "9000"}],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_receiving_purchase_order_fills_stock_and_creates_movement(self):
        self.client.force_authenticate(self.omborchi_user)
        create_resp = self.client.post(
            "/api/v1/purchase-orders/",
            {
                "supplier": str(self.supplier.id),
                "warehouse": str(self.warehouse.id),
                "items": [{"material": str(self.material.id), "quantity": "20", "unit_cost": "9000"}],
            },
            format="json",
        )
        self.assertEqual(create_resp.status_code, 201, create_resp.data)
        order_id = create_resp.data["id"]

        receive_resp = self.client.post(f"/api/v1/purchase-orders/{order_id}/receive/")
        self.assertEqual(receive_resp.status_code, 200, receive_resp.data)
        self.assertEqual(receive_resp.data["status"], "received")

        stock = MaterialStock.objects.get(warehouse=self.warehouse, material=self.material)
        self.assertEqual(stock.quantity, Decimal("20"))

        order = PurchaseOrder.objects.get(pk=order_id)
        self.assertIsNotNone(order.received_at)

    def test_cannot_receive_already_received_order(self):
        self.client.force_authenticate(self.omborchi_user)
        create_resp = self.client.post(
            "/api/v1/purchase-orders/",
            {
                "supplier": str(self.supplier.id),
                "warehouse": str(self.warehouse.id),
                "items": [{"material": str(self.material.id), "quantity": "5", "unit_cost": "9000"}],
            },
            format="json",
        )
        order_id = create_resp.data["id"]
        self.client.post(f"/api/v1/purchase-orders/{order_id}/receive/")
        second = self.client.post(f"/api/v1/purchase-orders/{order_id}/receive/")
        self.assertEqual(second.status_code, 400)
