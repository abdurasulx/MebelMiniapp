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


# Kichiklashtirilgan Bazis eksporti — apps/workflow/tests.py::BAZIS_FIXTURE bilan
# bir xil tuzilish (1 detal, 2 dona, 2 ta Ø8 teshik, 1 varaq material).
BAZIS_FIXTURE = """<?xml version="1.0" encoding="windows-1251"?><project importBMV="1.86">
<good typeId="product" id="1" count="1" name="test mahsulot" code="1">
<part id="1" name="01_001 tag" dl="600" dw="350" count="2"/>
</good>
<good typeId="tool.cutting" id="2"/>
<good typeId="sheet" id="3" t="16" name="DSP oq"><part id="10" count="1000" l="2800" w="2070"/></good>
<operation typeId="CS" id="1" tool1="2"><material id="3"/><part id="1" /></operation>
<operation typeId="XNC" id="3" bySizeDetail="true" code="1_01_001" typeName="01_001 tag" program="&lt;?xml version=&quot;1.0&quot; encoding=&quot;UTF-8&quot;?&gt;&lt;program dx=&quot;600.00&quot; dy=&quot;350.00&quot; dz=&quot;16.00&quot;&gt;&lt;tool name=&quot;Bore8&quot; d=&quot;8&quot; /&gt;&lt;bf x=&quot;50&quot; y=&quot;50&quot; dp=&quot;13&quot; name=&quot;Bore8&quot;/&gt;&lt;bf x=&quot;550&quot; y=&quot;50&quot; dp=&quot;13&quot; name=&quot;Bore8&quot;/&gt;&lt;/program&gt;"/>
</project>""".encode("windows-1251")


class DesignBazisImportTests(APITestCase):
    def setUp(self):
        self.owner, self.company, self.usta_user, self.customer, self.product = make_company_with_usta()
        self.client = APIClient()
        self.client.force_authenticate(self.usta_user)
        resp = self.client.post(
            "/api/v1/custom-orders/create/",
            {
                "items": [{"product": str(self.product.id), "width": "1", "height": "1", "depth": "1", "quantity": 1}],
                "customer_worker_id": "MIJOZ001",
                "address": "Toshkent",
            },
            format="json",
        )
        self.order = Order.objects.get(pk=resp.data["id"])

    def _upload(self):
        from django.core.files.uploadedfile import SimpleUploadedFile

        f = SimpleUploadedFile("test.project", BAZIS_FIXTURE, content_type="application/xml")
        return self.client.post(
            f"/api/v1/custom-orders/{self.order.id}/import-bazis/", {"file": f}, format="multipart"
        )

    def test_import_attaches_summary_to_design(self):
        resp = self._upload()
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data["holes_total"], 4)  # 2 teshik x 2 dona

        design = Design.objects.get(order=self.order)
        self.assertTrue(design.bazis_file)
        self.assertEqual(design.bazis_summary["parts_count"], 1)
        self.assertIn("DSP oq", design.bazis_summary["sheet_usage"])

    def test_stranger_cannot_import_into_others_order(self):
        other_owner = User.objects.create_user(
            email="boshqa-owner@custom.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        Company.objects.create(owner=other_owner, name="Boshqa", slug="boshqa-custom")
        self.client.force_authenticate(other_owner)
        resp = self._upload()
        self.assertEqual(resp.status_code, 400)  # boshqa firma uchun order "topilmadi"

    def test_invalid_file_returns_400(self):
        from django.core.files.uploadedfile import SimpleUploadedFile

        f = SimpleUploadedFile("bad.project", b"not xml", content_type="application/xml")
        resp = self.client.post(
            f"/api/v1/custom-orders/{self.order.id}/import-bazis/", {"file": f}, format="multipart"
        )
        self.assertEqual(resp.status_code, 400)


class WorkflowInstancesFromBazisDesignTests(APITestCase):
    """create_workflow_instances_from_design Bazis ma'lumoti bo'lsa DETAL
    darajasidagi topshiriq yaratishi, bo'lmasa eski production_sequence
    yo'liga tushishi kerak."""

    def setUp(self):
        self.owner, self.company, self.usta_user, self.customer, self.product = make_company_with_usta()

    def _make_order_with_design(self):
        from apps.orders.models import Order as OrderModel

        order = OrderModel.objects.create(
            company=self.company, customer=self.customer, order_type=OrderModel.OrderType.CUSTOM_PROJECT,
            status=OrderModel.Status.NEW,
        )
        design = Design.objects.create(order=order)
        return order, design

    def test_bazis_summary_creates_grouped_instances_with_work_type(self):
        from .services import create_workflow_instances_from_design

        order, design = self._make_order_with_design()
        design.bazis_summary = {
            "product_name": "shkaf",
            "parts_count": 2,
            "sheet_usage": {"DSP oq": 3},
            "band_usage": {"PVX oq": 2},
            "hole_groups": {"Ø8mm": 4, "Ø5mm": 2},
        }
        design.save(update_fields=["bazis_summary"])

        instances = create_workflow_instances_from_design(order, design)
        self.assertEqual(len(instances), 4)  # 1 kesish + 1 kromkalash + 2 teshik guruhi

        hole8 = next(i for i in instances if i.name == "Teshish Ø8mm")
        self.assertEqual(hole8.quantity, Decimal("4"))
        self.assertEqual(hole8.cost, Decimal("0.00"))  # narx hali belgilanmagan
        self.assertIsNotNone(hole8.work_type_id)

        cutting = next(i for i in instances if i.name.startswith("Kesish"))
        self.assertEqual(cutting.quantity, Decimal("3"))

        # Ketma-ket bog'langan zanjir — birinchisi hech qanday bog'liqligi
        # yo'qligi sabab avtomatik IN_PROGRESS'ga o'tadi (mavjud xatti-harakat,
        # qarang create_workflow_instances_from_design), qolganlari kutadi.
        from apps.workflow.models import StepStatus

        self.assertEqual(instances[0].status, StepStatus.IN_PROGRESS)
        self.assertFalse(instances[1].is_available)  # birinchisiga bog'liq

    def test_without_bazis_summary_falls_back_to_production_sequence(self):
        from .services import create_workflow_instances_from_design

        order, design = self._make_order_with_design()
        design.production_sequence = ["cutting", "assembly"]
        design.save(update_fields=["production_sequence"])

        instances = create_workflow_instances_from_design(order, design)
        self.assertEqual(len(instances), 2)
        self.assertIsNone(instances[0].work_type_id)
        self.assertEqual(instances[0].stage, "cutting")

    def test_neither_bazis_nor_sequence_creates_nothing(self):
        from .services import create_workflow_instances_from_design

        order, design = self._make_order_with_design()
        instances = create_workflow_instances_from_design(order, design)
        self.assertEqual(instances, [])
