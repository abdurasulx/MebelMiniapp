from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.db import IntegrityError, transaction
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from . import versioning
from .models import AppVersion

User = get_user_model()
URL = "/api/v1/app/version/"


def make(version, platform="android", status="active", force=False, url="https://play.google.com/store/apps/x", message=""):
    return AppVersion.objects.create(
        version=version, platform=platform, status=status, force_update=force,
        store_url=url, update_message=message,
    )


class SemverTests(TestCase):
    def test_not_lexicographic(self):
        self.assertEqual(versioning.compare_versions("2.9.0", "2.10.0"), -1)
        self.assertEqual(versioning.compare_versions("2.3.0", "2.4.0"), -1)
        self.assertEqual(versioning.compare_versions("2.4.0", "2.4.0"), 0)
        self.assertEqual(versioning.compare_versions("2.10.3", "2.9.9"), 1)

    def test_short_and_build_forms(self):
        self.assertEqual(versioning.parse_version("1.0"), (1, 0, 0))
        self.assertEqual(versioning.parse_version("2.4.0+24"), (2, 4, 0))
        self.assertIsNone(versioning.parse_version("abc"))
        self.assertIsNone(versioning.parse_version("1.2.3.4"))
        self.assertIsNone(versioning.parse_version("1.0", strict=True))


class DatabaseTests(TestCase):
    def test_same_version_different_platform_allowed(self):
        make("2.4.0", "android")
        make("2.4.0", "ios")
        self.assertEqual(AppVersion.objects.count(), 2)

    def test_duplicate_rejected(self):
        make("2.4.0", "android")
        with self.assertRaises(IntegrityError), transaction.atomic():
            make("2.4.0", "android")


class VersionApiTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        make("2.1.0", status="blocked", force=True)
        make("2.2.0", status="update_required", force=True)
        make("2.3.0")
        make("2.4.0", message="Yangi imkoniyatlar!")
        make("1.0.0", "ios", url="https://apps.apple.com/app/id1")
        make("1.1.0", "ios", url="https://apps.apple.com/app/id1")

    def check(self, version, platform="android"):
        return self.client.get(URL, HTTP_X_APP_VERSION=version, HTTP_X_APP_PLATFORM=platform)

    def test_latest(self):
        d = self.check("2.4.0").json()
        self.assertEqual((d["status"], d["update_available"], d["force_update"]), ("ACTIVE", False, False))
        self.assertEqual(d["latest_version"], "2.4.0")
        self.assertEqual(d["minimum_supported_version"], "2.2.0")

    def test_older_active_has_optional_update(self):
        d = self.check("2.3.0").json()
        self.assertEqual((d["status"], d["update_available"], d["force_update"]), ("ACTIVE", True, False))
        self.assertEqual(d["message"], "Yangi imkoniyatlar!")
        self.assertTrue(d["store_url"].startswith("https://play.google.com"))

    def test_update_required(self):
        d = self.check("2.2.0").json()
        self.assertEqual((d["status"], d["force_update"]), ("UPDATE_REQUIRED", True))

    def test_blocked(self):
        d = self.check("2.1.0").json()
        self.assertEqual((d["status"], d["force_update"]), ("BLOCKED", True))

    def test_platforms_are_independent(self):
        d = self.check("1.0.0", "ios").json()
        self.assertEqual(d["latest_version"], "1.1.0")
        self.assertEqual(self.check("2.4.0", "ios").json()["status"], "ACTIVE")  # ios latest 1.1.0 -> yangiroq

    def test_unknown_versions(self):
        self.assertEqual(self.check("99.99.99").json()["status"], "ACTIVE")
        self.assertEqual(self.check("2.3.5").json()["status"], "ACTIVE")  # 2.3.0 dan meros
        self.assertEqual(self.check("2.2.7").json()["status"], "UPDATE_REQUIRED")
        self.assertEqual(self.check("1.0.0").json()["status"], "BLOCKED")  # minimumdan past

    def test_invalid_and_missing(self):
        self.assertEqual(self.check("x.y").status_code, 400)
        self.assertEqual(self.check("2.4.0", "windows").status_code, 400)
        self.assertEqual(self.client.get(URL).status_code, 400)
        self.assertEqual(self.client.get(URL, HTTP_X_APP_VERSION="2.4.0").status_code, 400)

    def test_works_with_bad_token(self):
        r = self.client.get(
            URL, HTTP_X_APP_VERSION="2.4.0", HTTP_X_APP_PLATFORM="android",
            HTTP_AUTHORIZATION="Bearer expired.garbage.token",
        )
        self.assertEqual(r.status_code, 200)

    def test_no_records_never_blocks(self):
        AppVersion.objects.filter(platform="ios").delete()
        cache.clear()
        self.assertEqual(self.check("0.0.1", "ios").json()["status"], "ACTIVE")

    def test_future_release_date_ignored(self):
        from datetime import timedelta
        from django.utils import timezone
        AppVersion.objects.create(
            version="9.0.0", platform="android", release_date=timezone.now() + timedelta(days=5),
        )
        cache.clear()
        self.assertEqual(self.check("2.4.0").json()["latest_version"], "2.4.0")


class MiddlewareTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        make("2.1.0", status="blocked", force=True)
        make("2.2.0", status="update_required", force=True)
        make("2.3.0")
        make("2.4.0")
        make("2.5.0", status="update_required", force=False)
        make("2.6.0")

    def get(self, version, path="/api/v1/products/", platform="android", **extra):
        return self.client.get(path, HTTP_X_APP_VERSION=version, HTTP_X_APP_PLATFORM=platform, **extra)

    def test_supported_allowed(self):
        self.assertEqual(self.get("2.6.0").status_code, 200)
        self.assertEqual(self.get("2.3.0").status_code, 200)

    def test_blocked_426(self):
        r = self.get("2.1.0")
        self.assertEqual(r.status_code, 426)
        self.assertEqual(r.json()["code"], "APP_UPDATE_REQUIRED")
        self.assertEqual(r.json()["latest_version"], "2.6.0")

    def test_forced_update_required_426_but_soft_allowed(self):
        self.assertEqual(self.get("2.2.0").status_code, 426)
        self.assertEqual(self.get("2.5.0").status_code, 200)

    def test_version_endpoint_never_blocked(self):
        self.assertEqual(self.get("2.1.0", path=URL).status_code, 200)

    def test_health_paths_exempt(self):
        # mavjud bo'lmasa ham 426 EMAS (404) bo'lishi kerak
        self.assertEqual(self.get("2.1.0", path="/api/v1/health/").status_code, 404)

    def test_web_requests_without_headers_unaffected(self):
        self.assertEqual(self.client.get("/api/v1/products/").status_code, 200)

    def test_invalid_headers_400(self):
        self.assertEqual(self.get("garbage").status_code, 400)

    @override_settings(APP_VERSION_REQUIRE_HEADERS=True)
    def test_mobile_without_headers_rejected_when_required(self):
        r = self.client.get("/api/v1/products/", HTTP_X_DEVICE_ID="abc")
        self.assertEqual(r.status_code, 400)
        self.assertEqual(self.client.get("/api/v1/products/").status_code, 200)  # veb

    def test_mobile_without_headers_allowed_by_default(self):
        self.assertNotEqual(self.client.get("/api/v1/products/", HTTP_X_DEVICE_ID="abc").status_code, 426)


class AdminApiTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.admin = User.objects.create_user(email="a@v.uz", password="x12345678", role="platform_admin")
        self.owner = User.objects.create_user(email="o@v.uz", password="x12345678", role="company_owner")

    def test_only_platform_admin(self):
        self.client.force_authenticate(self.owner)
        self.assertEqual(self.client.get("/api/v1/admin/app-versions/").status_code, 403)

    def test_create_edit_sort_filter_no_delete(self):
        self.client.force_authenticate(self.admin)
        for v in ("2.9.0", "2.10.0"):
            r = self.client.post("/api/v1/admin/app-versions/", {"version": v, "platform": "android"}, format="json")
            self.assertEqual(r.status_code, 201, r.data)
        listing = self.client.get("/api/v1/admin/app-versions/").json()
        self.assertEqual([x["version"] for x in listing["results"]], ["2.10.0", "2.9.0"])
        self.assertEqual(listing["latest"]["android"], "2.10.0")
        self.assertEqual(len(self.client.get("/api/v1/admin/app-versions/?platform=ios").json()["results"]), 0)
        pk = listing["results"][0]["id"]
        r = self.client.patch(f"/api/v1/admin/app-versions/{pk}/", {"status": "blocked"}, format="json")
        self.assertTrue(r.json()["force_update"])  # blocked -> majburiy
        self.assertEqual(self.client.delete(f"/api/v1/admin/app-versions/{pk}/").status_code, 405)

    def test_validation(self):
        self.client.force_authenticate(self.admin)
        bad = self.client.post("/api/v1/admin/app-versions/", {"version": "2.4", "platform": "ios"}, format="json")
        self.assertEqual(bad.status_code, 400)
        bad = self.client.post(
            "/api/v1/admin/app-versions/", {"version": "2.4.0", "platform": "ios", "store_url": "not a url"}, format="json"
        )
        self.assertEqual(bad.status_code, 400)
        ok = {"version": "2.4.0", "platform": "ios"}
        self.assertEqual(self.client.post("/api/v1/admin/app-versions/", ok, format="json").status_code, 201)
        self.assertEqual(self.client.post("/api/v1/admin/app-versions/", ok, format="json").status_code, 400)
        self.assertEqual(
            self.client.post("/api/v1/admin/app-versions/", {**ok, "platform": "android"}, format="json").status_code, 201
        )

    def test_cache_invalidated_on_change(self):
        self.client.force_authenticate(self.admin)
        self.client.post("/api/v1/admin/app-versions/", {"version": "1.0.0", "platform": "ios"}, format="json")
        c = APIClient()
        h = {"HTTP_X_APP_VERSION": "1.0.0", "HTTP_X_APP_PLATFORM": "ios"}
        self.assertEqual(c.get(URL, **h).json()["latest_version"], "1.0.0")
        self.client.post("/api/v1/admin/app-versions/", {"version": "1.1.0", "platform": "ios"}, format="json")
        self.assertEqual(c.get(URL, **h).json()["latest_version"], "1.1.0")


class WebPlatformAndBulkTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        self.admin = User.objects.create_user(email="b@v.uz", password="x12345678", role="platform_admin")
        self.client.force_authenticate(self.admin)

    def test_web_platform_resolves(self):
        make("1.0.0", "web", url="https://vidamarket.uz")
        make("1.1.0", "web", url="https://vidamarket.uz")
        r = APIClient().get(URL, HTTP_X_APP_VERSION="1.0.0", HTTP_X_APP_PLATFORM="web")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["latest_version"], "1.1.0")

    def test_bulk_creates_one_record_per_platform_with_own_url(self):
        r = self.client.post("/api/v1/admin/app-versions/bulk/", {
            "platforms": ["android", "ios", "web"], "version": "1.0.0", "status": "active",
            "store_urls": {"android": "https://play.google.com/x", "ios": "https://apps.apple.com/y"},
        }, format="json")
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(AppVersion.objects.filter(version="1.0.0").count(), 3)
        self.assertEqual(AppVersion.objects.get(platform="ios", version="1.0.0").store_url, "https://apps.apple.com/y")
        self.assertEqual(AppVersion.objects.get(platform="web", version="1.0.0").store_url, "")

    def test_bulk_is_all_or_nothing(self):
        make("1.0.0", "ios")
        r = self.client.post("/api/v1/admin/app-versions/bulk/", {
            "platforms": ["android", "ios"], "version": "1.0.0",
        }, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertIn("ios", r.json()["platform_errors"])
        self.assertFalse(AppVersion.objects.filter(platform="android").exists())

    def test_bulk_requires_platforms_and_admin(self):
        self.assertEqual(self.client.post("/api/v1/admin/app-versions/bulk/", {"version": "1.0.0"}, format="json").status_code, 400)
        owner = User.objects.create_user(email="o2@v.uz", password="x12345678", role="company_owner")
        c = APIClient(); c.force_authenticate(owner)
        self.assertEqual(c.post("/api/v1/admin/app-versions/bulk/", {"platforms": ["ios"], "version": "1.0.0"}, format="json").status_code, 403)

    def test_cors_preflight_allows_version_headers(self):
        r = APIClient().options(
            "/api/v1/products/", HTTP_ORIGIN="https://vidamarket.uz",
            HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET",
            HTTP_ACCESS_CONTROL_REQUEST_HEADERS="x-app-version,x-app-platform",
        )
        allowed = r.headers.get("Access-Control-Allow-Headers", "").lower()
        self.assertIn("x-app-version", allowed)
        self.assertIn("x-app-platform", allowed)


class OrdersRestrictionTests(TestCase):
    def setUp(self):
        cache.clear()
        self.client = APIClient()
        make("1.0.0")
        AppVersion.objects.filter(version="1.0.0").update(orders_enabled=False)
        make("1.1.0")
        cache.clear()

    def post(self, version, path="/api/v1/orders/"):
        return self.client.post(
            path, {}, format="json", HTTP_X_APP_VERSION=version, HTTP_X_APP_PLATFORM="android",
        )

    def test_orders_blocked_for_restricted_version(self):
        for path in ("/api/v1/orders/", "/api/v1/custom-orders/create/"):
            r = self.post("1.0.0", path)
            self.assertEqual(r.status_code, 403)
            self.assertEqual(r.json()["code"], "ORDERS_RESTRICTED")

    def test_other_requests_and_versions_unaffected(self):
        self.assertNotEqual(self.post("1.1.0").json().get("code"), "ORDERS_RESTRICTED")
        r = self.client.get("/api/v1/products/", HTTP_X_APP_VERSION="1.0.0", HTTP_X_APP_PLATFORM="android")
        self.assertEqual(r.status_code, 200)

    def test_policy_exposes_flag(self):
        r = self.client.get(URL, HTTP_X_APP_VERSION="1.0.0", HTTP_X_APP_PLATFORM="android")
        self.assertIs(r.json()["orders_enabled"], False)


class PlatformLinkTests(TestCase):
    def setUp(self):
        cache.clear()
        self.admin = User.objects.create_user(email="c@v.uz", password="x12345678", role="platform_admin")
        self.client = APIClient()
        self.client.force_authenticate(self.admin)
        make("1.0.0", url="")

    def test_link_used_in_policy(self):
        r = self.client.put("/api/v1/admin/app-versions/links/", {"android": "https://play.google.com/x"}, format="json")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["android"], "https://play.google.com/x")
        self.assertEqual(r.json()["ios"], "")
        p = APIClient().get(URL, HTTP_X_APP_VERSION="1.0.0", HTTP_X_APP_PLATFORM="android")
        self.assertEqual(p.json()["store_url"], "https://play.google.com/x")

    def test_invalid_url_rejected(self):
        r = self.client.put("/api/v1/admin/app-versions/links/", {"ios": "nope"}, format="json")
        self.assertEqual(r.status_code, 400)
