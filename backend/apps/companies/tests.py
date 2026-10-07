from decimal import Decimal

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient, APITestCase

from apps.assets.models import Model3D
from apps.companies.models import Company, Employee, TariffPlan
from apps.products.models import Category, Product

User = get_user_model()


class TariffPlanTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            email="admin@platform.uz", password="pass12345", role=User.Role.PLATFORM_ADMIN
        )
        self.owner = User.objects.create_user(
            email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Shop", slug="shop")
        self.plan = TariffPlan.objects.create(
            name="Standart", price_per_employee=Decimal("1.00"), price_per_product=Decimal("1.00")
        )
        self.client = APIClient()

    def test_owner_cannot_create_tariff_plan(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.post(
            "/api/v1/tariff-plans/",
            {"name": "Firma o'zi", "price_per_employee": "5.00", "price_per_product": "5.00"},
            format="json",
        )
        self.assertEqual(resp.status_code, 403)

    def test_admin_can_create_and_owner_can_list(self):
        self.client.force_authenticate(self.admin)
        resp = self.client.post(
            "/api/v1/tariff-plans/",
            {"name": "Premium", "price_per_employee": "2.00", "price_per_product": "2.00"},
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)

        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/tariff-plans/")
        self.assertEqual(resp.status_code, 200)
        names = {p["name"] for p in resp.data["results"]}
        self.assertIn("Standart", names)
        self.assertIn("Premium", names)

    def test_inactive_plan_hidden_from_owner_but_visible_to_admin(self):
        TariffPlan.objects.create(name="Eskirgan", is_active=False)

        self.client.force_authenticate(self.owner)
        resp = self.client.get("/api/v1/tariff-plans/")
        names = {p["name"] for p in resp.data["results"]}
        self.assertNotIn("Eskirgan", names)

        self.client.force_authenticate(self.admin)
        resp = self.client.get("/api/v1/tariff-plans/")
        names = {p["name"] for p in resp.data["results"]}
        self.assertIn("Eskirgan", names)

    def test_owner_selects_plan_for_own_company(self):
        self.client.force_authenticate(self.owner)
        resp = self.client.patch(f"/api/v1/companies/{self.company.slug}/", {"tariff_plan": str(self.plan.id)})
        self.assertEqual(resp.status_code, 200, resp.data)
        self.company.refresh_from_db()
        self.assertEqual(self.company.tariff_plan_id, self.plan.id)

    def test_billing_summary_counts_employees_and_products_with_3d(self):
        self.company.tariff_plan = self.plan
        self.company.save(update_fields=["tariff_plan"])

        worker = User.objects.create_user(email="worker@shop.uz", password="pass12345")
        Employee.objects.create(company=self.company, user=worker, positions=["usta"], is_active=True)

        category = Category.objects.create(name_uz="Stullar", slug="stullar")
        product_with_3d = Product.objects.create(company=self.company, category=category, name_uz="3D li stul")
        Product.objects.create(company=self.company, category=category, name_uz="3D siz stol")
        Model3D.objects.create(product=product_with_3d, status="ready")

        summary = self.company.billing_summary
        self.assertEqual(summary["employee_count"], 1)
        self.assertEqual(summary["product_count"], 1)
        self.assertEqual(summary["total"], Decimal("2.00"))
        self.assertEqual(summary["plan"]["name"], "Standart")

    def test_billing_summary_without_plan_has_no_total(self):
        summary = self.company.billing_summary
        self.assertIsNone(summary["plan"])
        self.assertIsNone(summary["total"])


class EmployeeInvitationNotificationTests(APITestCase):
    """Ishga taklif oqimida bildirishnoma (in-app + push) yuborilishi —
    qarang apps.notifications.services.notify_employee_invited/
    notify_invitation_accepted/notify_invitation_declined."""

    def setUp(self):
        self.owner = User.objects.create_user(
            email="invite-owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        self.company = Company.objects.create(owner=self.owner, name="Invite Shop", slug="invite-shop")
        self.worker = User.objects.create_user(
            email="invite-worker@shop.uz", password="pass12345", role=User.Role.CUSTOMER, worker_id="INV001"
        )
        self.client = APIClient()

    def _invite(self):
        self.client.force_authenticate(self.owner)
        return self.client.post(
            "/api/v1/employee-invitations/",
            {"worker_id": "INV001", "positions": ["usta"], "pay_type": "fixed"},
            format="json",
        )

    def test_invite_notifies_invited_user(self):
        from apps.notifications.models import Notification, NotificationType

        resp = self._invite()
        self.assertEqual(resp.status_code, 201, resp.data)
        notif = Notification.objects.get(recipient=self.worker, notif_type=NotificationType.EMPLOYEE_INVITED)
        self.assertIn(self.company.name, notif.body)

    def test_employee_of_another_company_still_sees_received_invitations(self):
        from apps.companies.models import Employee

        # Ishchi allaqachon boshqa firmada faol xodim — unga yangi taklif kelsa ham
        # o'zining takliflar ro'yxatida ko'rinishi kerak (eskiden firma ro'yxati chiqardi).
        other_owner = User.objects.create_user(
            email="other-owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER
        )
        other = Company.objects.create(owner=other_owner, name="Other Shop", slug="other-shop")
        Employee.objects.create(company=other, user=self.worker, positions=["usta"], is_active=True)

        self.assertEqual(self._invite().status_code, 201)
        self.client.force_authenticate(self.worker)
        for url in ("/api/v1/employee-invitations/", "/api/v1/employee-invitations/?received=1"):
            data = self.client.get(url).json()
            results = data.get("results", data)
            self.assertEqual([i["status"] for i in results], ["pending"], url)

        # Egasi esa o'z yuborgan takliflarini ko'radi
        self.client.force_authenticate(self.owner)
        data = self.client.get("/api/v1/employee-invitations/").json()
        self.assertEqual(len(data.get("results", data)), 1)

    def test_reinviting_after_cancel_creates_visible_invitation(self):
        from apps.companies.models import EmployeeInvitation
        from apps.notifications.models import Notification, NotificationType

        first = self._invite().data["id"]
        # Egasi taklifni bekor qiladi (soft-delete), keyin qayta taklif qiladi
        self.assertEqual(self.client.delete(f"/api/v1/employee-invitations/{first}/").status_code, 204)
        second = self._invite()
        self.assertEqual(second.status_code, 201, second.data)
        self.assertNotEqual(second.data["id"], first)

        self.client.force_authenticate(self.worker)
        data = self.client.get("/api/v1/employee-invitations/?received=1").json()
        results = data.get("results", data)
        self.assertEqual([i["id"] for i in results], [second.data["id"]])
        self.assertEqual(EmployeeInvitation.objects.filter(is_deleted=False).count(), 1)

        # Ikki marta ketma-ket taklif qilinsa, ikkinchisi dublikat bildirishnoma yubormaydi
        self._invite()
        self.assertEqual(
            Notification.objects.filter(recipient=self.worker, notif_type=NotificationType.EMPLOYEE_INVITED).count(), 2
        )

    def test_accept_notifies_owner(self):
        from apps.notifications.models import Notification, NotificationType

        resp = self._invite()
        invitation_id = resp.data["id"]
        self.client.force_authenticate(self.worker)
        accept = self.client.post(f"/api/v1/employee-invitations/{invitation_id}/accept/")
        self.assertEqual(accept.status_code, 200, accept.data)
        notif = Notification.objects.get(
            recipient=self.owner, notif_type=NotificationType.EMPLOYEE_INVITATION_ACCEPTED
        )
        self.assertIn("qabul qildi", notif.body)

    def test_decline_notifies_owner(self):
        from apps.notifications.models import Notification, NotificationType

        resp = self._invite()
        invitation_id = resp.data["id"]
        self.client.force_authenticate(self.worker)
        decline = self.client.post(f"/api/v1/employee-invitations/{invitation_id}/decline/")
        self.assertEqual(decline.status_code, 200, decline.data)
        notif = Notification.objects.get(
            recipient=self.owner, notif_type=NotificationType.EMPLOYEE_INVITATION_DECLINED
        )
        self.assertIn("rad etdi", notif.body)
