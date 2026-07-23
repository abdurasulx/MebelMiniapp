# Furniture Platform — Android (Flutter)

Bu papka **shu Mac'da Flutter SDK o'rnatilmagani** (joy tanqisligi) sababli
faqat `lib/` (Dart kodi) va `pubspec.yaml` bilan tayyorlandi — Android/iOS
platforma qatlamlari (`android/`, `ios/` papkalar) hali generatsiya
qilinmagan. Bularni **Asus noutbukingizda** generatsiya qilasiz.

## Birinchi marta sozlash (Asus noutbuk)

1. Flutter SDK va Android Studio o'rnating: https://docs.flutter.dev/get-started/install
2. `flutter doctor` orqali sozlamani tekshiring.
3. Shu papkaga kiring:
   ```
   cd flutter_app
   flutter create --org uz.furnitureplatform --project-name furniture_platform_mobile .
   ```
   Bu **mavjud** `lib/` va `pubspec.yaml`ni buzmaydi — faqat yetishmayotgan
   `android/`, native fayllarni qo'shadi (standart Flutter xatti-harakati).
4. `flutter pub get`
5. **Backend Asus'da qayta ishga tushirilmaydi** — Mac'dagi backend'ga Wi-Fi
   orqali ulanadi (`lib/api_client.dart` — `ApiConfig.baseUrl`, standart
   qiymat allaqachon Mac'ning joriy Wi-Fi IP'siga sozlangan:
   `http://192.168.100.185:8000/api/v1`). Buning uchun:
   - **Mac va Asus bir xil Wi-Fi tarmog'ida** bo'lishi shart.
   - Mac'da backend `0.0.0.0:8000`ga bog'langan holda ishlab turishi kerak
     (`.claude/launch.json`dagi "backend" konfiguratsiyasi shunday
     sozlangan — faqat `127.0.0.1` bo'lsa, tashqi qurilmalar ulana olmaydi).
   - Mac'ning IP'si Wi-Fi qayta ulanganda o'zgarishi mumkin — Mac'da
     `ipconfig getifaddr en0` bilan tekshirib, kerak bo'lsa
     `lib/api_client.dart`dagi qiymatni yangilang, yoki qayta
     kompilyatsiyasiz: `flutter run --dart-define=API_BASE_URL=http://<yangi-ip>:8000/api/v1`
   - Android **emulyator**da (Asus'ning o'zida) ham shu IP ishlaydi —
     `10.0.2.2` bu holatda kerak emas, chunki backend endi Asus'da emas.
6. `flutter run` — tayyor.

## Git haqida eslatma

`.gitignore`da hozircha `android/`, `ios/` va h.k. papkalar **e'tiborsiz
qoldirilgan** — chunki ular hali generatsiya qilinmagan va shu Mac'da
tekshirib bo'lmadi. `flutter create .` bilan generatsiya qilib, ilova ishga
tushganidan keyin, agar shu native papkalarni ham git'ga qo'shmoqchi bo'lsangiz
(odatiy amaliyot — CI/CD yoki custom native sozlamalar bo'lsa kerak bo'ladi),
`.gitignore`dan o'sha qatorlarni olib tashlang va commit qiling.

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

## Hozircha qamrovdan tashqarida (keyingi bosqich)

- Rasm yuklab progress/complete qilish — hozircha faqat matnli izoh bilan
  ishlaydi (`image_picker` + Android kamera/fayl ruxsatlari kerak, alohida
  qo'shiladi).
- Xaridor Android'dan buyurtma **bermaydi** (faqat narx/3D ko'radi va mavjud
  buyurtmalar statusini kuzatadi) — spetsifikatsiyaga mos qamrov qarori.
- Firma obuna/to'lov holati bo'yicha 3D-fayl cheklovi — hali qo'yilmagan
  (web/iOS bilan bir xil qaror: hozircha cheklovsiz).
