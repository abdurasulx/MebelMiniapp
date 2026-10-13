# Store maxfiylik deklaratsiyasi (App Store "App Privacy" va Google Play "Data safety")

Bu hujjat `PrivacyInfo.xcprivacy` bilan **bir xil** bo'lishi shart. App Store Connect → App Privacy
va Play Console → Data safety ni shu jadval bo'yicha to'ldiring. Hammasi uchun: **Tracking = Yo'q**,
maqsad: **App Functionality**, **Linked to user = Ha**, uchinchi tomon reklama/analitika SDK yo'q.

| Ma'lumot turi | Nima uchun / qayerdan | Yig'iladimi | Maqsad |
|---|---|---|---|
| **Name** | profil: ism/familiya, Google/Apple akkaunti | ha | App Functionality |
| **Email Address** | Google/Apple bilan kirish, firma egasi | ha | App Functionality |
| **Phone Number** | telefon + SMS-OTP bilan kirish, buyurtma | ha | App Functionality |
| **Precise Location** | yaqin firmalarni ko'rsatish (GPS → server) | ha | App Functionality |
| **Physical Address** | buyurtma yetkazib berish manzili, firma manzili | ha | App Functionality |
| **Purchase History** | buyurtmalar ro'yxati va holati | ha | App Functionality |
| **User ID** | akkaunt identifikatori (JWT) | ha | App Functionality |
| **Device ID** | push token (FCM), qurilma imzosi | ha | App Functionality |
| **Photos or Videos** | rasm bilan qidirish (yuboriladi), ish jarayoni foto/video, mahsulot rasmlari | ha | App Functionality |
| **Audio Data** | ish jarayoni videosining ovozi (mikrofon) | ha | App Functionality |
| **Other User Content** | sharhlar, izohlar, mahsulot tavsifi, buyurtma izohlari | ha | App Functionality |
| Contacts, Health, Financial, Browsing/Search History, Diagnostics, Usage/Advertising Data | — | **yo'q** | — |

## Uchinchi tomon xizmatlari
- **Firebase Cloud Messaging** (push) — qurilma tokeni. SDK o'zining Privacy Manifest'ini olib keladi.
- **Google Sign-In / Sign in with Apple** — kirish uchun; email va ism olinadi.
- **Telegram Login** — foydalanuvchi o'z Telegram profilidan ism/ID bilan kiradi.
- **Eskiz.uz** — SMS yuborish (telefon raqam serverdan yuboriladi; ilova to'g'ridan-to'g'ri aloqa qilmaydi).
- Reklama, kuzatuv (tracking) va analitika SDK'lari **yo'q**.

## Required-Reason API
- `UserDefaults` — sabab `CA92.1` (ilovaning o'z sozlamalari). Boshqa API'lar (fayl vaqti, disk, boot time) ishlatilmaydi.

## Foydalanuvchi huquqlari
- Hisobni o'chirish: Profil → Hisobni o'chirish (so'rov admin tomonidan ko'rib chiqiladi).
- Maxfiylik siyosati: https://vidamarket.uz/privacy
