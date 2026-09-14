from rest_framework.pagination import PageNumberPagination


class ConfigurablePageSizePagination(PageNumberPagination):
    """Standart `PageNumberPagination` — farqi, `?page_size=` orqali
    mijoz sahifa hajmini so'rashi mumkin (standart DRF sinfida bu
    o'chirilgan). Masalan FirmaProduction.jsx'dagi pipeline ko'rinishi
    har buyurtma uchun "X/Y bosqich bajarildi" hisobini FAQAT hozir
    yuklangan yozuvlar asosida chiqaradi — standart 20 talik sahifa bilan
    eski buyurtmaning hali tugallanmagan bosqichi keyingi sahifaga tushib
    qolib, hisob noto'g'ri (masalan haqiqatda 2/3 o'rniga "2/2") ko'rinardi."""

    page_size_query_param = "page_size"
    max_page_size = 200
