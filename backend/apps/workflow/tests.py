from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient, APITestCase

from apps.companies.models import Company, Employee
from apps.orders.models import Order
from apps.products.models import Category, Product, Variant

from .models import StepStatus, WorkflowStep, WorkflowStepInstance, WorkType
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
        self.assertEqual(payslip.workflow_earnings, Decimal("15000"))  # ikkalasining cost yig'indisi (0 + 15000)
        # completed_tasks_amount = workflow_earnings + bonus_per_task*tasks_completed = 15000+5000 = 20000
        self.assertEqual(payslip.completed_tasks_amount, Decimal("20000"))
        # FIXED_BONUS: total = max(oylik, bajarilgan ishlar summasi) — oylik ustun bo'lgani uchun
        # bonus_amount (ko'rsatiladigan "oshgan qism") 0, jami = oylik.
        self.assertEqual(payslip.bonus_amount, Decimal("0"))
        self.assertEqual(payslip.total_amount, Decimal("1000000"))


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


class WorkTypeTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="owner3@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop3", slug="shop3")
        self.category = Category.objects.create(name_uz="Stullar3", slug="stullar3")
        self.product = Product.objects.create(company=self.company, category=self.category, name_uz="Stul", is_published=True)
        self.client = APIClient()

    def test_owner_creates_work_type(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/work-types/",
            {"stage": "cutting", "name": "Rekani kesish", "unit": "m", "price_per_unit": "5000", "required_role": "usta"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(WorkType.objects.count(), 1)

    def test_workflow_step_cost_auto_computed_from_work_type(self):
        work_type = WorkType.objects.create(
            company=self.company, name="Rekani kesish", unit="m",
            price_per_unit=Decimal("5000"), required_role="usta",
        )
        step = WorkflowStep.objects.create(
            product=self.product, name="Kesish", work_type=work_type, quantity=Decimal("3"),
        )
        self.assertEqual(step.cost, Decimal("15000.00"))
        self.assertEqual(step.role, "usta")

        # Narx o'zgarsa, MAVJUD bosqichning cost'i o'zgarmaydi (faqat qayta
        # save() qilinganda qayta hisoblanadi) - lekin YANGI save() chaqirilsa
        # yangi narx bilan qayta hisoblanishi kerak (shablon hali "jonli").
        work_type.price_per_unit = Decimal("6000")
        work_type.save()
        step.refresh_from_db()
        self.assertEqual(step.cost, Decimal("15000.00"))  # eski qiymat saqlanadi
        step.save()
        self.assertEqual(step.cost, Decimal("18000.00"))  # qayta save()da yangilanadi

    def test_workflow_step_without_work_type_keeps_manual_cost(self):
        step = WorkflowStep.objects.create(product=self.product, name="Qo'lda", cost=Decimal("25000"))
        self.assertEqual(step.cost, Decimal("25000.00"))

    def test_instance_snapshots_work_type_and_quantity_at_creation(self):
        work_type = WorkType.objects.create(
            company=self.company, name="Kromkalash", unit="m", price_per_unit=Decimal("2000"),
        )
        WorkflowStep.objects.create(
            product=self.product, name="Kromkalash", work_type=work_type, quantity=Decimal("4"),
        )
        customer = User.objects.create_user(email="mijoz3@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        order = Order.objects.create(company=self.company, customer=customer, phone="+998900000002", address="Toshkent")
        instances = create_workflow_instances(order, self.product)
        self.assertEqual(len(instances), 1)
        instance = instances[0]
        self.assertEqual(instance.work_type_id, work_type.id)
        self.assertEqual(instance.quantity, Decimal("4.000"))
        self.assertEqual(instance.cost, Decimal("8000.00"))

        # Shablon narxi keyinroq o'zgarsa ham, allaqachon yaratilgan
        # instance'ning cost'i o'zgarmasligi kerak (snapshot).
        work_type.price_per_unit = Decimal("9999")
        work_type.save()
        instance.refresh_from_db()
        self.assertEqual(instance.cost, Decimal("8000.00"))


class MaterialConsumptionAndPayrollTests(APITestCase):
    """'Bajardim' bosilganda ombor va ish haqi avtomatik yangilanishi kerak
    (bitta atomik amalda) — spetsifikatsiyaning eng muhim talabi."""

    def setUp(self):
        from datetime import date

        from apps.inventory.models import Material, MaterialStock, Warehouse
        from apps.production.models import Payslip, PayType

        self.owner = User.objects.create_user(email="owner4@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop4", slug="shop4")
        self.worker_user = User.objects.create_user(email="usta4@shop.uz", password="pass12345", role=User.Role.EMPLOYEE)
        self.employee = Employee.objects.create(
            company=self.company, user=self.worker_user, positions=["usta"],
            pay_type=PayType.FIXED, base_salary=Decimal("1000000"),
        )
        self.warehouse = Warehouse.objects.create(
            company=self.company, name="Xom ashyo ombori", kind=Warehouse.Kind.RAW_MATERIAL, address="Toshkent",
        )
        self.material = Material.objects.create(company=self.company, name="Reyka", unit="m")
        self.stock = MaterialStock.objects.create(warehouse=self.warehouse, material=self.material, quantity=Decimal("10"))
        self.period = date.today().replace(day=1)
        self.client = APIClient()

    def _make_instance(self, quantity=Decimal("4")):
        return WorkflowStepInstance.objects.create(
            company=self.company, name="Kesish", employee=self.employee,
            raw_material=self.material, quantity=quantity, cost=Decimal("1000"),
        )

    def test_complete_deducts_stock_and_creates_movement(self):
        from apps.inventory.models import MaterialMovement

        instance = self._make_instance()
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)

        self.stock.refresh_from_db()
        self.assertEqual(self.stock.quantity, Decimal("6.000"))
        movement = MaterialMovement.objects.get(workflow_instance=instance)
        self.assertEqual(movement.movement_type, MaterialMovement.Type.OUT)
        self.assertEqual(movement.quantity, Decimal("4.000"))

        instance.refresh_from_db()
        self.assertTrue(instance.material_consumed)

    def test_complete_blocked_when_insufficient_stock(self):
        instance = self._make_instance(quantity=Decimal("100"))
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 400, resp.data)

        instance.refresh_from_db()
        self.assertNotEqual(instance.status, StepStatus.COMPLETED)
        self.stock.refresh_from_db()
        self.assertEqual(self.stock.quantity, Decimal("10.000"))

    def test_double_consumption_guarded_by_material_consumed_flag(self):
        from .services import consume_material_on_completion

        instance = self._make_instance()
        consume_material_on_completion(instance, self.owner)
        consume_material_on_completion(instance, self.owner)  # ikkinchi chaqiruv hech narsa qilmasligi kerak

        self.stock.refresh_from_db()
        self.assertEqual(self.stock.quantity, Decimal("6.000"))

    def test_complete_credits_payslip_immediately(self):
        """Payroll usta "Bajardim" bosishi bilanoq kreditlanadi — firma
        egasi/menejer tasdiqlashini (`approve()`) kutmaydi (qarang
        test_owner_approve_credits_payslip — u shu hisobni yana bir bor
        tasdiqlaydi, xolos)."""
        from apps.production.models import Payslip

        instance = self._make_instance()
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "completed")

        payslip = Payslip.objects.get(company=self.company, employee=self.employee, period=self.period)
        self.assertEqual(payslip.base_salary, Decimal("1000000"))

    def test_owner_approve_credits_payslip(self):
        from apps.production.models import Payslip

        instance = self._make_instance()
        self.client.force_authenticate(self.owner)
        self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")

        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/approve/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "approved")

        payslip = Payslip.objects.get(company=self.company, employee=self.employee, period=self.period)
        self.assertEqual(payslip.base_salary, Decimal("1000000"))

    def test_cannot_approve_unfinished_step(self):
        instance = self._make_instance()
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/approve/", {}, format="json")
        self.assertEqual(resp.status_code, 400, resp.data)

    def test_employee_cannot_approve(self):
        instance = self._make_instance()
        self.client.force_authenticate(self.owner)
        self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")

        self.client.force_authenticate(self.worker_user)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/approve/", {}, format="json")
        self.assertEqual(resp.status_code, 403, resp.data)

    def test_paid_payslip_not_recomputed(self):
        from apps.production.models import Payslip
        from .services import approve_step_and_credit_payroll

        payslip = Payslip.objects.create(
            company=self.company, employee=self.employee, period=self.period,
            is_paid=True, total_amount=Decimal("500000"),
        )
        from django.utils import timezone

        instance = WorkflowStepInstance.objects.create(
            company=self.company, name="Yig'ish", employee=self.employee,
            status=StepStatus.COMPLETED, completed_at=timezone.now(), cost=Decimal("1000"),
        )
        approve_step_and_credit_payroll(instance, self.owner)

        payslip.refresh_from_db()
        self.assertEqual(payslip.total_amount, Decimal("500000"))


class CancelStepTests(APITestCase):
    """Bekor qilish: ombordan ayirilgan material qaytariladi, kreditlangan
    ish haqi (agar tasdiqlangan edi) chiqarib tashlanadi."""

    def setUp(self):
        from datetime import date

        from apps.inventory.models import Material, MaterialStock, Warehouse
        from apps.production.models import PayType

        self.owner = User.objects.create_user(email="owner6@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop6", slug="shop6")
        self.worker_user = User.objects.create_user(email="usta6@shop.uz", password="pass12345", role=User.Role.EMPLOYEE)
        self.employee = Employee.objects.create(
            company=self.company, user=self.worker_user, positions=["usta"],
            pay_type=PayType.FIXED, base_salary=Decimal("1000000"),
        )
        self.warehouse = Warehouse.objects.create(
            company=self.company, name="Xom ashyo ombori", kind=Warehouse.Kind.RAW_MATERIAL, address="Toshkent",
        )
        self.material = Material.objects.create(company=self.company, name="Reyka", unit="m")
        self.stock = MaterialStock.objects.create(warehouse=self.warehouse, material=self.material, quantity=Decimal("10"))
        self.period = date.today().replace(day=1)
        self.client = APIClient()
        self.client.force_authenticate(self.owner)

    def _completed_instance(self, quantity=Decimal("4")):
        instance = WorkflowStepInstance.objects.create(
            company=self.company, name="Kesish", employee=self.employee,
            raw_material=self.material, quantity=quantity, cost=Decimal("1000"),
        )
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/complete/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        instance.refresh_from_db()
        return instance

    def test_cancel_returns_material_to_stock(self):
        from apps.inventory.models import MaterialMovement

        instance = self._completed_instance()
        self.stock.refresh_from_db()
        self.assertEqual(self.stock.quantity, Decimal("6.000"))

        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "cancelled")

        self.stock.refresh_from_db()
        self.assertEqual(self.stock.quantity, Decimal("10.000"))
        self.assertTrue(
            MaterialMovement.objects.filter(workflow_instance=instance, movement_type=MaterialMovement.Type.RETURN).exists()
        )

    def test_cancel_after_approval_removes_payroll_credit(self):
        from apps.production.models import Payslip

        instance = self._completed_instance()
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/approve/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        payslip = Payslip.objects.get(company=self.company, employee=self.employee, period=self.period)
        self.assertEqual(payslip.workflow_earnings, Decimal("1000.00"))

        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)

        payslip.refresh_from_db()
        self.assertEqual(payslip.workflow_earnings, 0)

    def test_cancel_never_approved_step_removes_payroll_credit(self):
        """Ish haqi endi "Bajardim" bosilishi bilanoq kreditlanadi (hali
        tasdiqlanmagan bo'lsa ham) — bekor qilinsa, shu hissa ham darhol
        olib tashlanishi kerak (qarang test_cancel_after_approval_removes_payroll_credit
        — tasdiqlangan holat uchun bir xil tekshiruv)."""
        from apps.production.models import Payslip

        instance = self._completed_instance()
        payslip = Payslip.objects.get(company=self.company, employee=self.employee, period=self.period)
        self.assertEqual(payslip.workflow_earnings, Decimal("1000.00"))

        self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")

        payslip.refresh_from_db()
        self.assertEqual(payslip.workflow_earnings, 0)

    def test_cannot_cancel_twice(self):
        instance = self._completed_instance()
        self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 400, resp.data)

    def test_employee_cannot_cancel(self):
        instance = self._completed_instance()
        self.client.force_authenticate(self.worker_user)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 403, resp.data)

    def test_pending_step_can_be_cancelled_without_reversal(self):
        instance = WorkflowStepInstance.objects.create(company=self.company, name="Yig'ish")
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "cancelled")


class CuttingInstructionTests(TestCase):
    def setUp(self):
        from apps.inventory.models import Material

        self.owner = User.objects.create_user(email="owner5@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop5", slug="shop5")
        self.category = Category.objects.create(name_uz="Stullar5", slug="stullar5")
        self.product = Product.objects.create(company=self.company, category=self.category, name_uz="Stul", is_published=True)
        self.material = Material.objects.create(company=self.company, name="Reyka", unit="m")

    def test_instruction_built_from_cut_fields(self):
        step = WorkflowStep.objects.create(
            product=self.product, name="Kesish", raw_material=self.material,
            cut_piece_length=Decimal("0.8"), cut_piece_count=4, cut_note="stol oyoqlari uchun",
        )
        self.assertEqual(step.cutting_instruction, "Reykadan 0.8m x 4 dona kes (stol oyoqlari uchun)")

    def test_no_instruction_without_cut_length(self):
        step = WorkflowStep.objects.create(product=self.product, name="Yig'ish", raw_material=self.material)
        self.assertIsNone(step.cutting_instruction)

    def test_no_instruction_without_raw_material(self):
        step = WorkflowStep.objects.create(product=self.product, name="Kesish", cut_piece_length=Decimal("0.8"))
        self.assertIsNone(step.cutting_instruction)

    def test_instance_snapshots_cutting_fields(self):
        step = WorkflowStep.objects.create(
            product=self.product, name="Kesish", raw_material=self.material,
            cut_piece_length=Decimal("0.8"), cut_piece_width=Decimal("0.04"), cut_piece_count=4,
        )
        customer = User.objects.create_user(email="mijoz5@test.uz", password="pass12345", role=User.Role.CUSTOMER)
        order = Order.objects.create(company=self.company, customer=customer, phone="+998900000003", address="Toshkent")
        instances = create_workflow_instances(order, self.product)
        instance = instances[0]
        self.assertEqual(instance.cut_piece_length, Decimal("0.800"))
        self.assertEqual(instance.cut_piece_width, Decimal("0.040"))
        self.assertEqual(instance.cut_piece_count, 4)
        self.assertIn("0.800m x 0.040m x 4 dona", instance.cutting_instruction)

        # Shablon keyinroq o'zgarsa ham, allaqachon yaratilgan instansiya
        # o'zgarmaydi (snapshot).
        step.cut_piece_count = 99
        step.save()
        instance.refresh_from_db()
        self.assertEqual(instance.cut_piece_count, 4)


class OpenPoolManagerTests(APITestCase):
    """Firma egasi (odatda `positions`ga ega Employee yozuvi bo'lmaydi)
    "erkin topshiriqlar" hovuzida BARCHA ochiq bosqichlarni ko'rishi kerak
    (bekor qilish uchun), usta esa faqat o'z lavozimiga mos bosqichlarni."""

    def setUp(self):
        self.owner = User.objects.create_user(email="owner7@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.company = Company.objects.create(owner=self.owner, name="Shop7", slug="shop7")
        self.usta_user = User.objects.create_user(email="usta7@shop.uz", password="pass12345", role=User.Role.EMPLOYEE)
        Employee.objects.create(company=self.company, user=self.usta_user, positions=["usta"])
        WorkflowStepInstance.objects.create(company=self.company, name="Bo'yash", role="boyoqchi")
        self.client = APIClient()

    def test_owner_sees_all_open_steps_regardless_of_role(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/workflow-instances/open/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(len(resp.data["results"]), 1)

    def test_employee_only_sees_matching_role(self):
        self.client.force_authenticate(self.usta_user)
        resp = self.client.get("/api/v1/workflow-instances/open/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(len(resp.data["results"]), 0)

    def test_owner_can_cancel_open_step(self):
        instance = WorkflowStepInstance.objects.get(name="Bo'yash")
        self.client.force_authenticate(self.owner)
        resp = self.client.post(f"/api/v1/workflow-instances/{instance.id}/cancel/", {}, format="json")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["status"], "cancelled")
