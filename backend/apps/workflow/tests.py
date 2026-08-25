from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee
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

    def test_independent_unassigned_step_stays_pending_but_available_dependent_stays_pending(self):
        # Xodimi biriktirilmagan ("erkin") bosqich bog'liqlik yo'q bo'lsa ham
        # avtomatik IN_PROGRESS bo'lmaydi — hech kim hali ish boshlamagan
        # bo'ladi, faqat is_available=True bo'lib "erkin topshiriqlar
        # hovuzi"da ko'rinadi (qarang StepApplication/open_pool).
        instances = create_workflow_instances(self.order, self.product)
        self.assertEqual(len(instances), 2)
        by_name = {i.name: i for i in instances}
        self.assertEqual(by_name["Kesish"].status, StepStatus.PENDING)
        self.assertTrue(by_name["Kesish"].is_available)
        self.assertEqual(by_name["Yig'ish"].status, StepStatus.PENDING)
        self.assertFalse(by_name["Yig'ish"].is_available)

    def test_independent_assigned_step_starts_immediately(self):
        employee = Employee.objects.create(company=self.company, user=self.owner, positions=["usta"])
        self.step1.employee = employee
        self.step1.save(update_fields=["employee"])
        instances = create_workflow_instances(self.order, self.product)
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


class ManualTaskTests(APITestCase):
    """Avvalgi `ProductionTask` funksiyasi endi shu API'ga birlashtirilgan —
    retseptga bog'liq bo'lmagan (`template_step=None`) vazifalar."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.worker_user = User.objects.create_user(
            email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        self.employee = Employee.objects.create(
            company=self.company, user=self.worker_user, positions=["usta"]
        )
        self.client = APIClient()

    def test_owner_creates_manual_task(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/workflow-instances/",
            {"name": "Yetkazish", "stage": "delivery", "employee": str(self.employee.id)},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertTrue(resp.data["is_manual"])
        self.assertEqual(resp.data["suggested_position"], "haydovchi")
        self.assertEqual(resp.data["status"], "pending")

    def test_employee_cannot_create_manual_task(self):
        self.client.force_authenticate(self.worker_user)
        resp = self.client.post("/api/v1/workflow-instances/", {"name": "Yetkazish"}, format="json")
        self.assertEqual(resp.status_code, 403)

    def test_assigned_employee_can_only_change_status(self):
        task = WorkflowStepInstance.objects.create(
            company=self.company, name="Yig'ish", employee=self.employee, status=StepStatus.PENDING
        )
        self.client.force_authenticate(self.worker_user)

        resp = self.client.patch(
            f"/api/v1/workflow-instances/{task.id}/", {"name": "Boshqa nom"}, format="json"
        )
        self.assertEqual(resp.status_code, 403)

        resp = self.client.patch(
            f"/api/v1/workflow-instances/{task.id}/", {"status": "completed"}, format="json"
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        task.refresh_from_db()
        self.assertEqual(task.status, StepStatus.COMPLETED)
        self.assertIsNotNone(task.completed_at)

    def test_other_employee_cannot_touch_unassigned_task(self):
        other_user = User.objects.create_user(
            email="boshqa@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        Employee.objects.create(company=self.company, user=other_user, positions=["sotuvchi"])
        task = WorkflowStepInstance.objects.create(
            company=self.company, name="Yig'ish", employee=self.employee, status=StepStatus.PENDING
        )
        self.client.force_authenticate(other_user)
        resp = self.client.patch(
            f"/api/v1/workflow-instances/{task.id}/", {"status": "completed"}, format="json"
        )
        # Xodim endi faqat o'ziga biriktirilgan vazifalarni ko'radi (qarang
        # get_queryset "usta sahifasi" skoping) — boshqa xodimning vazifasi
        # uning queryset'ida umuman yo'q, shuning uchun 403 emas 404.
        self.assertEqual(resp.status_code, 404)

    def test_recipe_step_cannot_be_edited_directly(self):
        template = WorkflowStep.objects.create(product=Product.objects.create(
            company=self.company,
            category=Category.objects.create(name_uz="Stullar", slug="stullar-2"),
            name_uz="Stul", is_published=True,
        ), name="Kesish")
        instance = WorkflowStepInstance.objects.create(
            company=self.company, template_step=template, name="Kesish", status=StepStatus.PENDING
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.patch(
            f"/api/v1/workflow-instances/{instance.id}/", {"status": "completed"}, format="json"
        )
        self.assertEqual(resp.status_code, 400)

    def test_owner_deletes_manual_task(self):
        task = WorkflowStepInstance.objects.create(company=self.company, name="Vaqtinchalik")
        self.client.force_authenticate(self.owner)
        resp = self.client.delete(f"/api/v1/workflow-instances/{task.id}/")
        self.assertEqual(resp.status_code, 204)
        self.assertTrue(WorkflowStepInstance.objects.get(pk=task.pk).is_deleted)


class UstaSahifasiScopingTests(APITestCase):
    """"Usta sahifasi": oddiy xodim faqat o'ziga biriktirilgan vazifalarni
    ko'rishi, firma egasi esa hamon barchasini ko'rishi kerak."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner2@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop2", slug="shop2")
        self.usta_user = User.objects.create_user(
            email="usta2@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        self.usta = Employee.objects.create(company=self.company, user=self.usta_user, positions=["usta"])
        self.other_user = User.objects.create_user(
            email="other2@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        self.other = Employee.objects.create(company=self.company, user=self.other_user, positions=["usta"])
        self.client = APIClient()

    def test_employee_sees_only_own_tasks(self):
        mine = WorkflowStepInstance.objects.create(
            company=self.company, name="Mening vazifam", employee=self.usta, status=StepStatus.PENDING
        )
        WorkflowStepInstance.objects.create(
            company=self.company, name="Boshqaning vazifasi", employee=self.other, status=StepStatus.PENDING
        )
        WorkflowStepInstance.objects.create(
            company=self.company, name="Hech kimga biriktirilmagan", status=StepStatus.PENDING
        )
        self.client.force_authenticate(self.usta_user)
        resp = self.client.get("/api/v1/workflow-instances/")
        self.assertEqual(resp.status_code, 200)
        ids = {row["id"] for row in resp.data["results"]}
        self.assertEqual(ids, {str(mine.id)})

    def test_owner_still_sees_all_tasks(self):
        WorkflowStepInstance.objects.create(company=self.company, name="A", employee=self.usta)
        WorkflowStepInstance.objects.create(company=self.company, name="B", employee=self.other)
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/workflow-instances/")
        self.assertEqual(len(resp.data["results"]), 2)

    def test_employee_cannot_progress_other_employees_task(self):
        theirs = WorkflowStepInstance.objects.create(
            company=self.company, name="Boshqaning vazifasi", employee=self.other, status=StepStatus.PENDING
        )
        self.client.force_authenticate(self.usta_user)
        resp = self.client.post(f"/api/v1/workflow-instances/{theirs.id}/progress/", {}, format="json")
        self.assertEqual(resp.status_code, 404)

    def test_own_tasks_ordered_actionable_first_then_deadline(self):
        from datetime import date, timedelta

        today = date.today()
        done = WorkflowStepInstance.objects.create(
            company=self.company, name="Tugagan", employee=self.usta, status=StepStatus.COMPLETED,
        )
        far_deadline = WorkflowStepInstance.objects.create(
            company=self.company, name="Uzoq muddat", employee=self.usta, status=StepStatus.PENDING,
            deadline=today + timedelta(days=10),
        )
        no_deadline = WorkflowStepInstance.objects.create(
            company=self.company, name="Muddatsiz", employee=self.usta, status=StepStatus.PENDING,
        )
        soon_deadline = WorkflowStepInstance.objects.create(
            company=self.company, name="Yaqin muddat", employee=self.usta, status=StepStatus.IN_PROGRESS,
            deadline=today + timedelta(days=1),
        )
        self.client.force_authenticate(self.usta_user)
        resp = self.client.get("/api/v1/workflow-instances/")
        names = [row["name"] for row in resp.data["results"]]
        # in_progress (muddati yaqin) -> pending (muddati yaqin) -> pending (muddatsiz) -> completed
        self.assertEqual(names, ["Yaqin muddat", "Uzoq muddat", "Muddatsiz", "Tugagan"])


class PayslipRecomputeTests(TestCase):
    """Regressiya: birlashtirishdan keyin qo'lda vazifalar bonus_per_task
    bo'yicha, retsept bosqichlari esa cost bo'yicha hisoblanishi, ikkalasi
    bir-birining ustiga qo'shilib ketmasligi kerak."""

    def test_manual_and_recipe_completions_are_counted_separately(self):
        from datetime import date

        from apps.production.models import Payslip

        owner = User.objects.create_user(email="owner2@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="Shop2", slug="shop2")
        worker_user = User.objects.create_user(email="usta2@shop.uz", password="pass12345", role=User.Role.EMPLOYEE)
        employee = Employee.objects.create(
            company=company, user=worker_user, positions=["usta"],
            base_salary=Decimal("1000000"), bonus_per_task=Decimal("5000"),
        )

        from django.utils import timezone

        now = timezone.now()
        WorkflowStepInstance.objects.create(
            company=company, name="Qo'lda vazifa", employee=employee,
            status=StepStatus.COMPLETED, completed_at=now, cost=0,
        )
        WorkflowStepInstance.objects.create(
            company=company, name="Retsept bosqichi", employee=employee,
            template_step=WorkflowStep.objects.create(
                product=Product.objects.create(
                    company=company,
                    category=Category.objects.create(name_uz="Stul", slug="stul-x"),
                    name_uz="Stul", is_published=True,
                ),
                name="Yig'ish",
            ),
            status=StepStatus.COMPLETED, completed_at=now, cost=Decimal("15000"),
        )

        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()

        self.assertEqual(payslip.tasks_completed, 1)  # faqat qo'lda vazifa
        self.assertEqual(payslip.bonus_amount, Decimal("5000"))
        self.assertEqual(payslip.workflow_earnings, Decimal("15000"))  # ikkalasining cost yig'indisi (0 + 15000)
        self.assertEqual(payslip.total_amount, Decimal("1000000") + Decimal("5000") + Decimal("15000"))


class CapacityAndPredictionTests(APITestCase):
    """Ishlab chiqarish rejalashtirish: xodimlar bandligi va navbatni
    hisobga oladigan taxminiy tugash muddati."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.worker_user = User.objects.create_user(
            email="usta@shop.uz", password="pass12345", role=User.Role.EMPLOYEE
        )
        self.employee = Employee.objects.create(
            company=self.company, user=self.worker_user, positions=["usta"]
        )
        self.customer = User.objects.create_user(
            email="mijoz@test.uz", password="pass12345", role=User.Role.CUSTOMER
        )
        self.client = APIClient()

    def test_capacity_reflects_pending_workload(self):
        WorkflowStepInstance.objects.create(
            company=self.company, name="Yig'ish", employee=self.employee,
            status=StepStatus.PENDING, estimated_hours=Decimal("3"),
        )
        WorkflowStepInstance.objects.create(
            company=self.company, name="Bo'yash", employee=self.employee,
            status=StepStatus.IN_PROGRESS, estimated_hours=Decimal("2"),
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/workflow-capacity/")
        self.assertEqual(resp.status_code, 200, resp.data)
        row = next(r for r in resp.data if r["employee"] == str(self.employee.id))
        self.assertEqual(row["total_count"], 2)
        self.assertEqual(row["in_progress_count"], 1)
        self.assertEqual(row["pending_hours"], 5.0)

    def test_capacity_ignores_completed_steps(self):
        WorkflowStepInstance.objects.create(
            company=self.company, name="Kesish", employee=self.employee,
            status=StepStatus.COMPLETED, estimated_hours=Decimal("4"),
        )
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/workflow-capacity/")
        row = next(r for r in resp.data if r["employee"] == str(self.employee.id))
        self.assertEqual(row["total_count"], 0)
        self.assertEqual(row["pending_hours"], 0)

    def test_prediction_accounts_for_employee_backlog_on_other_orders(self):
        order1 = Order.objects.create(
            company=self.company, customer=self.customer, phone="+998900000000",
            address="Toshkent", status=Order.Status.IN_PRODUCTION,
        )
        order2 = Order.objects.create(
            company=self.company, customer=self.customer, phone="+998900000001",
            address="Toshkent", status=Order.Status.IN_PRODUCTION,
        )
        # order1'ning ustasi allaqachon order2'da band (boshqa buyurtmada navbatda).
        WorkflowStepInstance.objects.create(
            company=self.company, order=order2, name="Boshqa buyurtma ishi",
            employee=self.employee, status=StepStatus.PENDING, estimated_hours=Decimal("10"),
        )
        WorkflowStepInstance.objects.create(
            company=self.company, order=order1, name="Yig'ish",
            employee=self.employee, status=StepStatus.PENDING, estimated_hours=Decimal("2"),
        )

        self.client.force_authenticate(self.owner)
        resp = self.client.get(f"/api/v1/orders/{order1.id}/prediction/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["own_hours"], 2.0)
        self.assertEqual(resp.data["queue_hours"], 10.0)
        self.assertEqual(resp.data["remaining_hours"], 12.0)
