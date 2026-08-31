# Furniture Platform — Android (Flutter)

`android/` papkasi endi **git'ga commit qilingan** (birinchi marta Asus
noutbukda `flutter create .` bilan generatsiya qilinib, kerakli tuzatishlar
— masalan cleartext-traffic ruxsati — qo'lda kiritilgan holda saqlangan).
Bu degani: `git clone`dan keyin **`flutter create .` qayta ishga tushirish
shart emas** — `flutter pub get` va `flutter run` yetarli.

## Birinchi marta sozlash (Asus noutbuk)

1. Flutter SDK va Android Studio o'rnating: https://docs.flutter.dev/get-started/install
2. `flutter doctor` orqali sozlamani tekshiring.
3. `cd flutter_app`
4. `flutter pub get`
5. **Ilova haqiqiy domenga ulanadi** — `lib/api_client.dart` —
   `ApiConfig.baseUrl`, standart qiymat: `https://api.qrbite.uz/api/v1`
   (nginx TLS terminatsiya qilib, backend'ga proksi qiladi). Tailscale VPN
   yoki boshqa lokal tarmoq sozlamasi kerak emas — ilova qayerdan (Wi-Fi,
   mobil tarmoq) ishga tushirilmasin, domen barqaror ishlaydi.
   - Boshqa (masalan lokal dev) backend'ga ulash kerak bo'lsa, qayta
     kompilyatsiyasiz almashtirish mumkin:
     `flutter run --dart-define=API_BASE_URL=<boshqa-manzil>`
6. `flutter run` — tayyor. Birinchi ochilishda ilova viloyat filtri uchun
   **lokatsiya ruxsati** so'raydi (`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`,
   `AndroidManifest.xml`ga qo'shilgan) — rad etilsa yoki GPS o'chiq bo'lsa,
   katalog shunchaki "Barchasi" holatida qoladi, ilova ishlashda davom etadi.

## Git haqida eslatma

`android/` qo'lda commit qilingan (build keshi — `android/.gradle`,
`android/app/build` — bundan mustasno, ular `.gitignore`da qoladi).
`ios/`, `macos/`, `linux/`, `windows/`, `web/` esa ishlatilmagani uchun
hamon e'tiborsiz qoldirilgan (native iOS ilova alohida — `ios/` papka
repo ildizida, `flutter_app/` ichida emas).

**Agar `AndroidManifest.xml`ga yana qo'lda tuzatish kiritsangiz** (masalan
yangi ruxsat), uni commit qilib push qilishni unutmang — aks holda faqat
sizning mahalliy nusxangizda qoladi va boshqa joyda `git clone` qilinganda
yo'qoladi.

## Arxitektura (backend bilan bir xil)

Bu ilova **xuddi shu Django REST API**dan foydalanadi (`backend/`) — alohida
backend kerak emas. Web (`frontend/`) va iOS (`ios/`) bilan bir xil
endpointlar ishlatiladi:

- **Auth**: email/parol (`/auth/token/`) yoki telefon+SMS-OTP
  (`/auth/otp/request/` → `/auth/otp/verify/`, hozircha SMS provayder
  ulanmagani uchun kod javobda `debug_code` sifatida qaytadi — production'ga
  chiqishdan oldin bitta joy, `AuthStore.requestOTP`, almashtiriladi).
- **Rollar**: bitta hisob ham xaridor, ham (agar biror firmada ishlasa) usta
  sifatida foydalanishi mumkin — profil ichidagi "Ko'rinish rejimi" tugmasi
  bilan almashtiriladi (backend `role`sini o'zgartirmaydi, faqat mahalliy UI
  holati — `AppMode`).
- **Worker ID** — profilda ko'rinadigan 10 xonali raqamli ID; firma egasi shu
  ID orqali ishga taklif yuboradi (`/employee-invitations/`), foydalanuvchi
  profilidan qabul/rad qiladi.
- **Usta rejimi**: faqat o'z firmasining mahsulotlari/3D fayllari
  (`/products/?company=<slug>`), o'z firmasi buyurtmalarini boshqarish
  (status o'zgartirish + ishlab chiqarish bosqichlarini progress/complete
  qilish — `/workflow-instances/<id>/progress|complete/`).
- **Viloyat bo'yicha filtr**: bir nechta viloyatda filiali bor firmalar uchun
  — `LocationStore` (`lib/location_store.dart`) GPS orqali foydalanuvchi
  joylashgan viloyatni aniqlaydi (`geolocator` paketi, taxminiy viloyat
  markazlariga eng yaqinini tanlab — tashqi geocoding API kaliti kerak
  emas), katalog `?viloyat=<kod>` parametri bilan filtrlanadi (backend
  `Branch.viloyat`). Foydalanuvchi katalogdagi chip orqali qo'lda ham
  boshqa viloyat tanlashi yoki "Barchasi"ni tanlashi mumkin. "Top tovarlar"
  chipi `?ordering=top` (like soni bo'yicha) filtrini yoqadi.
- **Mahsulot sahifasi**: rasmlar galereyasi (bir nechta rasm bo'lsa
  PageView + nuqta indikator) tepada, layk/ulashish tugmalari galereya
  ustida; 3D model bo'lsa "3D ko'rish" tugmasi orqali alohida bottom-sheet
  oynada ochiladi (galereyaning o'ziga aralashmaydi).

- **Savat va buyurtma berish**: `CartStore` (`lib/cart_store.dart`) qurilmada
  saqlanadi (web `cart.js` bilan bir xil naqsh), "Savat" tabida checkout
  formasi (telefon/manzil/izoh) bilan haqiqiy `Order` yaratiladi. Bitta
  buyurtmada faqat bitta kompaniya bo'lishi mumkinligi sababli (backend
  qoidasi), savatdagi mahsulotlar kompaniya bo'yicha guruhlanib, har biriga
  alohida `/orders/` so'rovi yuboriladi — xuddi web `Cart.jsx`dagidek.

## Hozircha qamrovdan tashqarida (keyingi bosqich)

- Rasm yuklab progress/complete qilish — hozircha faqat matnli izoh bilan
  ishlaydi (`image_picker` + Android kamera/fayl ruxsatlari kerak, alohida
  qo'shiladi).
- Firma obuna/to'lov holati bo'yicha 3D-fayl cheklovi — hali qo'yilmagan
  (web/iOS bilan bir xil qaror: hozircha cheklovsiz).
