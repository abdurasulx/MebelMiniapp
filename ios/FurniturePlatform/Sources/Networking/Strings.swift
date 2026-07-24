import Foundation

/// Asosiy matnlar lug'ati — 9 til, Flutter'dagi `lib/l10n/strings.dart` bilan
/// bir xil kalitlar/tarjimalar (ikkala platformada bir xil so'zlar ishlatiladi).
/// Hozircha navigatsiya, kirish (auth) va savat kabi eng ko'p ko'rinadigan
/// matnlar qamrab olingan.
let appLocales: [(code: String, nativeName: String)] = [
    ("uz", "O'zbekcha"),
    ("en", "English"),
    ("ru", "Русский"),
    ("tg", "Тоҷикӣ"),
    ("tr", "Türkçe"),
    ("ky", "Кыргызча"),
    ("kk", "Қазақша"),
    ("de", "Deutsch"),
    ("az", "Azərbaycan"),
]

let defaultLocaleCode = "uz"

private let stringsTable: [String: [String: String]] = [
    "uz": [
        "nav_home": "Bosh sahifa", "nav_catalog": "Katalog", "nav_likes": "Sevimlilar",
        "nav_cart": "Savat", "nav_profile": "Profil",
        "auth_title": "Kirish", "auth_phone_hint": "Telefon", "auth_select_country": "Davlat",
        "auth_send_code": "Kod yuborish", "auth_phone_invalid": "Raqam noto'g'ri",
        "auth_code_hint": "Kod (6 raqam)", "auth_verify": "Kirish",
        "auth_change_number": "Raqamni o'zgartirish", "auth_sms_sent": "SMS yuborildi",
        "auth_resend": "Qayta yuborish", "auth_profile_title": "Ma'lumotlaringiz",
        "auth_first_name": "Ism", "auth_last_name": "Familiya",
        "auth_dob": "Tug'ilgan sana (ixtiyoriy)", "auth_save": "Saqlash",
        "profile_language": "Til",
    ],
    "en": [
        "nav_home": "Home", "nav_catalog": "Catalog", "nav_likes": "Favorites",
        "nav_cart": "Cart", "nav_profile": "Profile",
        "auth_title": "Sign in", "auth_phone_hint": "Phone", "auth_select_country": "Country",
        "auth_send_code": "Send code", "auth_phone_invalid": "Invalid number",
        "auth_code_hint": "Code (6 digits)", "auth_verify": "Sign in",
        "auth_change_number": "Change number", "auth_sms_sent": "SMS sent",
        "auth_resend": "Resend", "auth_profile_title": "Your details",
        "auth_first_name": "First name", "auth_last_name": "Last name",
        "auth_dob": "Date of birth (optional)", "auth_save": "Save",
        "profile_language": "Language",
    ],
    "ru": [
        "nav_home": "Главная", "nav_catalog": "Каталог", "nav_likes": "Избранное",
        "nav_cart": "Корзина", "nav_profile": "Профиль",
        "auth_title": "Вход", "auth_phone_hint": "Телефон", "auth_select_country": "Страна",
        "auth_send_code": "Отправить код", "auth_phone_invalid": "Неверный номер",
        "auth_code_hint": "Код (6 цифр)", "auth_verify": "Войти",
        "auth_change_number": "Изменить номер", "auth_sms_sent": "SMS отправлено",
        "auth_resend": "Отправить снова", "auth_profile_title": "Ваши данные",
        "auth_first_name": "Имя", "auth_last_name": "Фамилия",
        "auth_dob": "Дата рождения (необязательно)", "auth_save": "Сохранить",
        "profile_language": "Язык",
    ],
    "tg": [
        "nav_home": "Саҳифаи асосӣ", "nav_catalog": "Каталог", "nav_likes": "Дӯстдоштаҳо",
        "nav_cart": "Сабад", "nav_profile": "Профил",
        "auth_title": "Воридшавӣ", "auth_phone_hint": "Телефон", "auth_select_country": "Кишвар",
        "auth_send_code": "Фиристодани код", "auth_phone_invalid": "Рақами нодуруст",
        "auth_code_hint": "Код (6 рақам)", "auth_verify": "Ворид шудан",
        "auth_change_number": "Тағйири рақам", "auth_sms_sent": "SMS фиристода шуд",
        "auth_resend": "Дубора фиристодан", "auth_profile_title": "Маълумоти шумо",
        "auth_first_name": "Ном", "auth_last_name": "Насаб",
        "auth_dob": "Санаи таваллуд (ихтиёрӣ)", "auth_save": "Нигоҳ доштан",
        "profile_language": "Забон",
    ],
    "tr": [
        "nav_home": "Ana sayfa", "nav_catalog": "Katalog", "nav_likes": "Favoriler",
        "nav_cart": "Sepet", "nav_profile": "Profil",
        "auth_title": "Giriş yap", "auth_phone_hint": "Telefon", "auth_select_country": "Ülke",
        "auth_send_code": "Kodu gönder", "auth_phone_invalid": "Geçersiz numara",
        "auth_code_hint": "Kod (6 haneli)", "auth_verify": "Giriş yap",
        "auth_change_number": "Numarayı değiştir", "auth_sms_sent": "SMS gönderildi",
        "auth_resend": "Tekrar gönder", "auth_profile_title": "Bilgileriniz",
        "auth_first_name": "Ad", "auth_last_name": "Soyad",
        "auth_dob": "Doğum tarihi (isteğe bağlı)", "auth_save": "Kaydet",
        "profile_language": "Dil",
    ],
    "ky": [
        "nav_home": "Башкы бет", "nav_catalog": "Каталог", "nav_likes": "Тандалмалар",
        "nav_cart": "Себет", "nav_profile": "Профиль",
        "auth_title": "Кирүү", "auth_phone_hint": "Телефон", "auth_select_country": "Мамлекет",
        "auth_send_code": "Кодду жөнөтүү", "auth_phone_invalid": "Номер туура эмес",
        "auth_code_hint": "Код (6 сан)", "auth_verify": "Кирүү",
        "auth_change_number": "Номерди өзгөртүү", "auth_sms_sent": "SMS жөнөтүлдү",
        "auth_resend": "Кайра жөнөтүү", "auth_profile_title": "Сиздин маалымат",
        "auth_first_name": "Ысым", "auth_last_name": "Фамилия",
        "auth_dob": "Туулган күнү (милдеттүү эмес)", "auth_save": "Сактоо",
        "profile_language": "Тил",
    ],
    "kk": [
        "nav_home": "Басты бет", "nav_catalog": "Каталог", "nav_likes": "Таңдаулылар",
        "nav_cart": "Себет", "nav_profile": "Профиль",
        "auth_title": "Кіру", "auth_phone_hint": "Телефон", "auth_select_country": "Мемлекет",
        "auth_send_code": "Кодты жіберу", "auth_phone_invalid": "Нөмір қате",
        "auth_code_hint": "Код (6 сан)", "auth_verify": "Кіру",
        "auth_change_number": "Нөмірді өзгерту", "auth_sms_sent": "SMS жіберілді",
        "auth_resend": "Қайта жіберу", "auth_profile_title": "Сіздің деректеріңіз",
        "auth_first_name": "Аты", "auth_last_name": "Тегі",
        "auth_dob": "Туған күні (міндетті емес)", "auth_save": "Сақтау",
        "profile_language": "Тіл",
    ],
    "de": [
        "nav_home": "Start", "nav_catalog": "Katalog", "nav_likes": "Favoriten",
        "nav_cart": "Warenkorb", "nav_profile": "Profil",
        "auth_title": "Anmelden", "auth_phone_hint": "Telefon", "auth_select_country": "Land",
        "auth_send_code": "Code senden", "auth_phone_invalid": "Ungültige Nummer",
        "auth_code_hint": "Code (6 Ziffern)", "auth_verify": "Anmelden",
        "auth_change_number": "Nummer ändern", "auth_sms_sent": "SMS gesendet",
        "auth_resend": "Erneut senden", "auth_profile_title": "Ihre Angaben",
        "auth_first_name": "Vorname", "auth_last_name": "Nachname",
        "auth_dob": "Geburtsdatum (optional)", "auth_save": "Speichern",
        "profile_language": "Sprache",
    ],
    "az": [
        "nav_home": "Ana səhifə", "nav_catalog": "Kataloq", "nav_likes": "Sevimlilər",
        "nav_cart": "Səbət", "nav_profile": "Profil",
        "auth_title": "Giriş", "auth_phone_hint": "Telefon", "auth_select_country": "Ölkə",
        "auth_send_code": "Kodu göndər", "auth_phone_invalid": "Nömrə yanlışdır",
        "auth_code_hint": "Kod (6 rəqəm)", "auth_verify": "Giriş",
        "auth_change_number": "Nömrəni dəyiş", "auth_sms_sent": "SMS göndərildi",
        "auth_resend": "Yenidən göndər", "auth_profile_title": "Sizin məlumatlarınız",
        "auth_first_name": "Ad", "auth_last_name": "Soyad",
        "auth_dob": "Doğum tarixi (istəyə bağlı)", "auth_save": "Yadda saxla",
        "profile_language": "Dil",
    ],
]

func translate(_ code: String, _ key: String) -> String {
    stringsTable[code]?[key] ?? stringsTable["uz"]?[key] ?? key
}
