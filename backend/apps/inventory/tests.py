from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee
from apps.notifications.models import Notification, NotificationType
from apps.products.models import Category, Product

from .models import BillOfMaterial, Material, MaterialRemnant, MaterialStock, PurchaseOrder, Supplier, Warehouse

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


class SheetMaterialTests(APITestCase):
    """VARAQ (fanera/DVP kabi) materiallar — eni x bo'yi bo'yicha kirim
    qilinadi va ishlab chiqarishda eng mos (best-fit) qoldiqdan
    foydalaniladi, isrofni kamaytirish tavsiyasi bilan (Notification)."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.omborchi_user = User.objects.create_user(
            email="ombor@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=self.omborchi_user, positions=["omborchi"])
        self.material = Material.objects.create(
            company=self.company, name="Fanera 4mm", unit="m2", unit_cost=100000,
            dimension_type=Material.DimensionType.SHEET,
        )
        self.warehouse = Warehouse.objects.create(
            company=self.company, name="Xom ashyo ombori", kind=Warehouse.Kind.RAW_MATERIAL, address="Chilonzor",
        )
        self.finished_warehouse = Warehouse.objects.create(
            company=self.company, name="Tayyor mahsulot ombori", kind=Warehouse.Kind.FINISHED_GOODS,
            address="Chilonzor",
        )
        self.category = Category.objects.create(name_uz="Stullar", slug="stullar")
        self.product = Product.objects.create(
            company=self.company, category=self.category, name_uz="Stul", is_published=True
        )
        BillOfMaterial.objects.create(
            product=self.product, material=self.material, quantity_per_unit=1,
            cut_length=Decimal("0.4"), cut_width=Decimal("0.3"),
        )
        self.client = APIClient()

    def test_receive_creates_remnant_and_movement(self):
        self.client.force_authenticate(self.omborchi_user)
        resp = self.client.post(
            f"/api/v1/warehouses/{self.warehouse.id}/material-remnants/receive/",
            {"material": str(self.material.id), "length": "1.22", "width": "2.44", "quantity": 3},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        remnant = MaterialRemnant.objects.get(warehouse=self.warehouse, material=self.material)
        self.assertEqual(remnant.quantity, 3)
        self.assertEqual(remnant.width, Decimal("2.44"))

    def test_plain_employee_cannot_receive(self):
        plain_user = User.objects.create_user(
            email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=plain_user, positions=["usta"])
        self.client.force_authenticate(plain_user)
        resp = self.client.post(
            f"/api/v1/warehouses/{self.warehouse.id}/material-remnants/receive/",
            {"material": str(self.material.id), "length": "1.22", "width": "2.44", "quantity": 1},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_bom_validation_rejects_cut_width_without_sheet_material(self):
        linear_material = Material.objects.create(
            company=self.company, name="Reyka", unit="m", unit_cost=5000,
            dimension_type=Material.DimensionType.LINEAR, stock_unit_length=Decimal("3"),
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            f"/api/v1/products/{self.product.id}/bill-of-materials/",
            {"material": str(linear_material.id), "quantity_per_unit": 1, "cut_length": "0.4", "cut_width": "0.3"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_produce_picks_best_fit_remnant_and_creates_leftovers(self):
        # Kerak: 0.3x0.4. Ikkita nomzod qoldiq bor — 0.5x0.5 (kattaroq, ko'proq
        # isrof) va 0.35x0.45 (aniqroq mos, kamroq isrof) — best-fit
        # eng kichik yetarlisini (0.35x0.45) tanlashi kerak.
        MaterialRemnant.objects.create(
            warehouse=self.warehouse, material=self.material, length=Decimal("0.5"), width=Decimal("0.5"), quantity=1,
        )
        MaterialRemnant.objects.create(
            warehouse=self.warehouse, material=self.material, length=Decimal("0.45"), width=Decimal("0.35"), quantity=1,
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            f"/api/v1/warehouses/{self.finished_warehouse.id}/produce/",
            {
                "product": str(self.product.id), "quantity": 1,
                "material_warehouse": str(self.warehouse.id),
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)

        # Aniqroq mos (0.35x0.45) qoldiq butunlay ishlatilgan bo'lishi kerak.
        self.assertFalse(
            MaterialRemnant.objects.filter(warehouse=self.warehouse, length=Decimal("0.45"), width=Decimal("0.35")).exists()
        )
        # Kattaroq (0.5x0.5) qoldiq tegilmagan bo'lishi kerak.
        self.assertTrue(
            MaterialRemnant.objects.filter(warehouse=self.warehouse, length=Decimal("0.5"), width=Decimal("0.5"), quantity=1).exists()
        )
        # Yangi qoldiq(lar) hosil bo'lgan bo'lishi kerak (guillotine kesim).
        self.assertTrue(MaterialRemnant.objects.filter(warehouse=self.warehouse, length=Decimal("0.45")).exclude(width=Decimal("0.35")).exists() or
                         MaterialRemnant.objects.filter(warehouse=self.warehouse, width=Decimal("0.35")).exclude(length=Decimal("0.45")).exists())

        notif = Notification.objects.get(recipient=self.owner, notif_type=NotificationType.MATERIAL_SUGGESTION)
        self.assertIn("0.350x0.450", notif.body)

    def test_produce_fails_when_no_remnant_fits(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            f"/api/v1/warehouses/{self.finished_warehouse.id}/produce/",
            {
                "product": str(self.product.id), "quantity": 1,
                "material_warehouse": str(self.warehouse.id),
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn("qoldig'i yo'q", str(resp.data))


class MaterialSearchTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(email="search-owner@inv.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Qidiruv", slug="qidiruv-inv")
        other_owner = User.objects.create_user(email="search-other@inv.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        other = Company.objects.create(owner=other_owner, name="Boshqa", slug="boshqa-inv")
        Material.objects.create(company=self.company, name="ДСП бук 16")
        Material.objects.create(company=self.company, name="Kronospan Oq")
        Material.objects.create(company=other, name="Kronospan Begona")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def _names(self, query):
        resp = self.client.get("/api/v1/materials/", {"search": query})
        self.assertEqual(resp.status_code, 200)
        return [m["name"] for m in resp.data["results"]]

    def test_search_is_case_insensitive_substring_and_company_scoped(self):
        self.assertEqual(self._names("KRONO"), ["Kronospan Oq"])
        self.assertEqual(self._names("бук"), ["ДСП бук 16"])
        self.assertEqual(self._names("zzz"), [])

    def test_no_search_returns_all_own_materials_sorted(self):
        self.assertEqual(self._names(""), ["Kronospan Oq", "ДСП бук 16"])


class MaterialImageRequiredTests(APITestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(email="img-owner@inv.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Rasm", slug="rasm-inv")
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def _png(self):
        import io

        from django.core.files.uploadedfile import SimpleUploadedFile
        from PIL import Image

        buf = io.BytesIO()
        Image.new("RGB", (2, 2), "white").save(buf, format="PNG")
        return SimpleUploadedFile("dsp.png", buf.getvalue(), content_type="image/png")

    def test_create_without_image_rejected(self):
        resp = self.client.post("/api/v1/materials/", {"name": "DSP", "unit": "dona"}, format="multipart")
        self.assertEqual(resp.status_code, 400)
        self.assertIn("image", resp.data)

    def test_create_with_image_ok_and_update_without_image_ok(self):
        resp = self.client.post(
            "/api/v1/materials/", {"name": "DSP", "unit": "dona", "image": self._png()}, format="multipart"
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertTrue(resp.data["image"])
        upd = self.client.patch(f"/api/v1/materials/{resp.data['id']}/", {"unit_cost": "5"}, format="json")
        self.assertEqual(upd.status_code, 200, upd.data)

    def test_legacy_material_without_image_can_still_be_edited(self):
        legacy = Material.objects.create(company=self.company, name="Eski")
        upd = self.client.patch(f"/api/v1/materials/{legacy.id}/", {"unit_cost": "7"}, format="json")
        self.assertEqual(upd.status_code, 200, upd.data)
