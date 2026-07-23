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

## Hozircha qamrovdan tashqarida (keyingi bosqich)

- Rasm yuklab progress/complete qilish — hozircha faqat matnli izoh bilan
  ishlaydi (`image_picker` + Android kamera/fayl ruxsatlari kerak, alohida
  qo'shiladi).
- Xaridor Android'dan buyurtma **bermaydi** (faqat narx/3D ko'radi va mavjud
  buyurtmalar statusini kuzatadi) — spetsifikatsiyaga mos qamrov qarori.
- Firma obuna/to'lov holati bo'yicha 3D-fayl cheklovi — hali qo'yilmagan
  (web/iOS bilan bir xil qaror: hozircha cheklovsiz).
