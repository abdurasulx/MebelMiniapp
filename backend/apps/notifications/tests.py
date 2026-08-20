from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee
from apps.orders.models import Order
from apps.products.models import Category, Product, Variant
from apps.workflow.models import StepStatus, WorkflowStep, WorkflowStepInstance
from apps.workflow.services import create_workflow_instances, sync_order_status_on_step_completion

from .models import Notification, NotificationType
from .services import notify_order_status, notify_task_assigned, notify_task_available

User = get_user_model()


class NotificationTriggerTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.worker_user = User.objects.create_user(email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE)
        self.employee = Employee.objects.create(company=self.company, user=self.worker_user, positions=["usta"])
        self.customer = User.objects.create_user(email="mijoz@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.category = Category.objects.create(name_uz="Stullar", slug="stullar")
        self.product = Product.objects.create(company=self.company, category=self.category, name_uz="Stul", is_published=True)
        Variant.objects.create(product=self.product, name="oddiy", base_price=Decimal("100000"))
        self.order = Order.objects.create(
            company=self.company, customer=self.customer, phone="+998900000000", address="Toshkent"
        )

    def test_notify_order_status_creates_notification_for_customer(self):
        self.order.status = Order.Status.ACCEPTED
        self.order.save(update_fields=["status"])
        notify_order_status(self.order)
        notif = Notification.objects.get(recipient=self.customer)
        self.assertEqual(notif.notif_type, NotificationType.ORDER_STATUS)
        self.assertEqual(notif.order_id, self.order.id)

    def test_notify_task_assigned_and_available(self):
        step = WorkflowStepInstance.objects.create(
            company=self.company, name="Yetkazish", employee=self.employee, status=StepStatus.PENDING,
        )
        notify_task_assigned(step)
        notify_task_available(step)
        types = list(
            Notification.objects.filter(recipient=self.worker_user).order_by("created_at").values_list("notif_type", flat=True)
        )
        self.assertEqual(types, [NotificationType.TASK_ASSIGNED, NotificationType.TASK_AVAILABLE])

    def test_notify_task_assigned_noop_without_employee(self):
        step = WorkflowStepInstance.objects.create(company=self.company, name="Yetkazish")
        notify_task_assigned(step)
        self.assertEqual(Notification.objects.count(), 0)

    def test_create_workflow_instances_notifies_pre_assigned_employee(self):
        step1 = WorkflowStep.objects.create(
            product=self.product, order_index=0, name="Kesish", employee=self.employee
        )
        create_workflow_instances(self.order, self.product)
        self.assertTrue(
            Notification.objects.filter(
                recipient=self.worker_user, notif_type=NotificationType.TASK_ASSIGNED
            ).exists()
        )

    def test_sync_order_status_notifies_customer_on_ready(self):
        WorkflowStep.objects.create(product=self.product, order_index=0, name="Kesish")
        create_workflow_instances(self.order, self.product)
        self.order.status = Order.Status.IN_PRODUCTION
        self.order.save(update_fields=["status"])
        for step in self.order.workflow_steps.all():
            step.status = StepStatus.COMPLETED
            step.save(update_fields=["status"])
        sync_order_status_on_step_completion(self.order)
        self.assertTrue(
            Notification.objects.filter(recipient=self.customer, notif_type=NotificationType.ORDER_STATUS).exists()
        )

    def test_activate_dependents_returns_only_newly_activated_and_view_notifies(self):
        step1 = WorkflowStepInstance.objects.create(
            company=self.company, order=self.order, name="Kesish", status=StepStatus.IN_PROGRESS,
        )
        step2 = WorkflowStepInstance.objects.create(
            company=self.company, order=self.order, name="Yig'ish", employee=self.employee, status=StepStatus.PENDING,
        )
        step2.depends_on.set([step1])

        client = APIClient()
        client.force_authenticate(self.worker_user)
        # step1 topshirilmagan (employeesiz) — firma egasi orqali complete qilamiz
        client.force_authenticate(self.owner)
        resp = client.post(f"/api/v1/workflow-instances/{step1.id}/complete/", {"comment": "tayyor"})
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertTrue(
            Notification.objects.filter(
                recipient=self.worker_user, notif_type=NotificationType.TASK_AVAILABLE
            ).exists()
        )


class NotificationApiTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner2@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop2", slug="shop2")
        self.user = User.objects.create_user(email="u1@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.other = User.objects.create_user(email="u2@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.n1 = Notification.objects.create(
            recipient=self.user, notif_type=NotificationType.ORDER_STATUS, title="A", body="a"
        )
        self.n2 = Notification.objects.create(
            recipient=self.user, notif_type=NotificationType.ORDER_STATUS, title="B", body="b"
        )
        Notification.objects.create(
            recipient=self.other, notif_type=NotificationType.ORDER_STATUS, title="Boshqa", body="x"
        )

    def test_list_scoped_to_recipient(self):
        self.client.force_authenticate(self.user)
        resp = self.client.get("/api/v1/notifications/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data["count"], 2)

    def test_unread_count(self):
        self.client.force_authenticate(self.user)
        resp = self.client.get("/api/v1/notifications/unread_count/")
        self.assertEqual(resp.data["count"], 2)

    def test_mark_read(self):
        self.client.force_authenticate(self.user)
        resp = self.client.post(f"/api/v1/notifications/{self.n1.id}/mark_read/")
        self.assertEqual(resp.status_code, 200)
        self.n1.refresh_from_db()
        self.assertTrue(self.n1.is_read)

    def test_mark_read_other_users_notification_404(self):
        self.client.force_authenticate(self.user)
        other_notif = Notification.objects.get(recipient=self.other)
        resp = self.client.post(f"/api/v1/notifications/{other_notif.id}/mark_read/")
        self.assertEqual(resp.status_code, 404)

    def test_mark_all_read(self):
        self.client.force_authenticate(self.user)
        resp = self.client.post("/api/v1/notifications/mark_all_read/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(Notification.objects.filter(recipient=self.user, is_read=False).count(), 0)
        self.other.refresh_from_db()
        self.assertEqual(Notification.objects.filter(recipient=self.other, is_read=True).count(), 0)
