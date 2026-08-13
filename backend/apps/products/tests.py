import io

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image
from rest_framework.test import APIClient, APITestCase

from apps.cart.models import CartItem
from apps.companies.models import Company
from apps.likes.models import Like
from apps.orders.models import Order, OrderItem

from .imaging import compute_signature, dominant_color_tag, similarity_percent
from .models import Category, Product, Variant

User = get_user_model()


def make_test_image(color, size=(40, 40)):
    buf = io.BytesIO()
    Image.new("RGB", size, color).save(buf, format="PNG")
    buf.seek(0)
    return buf


def make_transparent_image(color, alpha=255):
    """RGBA PNG — 3D-render eksportlarida keng tarqalgan shaffof fon."""
    buf = io.BytesIO()
    Image.new("RGBA", (40, 40), (*color, alpha)).save(buf, format="PNG")
    buf.seek(0)
    return buf


def make_split_image(left_color, right_color, size=(60, 60)):
    """Chapi va o'ngi boshqa rangdagi rasm — dHash (shakl/gradient) signalini
    sinash uchun (bir xil o'rtacha rangda ham chegara joyi farq qiladi)."""
    buf = io.BytesIO()
    img = Image.new("RGB", size, left_color)
    for x in range(size[0] // 2, size[0]):
        for y in range(size[1]):
            img.putpixel((x, y), right_color)
    img.save(buf, format="PNG")
    buf.seek(0)
    return buf


class ImagingTests(APITestCase):
    def test_identical_colors_are_100_percent_similar(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((200, 30, 30)))
        self.assertEqual(similarity_percent(sig_a, sig_b), 100.0)

    def test_different_colors_are_less_similar(self):
        sig_a = compute_signature(make_test_image((200, 30, 30)))
        sig_b = compute_signature(make_test_image((10, 10, 200)))
        same = similarity_percent(sig_a, sig_a)
        different = similarity_percent(sig_a, sig_b)
        self.assertLess(different, same)

    def test_same_average_color_but_different_layout_is_less_similar(self):
        """Gistogramma yolg'iz o'zi bo'lganda ikkalasi ham "yashil" deb bir
        xil chiqishi mumkin edi — dHash shakl/chegara farqini ushlab, bularni
        ajratishi kerak."""
        split_a = compute_signature(make_split_image((255, 0, 0), (0, 255, 0)))
        split_b = compute_signature(make_split_image((0, 255, 0), (255, 0, 0)))  # teskari
        solid_green = compute_signature(make_test_image((128, 128, 0)))  # o'rtacha rang bir xil

        self.assertLess(similarity_percent(split_a, split_b), 100.0)
        self.assertLess(similarity_percent(split_a, solid_green), 100.0)

    def test_transparent_background_is_composited_onto_white_not_black(self):
        """Regressiya: mebel rasmlari ko'pincha shaffof fonli (3D-render
        eksporti) PNG bo'ladi. `.convert("RGB")` shaffof qismlarni to'g'ridan
        -to'g'ri qora qilib qo'yar edi — natijada bir xil ko'rinadigan (oq
        fonli) ikkita rasm ham (biri shaffof, biri haqiqiy oq) mutlaqo
        boshqa-boshqa signature olardi va qidiruv noto'g'ri natija berardi."""
        opaque_white_sig = compute_signature(make_test_image((255, 255, 255)))
        transparent_sig = compute_signature(make_transparent_image((255, 255, 255), alpha=0))
        self.assertEqual(similarity_percent(opaque_white_sig, transparent_sig), 100.0)
        # Qora bilan chalkashmasligini alohida ham tasdiqlaymiz.
        opaque_black_sig = compute_signature(make_test_image((0, 0, 0)))
        self.assertLess(similarity_percent(opaque_black_sig, transparent_sig), 100.0)

    def test_dominant_color_tag_ignores_white_background(self):
        img = Image.new("RGB", (40, 40), (255, 255, 255))
        for x in range(10, 30):
            for y in range(10, 30):
                img.putpixel((x, y), (150, 100, 55))  # jigarrang mahsulot
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        buf.seek(0)
        self.assertEqual(dominant_color_tag(buf), "jigarrang")

    def test_neutral_gray_shading_is_not_confused_with_a_hue(self):
        """Regressiya: oq/kulrang mahsulotning soyali qismlari (masalan
        (200,200,200) kabi neytral kulranglar) tasodifan "pushti" kabi
        to'yingan rang etaloniga raqamli jihatdan yaqinroq chiqib, oq
        stulni "pushti" deb noto'g'ri teglardi."""
        self.assertEqual(dominant_color_tag(make_test_image((210, 210, 210))), "kulrang")
        self.assertEqual(dominant_color_tag(make_test_image((240, 240, 240))), "oq")
        self.assertEqual(dominant_color_tag(make_test_image((30, 30, 30))), "qora")

    def test_search_by_image_ranks_closest_first(self):
        owner = User.objects.create_user(email="owner@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        company = Company.objects.create(owner=owner, name="Shop", slug="shop")
        category = Category.objects.create(name_uz="Stullar", slug="stullar")

        red = Product.objects.create(
            company=company, category=category, name_uz="Qizil stul", is_published=True,
            image=SimpleUploadedFile("red.png", make_test_image((220, 20, 20)).read(), content_type="image/png"),
        )
        blue = Product.objects.create(
            company=company, category=category, name_uz="Ko'k stul", is_published=True,
            image=SimpleUploadedFile("blue.png", make_test_image((20, 20, 220)).read(), content_type="image/png"),
        )
        self.assertIsNotNone(Product.objects.get(pk=red.pk).image_signature)
        self.assertIsNotNone(Product.objects.get(pk=blue.pk).image_signature)

        query = SimpleUploadedFile(
            "query.png", make_test_image((230, 15, 15)).read(), content_type="image/png"
        )
        client = APIClient()
        resp = client.post(
            "/api/v1/products/search-by-image/", {"image": query, "min_similarity": 0}, format="multipart"
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertGreaterEqual(len(resp.data), 1)
        self.assertEqual(resp.data[0]["id"], str(red.id))


class DistanceVisibilityTests(APITestCase):
    """Firma xizmat radiusi (Company.service_radius_km) bo'yicha mahsulot
    ko'rinishi — qarang apps/products/views.py `_companies_within_radius`."""

    def setUp(self):
        owner = User.objects.create_user(email="d@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.category = Category.objects.create(name_uz="Stullar", slug="d-stullar")
        # Toshkent markazi atrofida, 10km radius bilan xizmat qiladi.
        self.near_company = Company.objects.create(
            owner=owner, name="Yaqin firma", slug="yaqin-firma",
            latitude=41.311081, longitude=69.240562, service_radius_km=10,
        )
        # Samarqandda, faqat 5km radius — Toshkentdagi foydalanuvchiga yetmaydi.
        self.far_company = Company.objects.create(
            owner=owner, name="Uzoq firma", slug="uzoq-firma",
            latitude=39.627001, longitude=66.975006, service_radius_km=5,
        )
        # Lokatsiya sozlanmagan — har doim ko'rinishi kerak.
        self.unset_company = Company.objects.create(owner=owner, name="Sozlanmagan firma", slug="sozlanmagan-firma")

        self.near_product = Product.objects.create(
            company=self.near_company, category=self.category, name_uz="Yaqin stul", is_published=True,
        )
        self.far_product = Product.objects.create(
            company=self.far_company, category=self.category, name_uz="Uzoq stul", is_published=True,
        )
        self.unset_product = Product.objects.create(
            company=self.unset_company, category=self.category, name_uz="Sozlanmagan stul", is_published=True,
        )

    def test_only_companies_within_radius_and_unset_are_visible(self):
        # Toshkent shahridagi foydalanuvchi nuqtasi.
        resp = self.client.get("/api/v1/products/?lat=41.3111&lng=69.2797")
        self.assertEqual(resp.status_code, 200, resp.data)
        ids = {p["id"] for p in resp.data["results"]}
        self.assertIn(str(self.near_product.id), ids)
        self.assertIn(str(self.unset_product.id), ids)
        self.assertNotIn(str(self.far_product.id), ids)

    def test_without_lat_lng_all_are_visible(self):
        resp = self.client.get("/api/v1/products/")
        self.assertEqual(resp.status_code, 200, resp.data)
        ids = {p["id"] for p in resp.data["results"]}
        self.assertIn(str(self.near_product.id), ids)
        self.assertIn(str(self.far_product.id), ids)
        self.assertIn(str(self.unset_product.id), ids)


class RankingTests(APITestCase):
    """Qidiruv — sotuv/savat faolligi bo'yicha; Asosiy sahifa — foydalanuvchi
    qiziqishi (like/buyurtma/savat tarixi) bo'yicha tartiblanishi."""

    def setUp(self):
        owner = User.objects.create_user(email="r@shop.uz", password="pass12345", role=User.Role.COMPANY_OWNER)
        self.customer = User.objects.create_user(email="rc@shop.uz", password="pass12345", role=User.Role.CUSTOMER)
        self.company = Company.objects.create(owner=owner, name="Rank Shop", slug="rank-shop")
        self.cat_a = Category.objects.create(name_uz="A toifa", slug="rank-a")
        self.cat_b = Category.objects.create(name_uz="B toifa", slug="rank-b")

        self.popular = Product.objects.create(
            company=self.company, category=self.cat_a, name_uz="Ommabop stul", is_published=True,
        )
        self.unpopular = Product.objects.create(
            company=self.company, category=self.cat_a, name_uz="Kam sotilgan stul", is_published=True,
        )
        variant = Variant.objects.create(product=self.popular, name="Standart", base_price=100000)

        order = Order.objects.create(company=self.company, customer=self.customer, phone="+998900000000", address="Toshkent")
        OrderItem.objects.create(
            order=order, product=self.popular, variant=variant, product_name="Ommabop stul", variant_name="Standart",
            width=1, height=1, depth=1, quantity=5, unit_m3_price=100000, subtotal=500000,
        )

    def test_search_orders_by_sales_count_first(self):
        resp = self.client.get("/api/v1/products/?search=stul")
        self.assertEqual(resp.status_code, 200, resp.data)
        ids = [p["id"] for p in resp.data["results"]]
        self.assertEqual(ids[0], str(self.popular.id))

    def test_home_feed_favors_liked_category(self):
        # Alohida (buyurtma tarixi bo'lmagan) foydalanuvchi — faqat "like"
        # signali sof holda tekshiriladi, setUp'dagi self.customer'ning
        # buyurtma tarixi (cat_a) natijaga aralashmasligi uchun.
        fan = User.objects.create_user(email="fan@shop.uz", password="pass12345", role=User.Role.CUSTOMER)
        favorite_cat_product = Product.objects.create(
            company=self.company, category=self.cat_b, name_uz="B toifadan mahsulot", is_published=True,
        )
        other_cat_product = Product.objects.create(
            company=self.company, category=self.cat_a, name_uz="A toifadan yana biri", is_published=True,
        )
        Like.objects.create(user=fan, product=favorite_cat_product)

        self.client.force_authenticate(fan)
        resp = self.client.get("/api/v1/products/")
        self.assertEqual(resp.status_code, 200, resp.data)
        ids = [p["id"] for p in resp.data["results"]]
        self.assertEqual(ids[0], str(favorite_cat_product.id))
        self.assertIn(str(other_cat_product.id), ids)
