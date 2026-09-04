from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from apps.companies.models import Company, Employee, PayType, PositionPayStandard
from apps.orders.models import Order

from .models import Payslip, PayslipPayment

User = get_user_model()


def make_owner_and_company(email="owner@pay.uz", slug="pay-shop"):
    owner = User.objects.create_user(email=email, password="pass12345", role=User.Role.COMPANY_OWNER)
    company = Company.objects.create(owner=owner, name="Pay Shop", slug=slug)
    return owner, company


def make_employee(company, position="usta", email="worker@pay.uz", **fields):
    user = User.objects.create_user(email=email, password="pass12345", role=User.Role.EMPLOYEE)
    return Employee.objects.create(company=company, user=user, positions=[position], **fields)


class PayTypeRecomputeTests(TestCase):
    """To'rtta to'lov turining har biri to'g'ri hisoblanishini tekshiradi."""

    def test_fixed_ignores_tasks_and_bonus(self):
        _, company = make_owner_and_company()
        employee = make_employee(
            company, pay_type=PayType.FIXED, base_salary=Decimal("2000000"), bonus_per_task=Decimal("9999")
        )
        now = timezone.now()
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertEqual(payslip.base_salary, Decimal("2000000"))
        self.assertEqual(payslip.bonus_amount, 0)
        self.assertEqual(payslip.total_amount, Decimal("2000000"))

    def test_commission_sums_completed_orders_sold_by_employee(self):
        _, company = make_owner_and_company(email="owner3@pay.uz", slug="pay-shop-3")
        employee = make_employee(
            company, position="sotuvchi", email="sales@pay.uz",
            pay_type=PayType.COMMISSION, commission_percent=Decimal("10"),
        )
        customer = User.objects.create_user(email="cust@pay.uz", password="pass12345", role=User.Role.CUSTOMER)
        Order.objects.create(
            company=company, customer=customer, phone="+998", address="x",
            total_price=Decimal("1000000"), status=Order.Status.COMPLETED, sold_by=employee,
        )
        # Boshqa xodimga tegishli buyurtma — hisobga kirmasligi kerak
        other = make_employee(company, position="sotuvchi", email="other@pay.uz")
        Order.objects.create(
            company=company, customer=customer, phone="+998", address="x",
            total_price=Decimal("5000000"), status=Order.Status.COMPLETED, sold_by=other,
        )
        now = timezone.now()
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertEqual(payslip.commission_sales, Decimal("1000000"))
        self.assertEqual(payslip.commission_amount, Decimal("100000"))
        self.assertEqual(payslip.total_amount, Decimal("100000"))

    def test_hourly_computed_from_attendance_records(self):
        from apps.attendance.models import AttendanceAction, AttendanceRecord, AttendanceStatus, Workplace

        _, company = make_owner_and_company(email="owner4@pay.uz", slug="pay-shop-4")
        employee = make_employee(
            company, position="haydovchi", email="driver@pay.uz",
            pay_type=PayType.HOURLY, hourly_rate=Decimal("20000"),
        )
        workplace = Workplace.objects.create(
            company=company, name="Filial", latitude=Decimal("41.311081"), longitude=Decimal("69.240562"),
        )
        now = timezone.now()
        check_in = AttendanceRecord.objects.create(
            employee=employee, workplace=workplace, action=AttendanceAction.CHECK_IN,
            latitude=workplace.latitude, longitude=workplace.longitude, status=AttendanceStatus.APPROVED,
        )
        check_in.server_timestamp = now
        check_in.save(update_fields=["server_timestamp"])
        check_out = AttendanceRecord.objects.create(
            employee=employee, workplace=workplace, action=AttendanceAction.CHECK_OUT,
            latitude=workplace.latitude, longitude=workplace.longitude, status=AttendanceStatus.APPROVED,
        )
        check_out.server_timestamp = now + timedelta(hours=8)
        check_out.save(update_fields=["server_timestamp"])

        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertEqual(payslip.worked_hours, Decimal("8"))
        self.assertEqual(payslip.hourly_amount, Decimal("160000"))
        self.assertEqual(payslip.total_amount, Decimal("160000"))

    def test_fixed_bonus_pays_higher_of_salary_or_tasks(self):
        from apps.workflow.models import StepStatus, WorkflowStepInstance

        _, company = make_owner_and_company(email="owner5@pay.uz", slug="pay-shop-5")
        employee = make_employee(
            company, position="usta", email="usta5@pay.uz",
            pay_type=PayType.FIXED_BONUS, base_salary=Decimal("5000000"),
        )
        now = timezone.now()
        # Misol 1: bajarilgan ishlar oylikdan kam — oylik to'lanadi.
        WorkflowStepInstance.objects.create(
            company=company, name="Kam ish", employee=employee,
            status=StepStatus.COMPLETED, completed_at=now, cost=Decimal("3500000"),
        )
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertEqual(payslip.total_amount, Decimal("5000000"))

        # Misol 2: bajarilgan ishlar oylikdan oshadi — oshgan summa to'lanadi.
        WorkflowStepInstance.objects.create(
            company=company, name="Ko'p ish", employee=employee,
            status=StepStatus.COMPLETED, completed_at=now, cost=Decimal("3500000"),
        )
        payslip.recompute()
        self.assertEqual(payslip.completed_tasks_amount, Decimal("7000000"))
        self.assertEqual(payslip.bonus_amount, Decimal("2000000"))
        self.assertEqual(payslip.total_amount, Decimal("7000000"))

    def test_piecework_pays_only_completed_task_value(self):
        from apps.workflow.models import StepStatus, WorkflowStepInstance

        _, company = make_owner_and_company(email="owner6@pay.uz", slug="pay-shop-6")
        employee = make_employee(
            company, position="usta", email="usta6@pay.uz", pay_type=PayType.PIECEWORK,
            base_salary=Decimal("9999999"),  # ISHBAY'da e'tiborga olinmasligi kerak
        )
        now = timezone.now()
        for cost in (Decimal("500000"), Decimal("1200000"), Decimal("900000")):
            WorkflowStepInstance.objects.create(
                company=company, name="Vazifa", employee=employee,
                status=StepStatus.COMPLETED, completed_at=now, cost=cost,
            )
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertEqual(payslip.base_salary, 0)
        self.assertEqual(payslip.total_amount, Decimal("2600000"))


class KpiBonusTests(TestCase):
    """PositionPayStandard'dagi KPI maqsadi bajarilsa multiplikator qo'llanishi,
    aks holda qo'llanmasligi kerak. Firma standarti platforma standartidan ustun."""

    def _employee_with_tasks(self, company, tasks_count, position="usta"):
        from apps.workflow.models import StepStatus, WorkflowStepInstance

        employee = make_employee(
            company, position=position, email=f"kpi-{tasks_count}-{position}@pay.uz",
            pay_type=PayType.FIXED, base_salary=Decimal("1000000"),
        )
        now = timezone.now()
        for i in range(tasks_count):
            WorkflowStepInstance.objects.create(
                company=company, name=f"Vazifa {i}", employee=employee,
                status=StepStatus.COMPLETED, completed_at=now, cost=0,
            )
        return employee

    def test_kpi_met_applies_multiplier(self):
        _, company = make_owner_and_company(email="owner5@pay.uz", slug="pay-shop-5")
        PositionPayStandard.objects.create(
            company=None, position="usta", kpi_target_tasks_per_month=2, kpi_bonus_multiplier=Decimal("1.2")
        )
        employee = self._employee_with_tasks(company, tasks_count=3)
        now = timezone.now()
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertTrue(payslip.kpi_met)
        self.assertEqual(payslip.kpi_bonus_amount, Decimal("1000000") * Decimal("0.2"))
        self.assertEqual(payslip.total_amount, Decimal("1200000"))

    def test_kpi_not_met_gives_no_bonus(self):
        _, company = make_owner_and_company(email="owner6@pay.uz", slug="pay-shop-6")
        PositionPayStandard.objects.create(
            company=None, position="usta", kpi_target_tasks_per_month=5, kpi_bonus_multiplier=Decimal("1.2")
        )
        employee = self._employee_with_tasks(company, tasks_count=2)
        now = timezone.now()
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertFalse(payslip.kpi_met)
        self.assertEqual(payslip.kpi_bonus_amount, 0)
        self.assertEqual(payslip.total_amount, Decimal("1000000"))

    def test_company_standard_overrides_platform_standard(self):
        _, company = make_owner_and_company(email="owner7@pay.uz", slug="pay-shop-7")
        PositionPayStandard.objects.create(
            company=None, position="usta", kpi_target_tasks_per_month=100, kpi_bonus_multiplier=Decimal("1.5")
        )
        PositionPayStandard.objects.create(
            company=company, position="usta", kpi_target_tasks_per_month=1, kpi_bonus_multiplier=Decimal("1.1")
        )
        employee = self._employee_with_tasks(company, tasks_count=2)
        now = timezone.now()
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        # Platforma standarti (100 ta vazifa) bajarilmagan bo'lardi, lekin firma
        # o'ziniki (1 ta) ustun bo'lishi va bajarilgan deb hisoblanishi kerak.
        self.assertTrue(payslip.kpi_met)
        self.assertEqual(payslip.kpi_bonus_amount, Decimal("1000000") * Decimal("0.1"))

    def test_on_time_target_checked_against_deadline(self):
        from apps.workflow.models import StepStatus, WorkflowStepInstance

        _, company = make_owner_and_company(email="owner8@pay.uz", slug="pay-shop-8")
        PositionPayStandard.objects.create(
            company=None, position="usta", kpi_target_on_time_percent=Decimal("90"),
            kpi_bonus_multiplier=Decimal("1.5"),
        )
        employee = make_employee(
            company, position="usta", email="late@pay.uz", pay_type=PayType.FIXED, base_salary=Decimal("1000000")
        )
        now = timezone.now()
        # Muddatidan kech bajarilgan — KPI bajarilmagan bo'lishi kerak
        WorkflowStepInstance.objects.create(
            company=company, name="Kech", employee=employee, status=StepStatus.COMPLETED,
            completed_at=now, deadline=(now - timedelta(days=1)).date(), cost=0,
        )
        payslip = Payslip.objects.create(company=company, employee=employee, period=date(now.year, now.month, 1))
        payslip.recompute()
        self.assertFalse(payslip.kpi_met)
        self.assertEqual(payslip.kpi_bonus_amount, 0)


class PositionPayStandardPermissionTests(TestCase):
    """Platforma admini faqat global (`company=None`), firma egasi faqat
    o'z firmasi standartlarini yarata olishi — API orqali cheklangan."""

    def setUp(self):
        from rest_framework.test import APIClient

        self.client_api = APIClient()

    def test_firma_owner_cannot_create_global_standard(self):
        owner, company = make_owner_and_company(email="owner9@pay.uz", slug="pay-shop-9")
        self.client_api.force_authenticate(owner)
        resp = self.client_api.post(
            "/api/v1/pay-standards/",
            {"position": "usta", "pay_type": "fixed"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403, resp.data)

    def test_firma_owner_creates_own_company_standard(self):
        owner, company = make_owner_and_company(email="owner10@pay.uz", slug="pay-shop-10")
        self.client_api.force_authenticate(owner)
        resp = self.client_api.post(
            "/api/v1/pay-standards/",
            {"company": str(company.id), "position": "usta", "pay_type": "fixed"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)

    def test_firma_owner_cannot_create_standard_for_other_company(self):
        owner, company = make_owner_and_company(email="owner11@pay.uz", slug="pay-shop-11")
        _, other_company = make_owner_and_company(email="owner12@pay.uz", slug="pay-shop-12")
        self.client_api.force_authenticate(owner)
        resp = self.client_api.post(
            "/api/v1/pay-standards/",
            {"company": str(other_company.id), "position": "usta", "pay_type": "fixed"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403, resp.data)

    def test_duplicate_position_standard_rejected(self):
        owner, company = make_owner_and_company(email="owner13@pay.uz", slug="pay-shop-13")
        PositionPayStandard.objects.create(company=company, position="usta")
        self.client_api.force_authenticate(owner)
        resp = self.client_api.post(
            "/api/v1/pay-standards/",
            {"company": str(company.id), "position": "usta", "pay_type": "hourly"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400, resp.data)

    def test_platform_admin_creates_global_standard(self):
        admin = User.objects.create_user(email="admin@pay.uz", password="pass12345", role="platform_admin")
        self.client_api.force_authenticate(admin)
        resp = self.client_api.post(
            "/api/v1/pay-standards/",
            {"position": "usta", "pay_type": "fixed_bonus", "kpi_bonus_multiplier": "1.1"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertTrue(resp.data["is_platform_default"])


class PayslipPaymentTests(TestCase):
    """Avans/qisman to'lov oqimi — portable payroll dizayn hujjatidagi
    "kassa asosida, hisoblangandan alohida" tamoyili."""

    def setUp(self):
        from rest_framework.test import APIClient

        self.client_api = APIClient()
        self.owner, self.company = make_owner_and_company(email="owner14@pay.uz", slug="pay-shop-14")
        self.employee = make_employee(
            self.company, email="worker14@pay.uz", pay_type=PayType.FIXED, base_salary=Decimal("3000000")
        )
        now = timezone.now()
        self.payslip = Payslip.objects.create(
            company=self.company, employee=self.employee, period=date(now.year, now.month, 1)
        )
        self.payslip.recompute()
        self.payslip.save()

    def test_advance_reduces_outstanding_without_marking_paid(self):
        self.assertEqual(self.payslip.outstanding_amount, Decimal("3000000"))
        self.client_api.force_authenticate(self.owner)
        resp = self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "advance", "amount": "1000000", "note": "Avans"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.payslip.refresh_from_db()
        self.assertEqual(self.payslip.paid_total, Decimal("1000000"))
        self.assertEqual(self.payslip.outstanding_amount, Decimal("2000000"))
        self.assertFalse(self.payslip.is_paid)

    def test_final_payment_covering_outstanding_marks_paid(self):
        self.client_api.force_authenticate(self.owner)
        self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "advance", "amount": "1000000"},
            format="json",
        )
        resp = self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "final", "amount": "2000000"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.payslip.refresh_from_db()
        self.assertTrue(self.payslip.is_paid)
        self.assertEqual(self.payslip.outstanding_amount, 0)
        self.assertEqual(PayslipPayment.objects.filter(payslip=self.payslip).count(), 2)

    def test_overpayment_rejected(self):
        self.client_api.force_authenticate(self.owner)
        resp = self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "final", "amount": "5000000"},
            format="json",
        )
        self.assertEqual(resp.status_code, 400)
        self.payslip.refresh_from_db()
        self.assertEqual(self.payslip.paid_total, 0)

    def test_employee_cannot_add_payment(self):
        self.client_api.force_authenticate(self.employee.user)
        resp = self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "advance", "amount": "500000"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_employee_can_view_own_payment_history(self):
        self.client_api.force_authenticate(self.owner)
        self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "advance", "amount": "500000"},
            format="json",
        )
        self.client_api.force_authenticate(self.employee.user)
        resp = self.client_api.get(f"/api/v1/payslips/{self.payslip.id}/payments/")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(len(resp.data), 1)

    def test_mark_paid_creates_final_payment_for_full_outstanding(self):
        self.client_api.force_authenticate(self.owner)
        resp = self.client_api.post(f"/api/v1/payslips/{self.payslip.id}/mark_paid/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.payslip.refresh_from_db()
        self.assertTrue(self.payslip.is_paid)
        self.assertEqual(self.payslip.paid_total, Decimal("3000000"))
        payment = PayslipPayment.objects.get(payslip=self.payslip)
        self.assertEqual(payment.kind, PayslipPayment.Kind.FINAL)

    def test_recompute_blocked_once_payment_exists(self):
        self.client_api.force_authenticate(self.owner)
        self.client_api.post(
            f"/api/v1/payslips/{self.payslip.id}/payments/",
            {"kind": "advance", "amount": "500000"},
            format="json",
        )
        now = timezone.now()
        resp = self.client_api.post(
            "/api/v1/payslips/generate/",
            {"period": f"{now.year}-{now.month:02d}"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200)
        self.payslip.refresh_from_db()
        # base_salary shu paytgacha o'zgarmaganidan tashqari, hech bo'lmasa
        # `paid_total` (avans) daxlsiz qolganini tekshiramiz.
        self.assertEqual(self.payslip.paid_total, Decimal("500000"))
