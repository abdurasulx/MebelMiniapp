from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from apps.companies.models import Company
from apps.orders.models import Order
from apps.products.models import Category, Product, Variant

from .models import StepStatus, WorkflowStep, WorkflowStepInstance
from .services import create_workflow_instances, sync_order_status_on_step_completion

User = get_user_model()


class WorkflowServiceTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.category = Category.objects.create(name_uz="Stullar", slug="stullar")
        self.product = Product.objects.create(company=self.company, category=self.category, name_uz="Stul", is_published=True)
        self.variant = Variant.objects.create(product=self.product, name="oddiy", base_price=Decimal("100000"))
        self.customer = User.objects.create_user(email="mijoz@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.order = Order.objects.create(
            company=self.company, customer=self.customer, phone="+998900000000", address="Toshkent"
        )

        self.step1 = WorkflowStep.objects.create(product=self.product, order_index=0, name="Kesish")
        self.step2 = WorkflowStep.objects.create(product=self.product, order_index=1, name="Yig'ish")
        self.step2.depends_on.set([self.step1])

    def test_independent_step_starts_immediately_dependent_stays_pending(self):
        instances = create_workflow_instances(self.order, self.product)
        self.assertEqual(len(instances), 2)
        by_name = {i.name: i for i in instances}
        self.assertEqual(by_name["Kesish"].status, StepStatus.IN_PROGRESS)
        self.assertEqual(by_name["Yig'ish"].status, StepStatus.PENDING)

    def test_completing_all_steps_moves_order_to_ready(self):
        create_workflow_instances(self.order, self.product)
        self.order.status = Order.Status.IN_PRODUCTION
        self.order.save(update_fields=["status"])

        first = WorkflowStepInstance.objects.get(order=self.order, name="Kesish")
        first.status = StepStatus.COMPLETED
        first.save(update_fields=["status"])
        first.activate_dependents()
        sync_order_status_on_step_completion(self.order)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.IN_PRODUCTION)  # hali "Yig'ish" tugamagan

        second = WorkflowStepInstance.objects.get(order=self.order, name="Yig'ish")
        second.status = StepStatus.COMPLETED
        second.save(update_fields=["status"])
        sync_order_status_on_step_completion(self.order)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.READY)

    def test_complete_action_via_api_triggers_sync(self):
        create_workflow_instances(self.order, self.product)
        self.order.status = Order.Status.IN_PRODUCTION
        self.order.save(update_fields=["status"])
        # Ikkinchi bosqich bog'liq bo'lgani uchun avval birinchisini yakunlaymiz.
        first = WorkflowStepInstance.objects.get(order=self.order, name="Kesish")

        client = APIClient()
        client.force_authenticate(self.owner)
        resp = client.post(f"/api/v1/workflow-instances/{first.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)

        second = WorkflowStepInstance.objects.get(order=self.order, name="Yig'ish")
        resp = client.post(f"/api/v1/workflow-instances/{second.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)

        self.order.refresh_from_db()
        self.assertEqual(self.order.status, Order.Status.READY)
