from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from .models import GoogleAccount, PhoneOTP, TelegramAccount, TelegramLoginSession, User


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
        user = User.objects.get(phone="+998901234567")
        self.assertTrue(user.phone_verified)

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
    e'tibor account-linking mantig'ida: `google_sub` bo'yicha topilsa
    to'g'ridan-to'g'ri, topilmasa-yu email mos kelsa avtomatik bog'lanadi
    (Google `email_verified` orqali email egaligini tekshirgani sabab —
    qarang GoogleLoginView docstring)."""

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
        self.assertFalse(user.registration_completed)
        self.assertFalse(user.phone_verified)
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

    def test_email_collision_with_verified_email_auto_links_existing_account(self):
        """Email/parol bilan kirish endi faqat admin uchun qolgani sabab —
        shu email bilan mavjud (parolli) hisobga Google `email_verified:
        true` bilan kelsa, avtomatik bog'lanadi, yangi hisob YARATILMAYDI."""
        existing = User.objects.create_user(email="user@example.com", password="StrongPass123")

        resp = self._login(sub="new-google-sub")
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.json()["is_new_user"])
        self.assertEqual(User.objects.count(), 1)
        self.assertTrue(
            GoogleAccount.objects.filter(user=existing, google_sub="new-google-sub").exists()
        )

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


class AdminOnlyPasswordLoginTests(TestCase):
    """Email+parol bilan kirish endi faqat platforma admini uchun."""

    def _login(self, email, password):
        return self.client.post(
            reverse("token_obtain_pair"),
            {"email": email, "password": password},
            content_type="application/json",
        )

    def test_platform_admin_can_login_with_password(self):
        User.objects.create_user(
            email="admin@example.com", password="StrongPass123", role=User.Role.PLATFORM_ADMIN
        )
        resp = self._login("admin@example.com", "StrongPass123")
        self.assertEqual(resp.status_code, 200)
        self.assertIn("access", resp.json())

    def test_customer_cannot_login_with_password(self):
        User.objects.create_user(
            email="customer@example.com", password="StrongPass123", role=User.Role.CUSTOMER
        )
        resp = self._login("customer@example.com", "StrongPass123")
        self.assertEqual(resp.status_code, 400)

    def test_company_owner_cannot_login_with_password(self):
        User.objects.create_user(
            email="owner@example.com", password="StrongPass123", role=User.Role.COMPANY_OWNER
        )
        resp = self._login("owner@example.com", "StrongPass123")
        self.assertEqual(resp.status_code, 400)

    def test_register_endpoint_no_longer_exists(self):
        resp = self.client.post(
            "/api/v1/auth/register/",
            {"email": "x@example.com", "password": "StrongPass123"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 404)


class CompleteRegistrationTests(TestCase):
    """Google/Telegram orqali yangi hisob ochilgandan keyingi yakuniy qadam."""

    def _new_user(self):
        user = User(
            email="new@example.com", role=User.Role.CUSTOMER, registration_completed=False
        )
        user.set_unusable_password()
        user.save()
        return user

    def _auth_client(self, user):
        from rest_framework_simplejwt.tokens import RefreshToken

        client = self.client
        token = str(RefreshToken.for_user(user).access_token)
        client.defaults["HTTP_AUTHORIZATION"] = f"Bearer {token}"
        return client

    def test_completes_as_customer(self):
        user = self._new_user()
        client = self._auth_client(user)
        resp = client.post(
            reverse("complete-registration"),
            {"role": "customer", "first_name": "Ali", "phone": "+998901234567"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.registration_completed)
        self.assertEqual(user.role, User.Role.CUSTOMER)
        self.assertEqual(user.first_name, "Ali")

    def test_completes_as_company_owner_creates_company(self):
        from apps.companies.models import Company

        user = self._new_user()
        client = self._auth_client(user)
        resp = client.post(
            reverse("complete-registration"),
            {"role": "company_owner", "first_name": "Ali", "company_name": "Ali Mebel"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 200)
        user.refresh_from_db()
        self.assertEqual(user.role, User.Role.COMPANY_OWNER)
        self.assertTrue(Company.objects.filter(owner=user, name="Ali Mebel").exists())

    def test_company_owner_without_company_name_rejected(self):
        user = self._new_user()
        client = self._auth_client(user)
        resp = client.post(
            reverse("complete-registration"),
            {"role": "company_owner", "first_name": "Ali"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)

    def test_already_completed_user_cannot_call_again(self):
        """Regressiya: bu endpoint rol o'zgartirish vositasi emas — bir marta
        ishlatilgandan keyin qayta chaqirilsa rad etilishi kerak."""
        user = self._new_user()
        user.registration_completed = True
        user.save(update_fields=["registration_completed"])
        client = self._auth_client(user)
        resp = client.post(
            reverse("complete-registration"),
            {"role": "company_owner", "first_name": "Ali", "company_name": "Ali Mebel"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)
        user.refresh_from_db()
        self.assertEqual(user.role, User.Role.CUSTOMER)


class TelegramLoginTests(TestCase):
    """Telegram login: session_id yaratish -> bot webhook orqali bog'lash
    -> frontend poll qilib JWT olish."""

    def test_create_session_returns_pending_id(self):
        resp = self.client.post(reverse("telegram-session-create"))
        self.assertEqual(resp.status_code, 200)
        session_id = resp.json()["session_id"]
        self.assertTrue(TelegramLoginSession.objects.filter(pk=session_id).exists())

        poll = self.client.get(reverse("telegram-session-poll", args=[session_id]))
        self.assertEqual(poll.status_code, 200)
        self.assertEqual(poll.json()["status"], "pending")

    def test_webhook_start_payload_links_session_then_poll_logs_in(self):
        from django.test import override_settings

        session = TelegramLoginSession.objects.create()
        update = {
            "message": {
                "text": f"/start {session.id}",
                "from": {"id": 555, "first_name": "Vali", "username": "vali_tg"},
                "chat": {"id": 555},
            }
        }
        with patch("apps.users.telegram_bot.send_message"), override_settings(
            TELEGRAM_WEBHOOK_SECRET=""
        ):
            resp = self.client.post(
                reverse("telegram-webhook"), update, content_type="application/json"
            )
        self.assertEqual(resp.status_code, 200)

        session.refresh_from_db()
        self.assertEqual(session.telegram_id, 555)

        poll = self.client.get(reverse("telegram-session-poll", args=[session.id]))
        self.assertEqual(poll.status_code, 200)
        data = poll.json()
        self.assertEqual(data["status"], "done")
        self.assertIn("access", data)
        self.assertTrue(data["is_new_user"])

        user = TelegramAccount.objects.get(telegram_id=555).user
        self.assertFalse(user.registration_completed)
        self.assertFalse(user.phone_verified)

    def test_known_telegram_id_logs_in_existing_user(self):
        user = User(email="existing@example.com", role=User.Role.CUSTOMER)
        user.set_unusable_password()
        user.save()
        TelegramAccount.objects.create(user=user, telegram_id=777)

        session = TelegramLoginSession.objects.create(telegram_id=777, telegram_first_name="Vali")
        poll = self.client.get(reverse("telegram-session-poll", args=[session.id]))
        self.assertEqual(poll.status_code, 200)
        data = poll.json()
        self.assertFalse(data["is_new_user"])
        self.assertEqual(User.objects.filter(email="existing@example.com").count(), 1)

    def test_consumed_session_cannot_be_polled_again(self):
        session = TelegramLoginSession.objects.create(telegram_id=888, telegram_first_name="Vali")
        first = self.client.get(reverse("telegram-session-poll", args=[session.id]))
        self.assertEqual(first.status_code, 200)

        second = self.client.get(reverse("telegram-session-poll", args=[session.id]))
        self.assertEqual(second.status_code, 400)

    def test_expired_session_rejected(self):
        session = TelegramLoginSession.objects.create(telegram_id=999, telegram_first_name="Vali")
        session.created_at = timezone.now() - timedelta(minutes=TelegramLoginSession.EXPIRY_MINUTES + 1)
        session.save(update_fields=["created_at"])

        resp = self.client.get(reverse("telegram-session-poll", args=[session.id]))
        self.assertEqual(resp.status_code, 400)

    def test_webhook_rejects_wrong_secret(self):
        from django.test import override_settings

        with override_settings(TELEGRAM_WEBHOOK_SECRET="expected-secret"):
            resp = self.client.post(
                reverse("telegram-webhook"),
                {"message": {"text": "/start abc"}},
                content_type="application/json",
                HTTP_X_TELEGRAM_BOT_API_SECRET_TOKEN="wrong",
            )
        self.assertEqual(resp.status_code, 403)

    def test_bot_info_returns_configured_username(self):
        from django.test import override_settings

        with override_settings(TELEGRAM_BOT_USERNAME="test_bot"):
            resp = self.client.get(reverse("telegram-bot-info"))
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["username"], "test_bot")


class PhoneVerifyTests(TestCase):
    """Google/Telegram orqali kirgan (`phone_verified=False`) foydalanuvchi
    checkout paytida telefonini SMS-kod bilan tasdiqlashi — qarang
    PhoneVerifyRequestView/PhoneVerifyConfirmView va OrderViewSet.perform_create."""

    def _auth_client(self, user):
        from rest_framework_simplejwt.tokens import RefreshToken

        token = str(RefreshToken.for_user(user).access_token)
        self.client.defaults["HTTP_AUTHORIZATION"] = f"Bearer {token}"

    def _new_unverified_user(self):
        user = User(email="social@example.com", role=User.Role.CUSTOMER, phone_verified=False)
        user.set_unusable_password()
        user.save()
        return user

    def test_unauthenticated_cannot_request_or_confirm(self):
        resp = self.client.post(
            reverse("phone-verify-request"), {"phone": "+998901234567"}, content_type="application/json"
        )
        self.assertEqual(resp.status_code, 401)

    def test_request_then_confirm_verifies_phone(self):
        user = self._new_unverified_user()
        self._auth_client(user)

        resp = self.client.post(
            reverse("phone-verify-request"), {"phone": "+998901234567"}, content_type="application/json"
        )
        self.assertEqual(resp.status_code, 200)
        otp = PhoneOTP.objects.filter(phone="+998901234567").order_by("-created_at").first()
        self.assertIsNotNone(otp)

        resp = self.client.post(
            reverse("phone-verify-confirm"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.phone_verified)
        self.assertEqual(user.phone, "+998901234567")

    def test_phone_already_linked_to_another_account_is_rejected(self):
        User.objects.create_user(
            email="existing@example.com", password="StrongPass123", phone="+998901234567"
        )
        user = self._new_unverified_user()
        self._auth_client(user)

        self.client.post(
            reverse("phone-verify-request"), {"phone": "+998901234567"}, content_type="application/json"
        )
        otp = PhoneOTP.objects.filter(phone="+998901234567").order_by("-created_at").first()
        resp = self.client.post(
            reverse("phone-verify-confirm"),
            {"phone": "+998901234567", "code": otp.code},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)
        user.refresh_from_db()
        self.assertFalse(user.phone_verified)

    def test_wrong_code_is_rejected(self):
        user = self._new_unverified_user()
        self._auth_client(user)
        self.client.post(
            reverse("phone-verify-request"), {"phone": "+998901234567"}, content_type="application/json"
        )
        resp = self.client.post(
            reverse("phone-verify-confirm"),
            {"phone": "+998901234567", "code": "000000"},
            content_type="application/json",
        )
        self.assertEqual(resp.status_code, 400)
        user.refresh_from_db()
        self.assertFalse(user.phone_verified)
