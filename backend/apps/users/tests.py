from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from .models import GoogleAccount, PhoneOTP, User


class OTPFlowTests(TestCase):
    """Telefon-OTP orqali kirish oqimi — shu jumladan avvalroq topilgan ikkita
    real bug uchun regressiya testlari: (1) cooldown ishlatilgan kodni ham
    hisoblab, chiqib-qayta-kirishni bloklardi; (2) bloklangan foydalanuvchi
    OTP orqali baribir token ola olardi."""

    def _request_otp(self, phone="+998901234567"):
        return self.client.post(
            reverse("otp-request"), {"phone": phone}, content_type="application/json"
        )

    def _latest_code(self, phone="+998901234567"):
        return PhoneOTP.objects.filter(phone=phone).order_by("-created_at").first()

    def test_request_then_verify_creates_user_and_returns_tokens(self):
        resp = self._request_otp()
        self.assertEqual(resp.status_code, 200)
        otp = self._latest_code()
        self.assertIsNotNone(otp)

        resp = self.client.post(
            reverse("otp-verify"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn("access", resp.json())
        self.assertTrue(resp.json()["is_new_user"])
        self.assertTrue(User.objects.filter(phone="+998901234567").exists())

    def test_wrong_code_increments_attempts_and_eventually_locks(self):
        self._request_otp()
        otp = self._latest_code()
        for _ in range(PhoneOTP.MAX_ATTEMPTS):
            resp = self.client.post(
                reverse("otp-verify"),
                {"phone": "+998901234567", "code": "000000"},
                content_type="application/json",
            )
            self.assertEqual(resp.status_code, 400)
        otp.refresh_from_db()
        self.assertTrue(otp.attempts >= PhoneOTP.MAX_ATTEMPTS)

        # Kod endi to'g'ri bo'lsa ham, urinishlar tugagani uchun rad etiladi.
        resp = self.client.post(
            reverse("otp-verify"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_resend_cooldown_ignores_already_used_codes(self):
        """Regressiya: login qilib chiqib, darhol qayta kirmoqchi bo'lganda
        (avvalgi kod allaqachon ishlatilgan) 400 chiqmasligi kerak."""
        self._request_otp()
        otp = self._latest_code()
        self.client.post(
            reverse("otp-verify"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertTrue(PhoneOTP.objects.get(pk=otp.pk).is_used)

        resp = self._request_otp()
        self.assertEqual(resp.status_code, 200)

    def test_resend_cooldown_still_blocks_unused_code(self):
        self._request_otp()
        resp = self._request_otp()
        self.assertEqual(resp.status_code, 400)

    def test_blocked_user_cannot_verify_otp(self):
        """Regressiya: is_active=False bo'lgan foydalanuvchi OTP orqali ham
        token ololmasligi kerak (avval bu tekshiruv yo'q edi)."""
        user = User.objects.create(
            phone="+998901234567", email="+998901234567@phone.local", role=User.Role.CUSTOMER,
            is_active=False,
        )
        user.set_unusable_password()
        user.save()

        self._request_otp()
        otp = self._latest_code()
        resp = self.client.post(
            reverse("otp-verify"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_expired_code_rejected(self):
        self._request_otp()
        otp = self._latest_code()
        otp.created_at = timezone.now() - timedelta(minutes=10)
        otp.save(update_fields=["created_at"])

        resp = self.client.post(
            reverse("otp-verify"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)


class GoogleLoginTests(TestCase):
    """Google Login — token verifikatsiyasi `verify_google_credential`
    mock qilinadi (real Google'ga tarmoq so'rovi yubormaslik uchun), asosiy
    e'tibor account-linking mantig'ida: `google_sub` asosiy kalit, email
    hech qachon avtomatik bog'lash uchun ishlatilmaydi (hisobni egallab
    olishning oldini olish — qarang GoogleLoginView docstring)."""

    def _claims(self, sub="google-sub-1", email="user@example.com", **extra):
        return {
            "sub": sub,
            "email": email,
            "email_verified": True,
            "given_name": "Ali",
            "family_name": "Valiyev",
            **extra,
        }

    def _login(self, **claims_kwargs):
        with patch(
            "apps.users.views.verify_google_credential",
            return_value=self._claims(**claims_kwargs),
        ):
            return self.client.post(
                reverse("google-login"),
                {"credential": "fake-id-token"},
                content_type="application/json",
            )

    def test_new_email_creates_user_and_links_google_account(self):
        resp = self._login()
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn("access", data)
        self.assertTrue(data["is_new_user"])

        user = User.objects.get(email="user@example.com")
        self.assertEqual(user.first_name, "Ali")
        self.assertTrue(
            GoogleAccount.objects.filter(user=user, google_sub="google-sub-1").exists()
        )

    def test_known_google_sub_logs_in_existing_user_without_creating_new_one(self):
        user = User.objects.create(email="user@example.com", role=User.Role.CUSTOMER)
        user.set_unusable_password()
        user.save()
        GoogleAccount.objects.create(user=user, google_sub="google-sub-1", email="user@example.com")

        resp = self._login()
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.json()["is_new_user"])
        self.assertEqual(User.objects.filter(email="user@example.com").count(), 1)

    def test_email_collision_with_unlinked_account_is_rejected_not_auto_linked(self):
        """Xavfsizlik regressiyasi: agar shu email bilan oddiy (parol/OTP)
        hisob allaqachon mavjud bo'lsa-yu, hali Google bilan bog'lanmagan
        bo'lsa — avtomatik bog'lanmasligi va yangi hisob ham
        yaratilmasligi kerak (hisobni egallab olish xavfi)."""
        User.objects.create_user(email="user@example.com", password="StrongPass123")

        resp = self._login(sub="attacker-sub")
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(User.objects.count(), 1)
        self.assertFalse(GoogleAccount.objects.exists())

    def test_blocked_linked_user_cannot_login_via_google(self):
        user = User.objects.create(email="user@example.com", role=User.Role.CUSTOMER, is_active=False)
        user.set_unusable_password()
        user.save()
        GoogleAccount.objects.create(user=user, google_sub="google-sub-1", email="user@example.com")

        resp = self._login()
        self.assertEqual(resp.status_code, 400)

    def test_unverified_email_is_rejected(self):
        from rest_framework.exceptions import ValidationError

        with patch(
            "apps.users.views.verify_google_credential",
            side_effect=ValidationError("Google email tasdiqlanmagan"),
        ):
            resp = self.client.post(
                reverse("google-login"),
                {"credential": "fake-id-token"},
                content_type="application/json",
            )
        self.assertEqual(resp.status_code, 400)
