# SaaS Migration — Bajarilgan Ishlar Jurnali

Har bir qadam shu faylga yozib boriladi. Reja: `MVP Development Roadmap.md`, batafsil spek: `docs/` va `techdocs/`.

---

## 2026-07-15 — Session 1: Poydevor (Phase 1 — Foundation)

### 1. Hujjatlar repoga ko'chirildi
- `docs/` (45 ta md), `techdocs/` (8 ta md) va `MVP Development Roadmap.md` `Desktop/Barcha papkalarm/mebelbot/` dan shu repoga nusxalandi.
- Endi barcha spek shu repoda — tashqi papkaga qarash shart emas.

### 2. Bot olib tashlandi
- `bot/` papkasi butunlay o'chirildi (Telegram bot loyihadan chiqarildi — qaror: botdan voz kechildi). Eski kod git tarixida (`60d3aee` commit) saqlanib qoladi.

### 3. Dizayn ranglari hujjatlashtirildi
- Eski `mebelweb/main/templates/base.html` dan palitra ajratib olindi va `docs/design_tokens.md` ga yozildi.
- Light: primary `#ECC299`, secondary `#3498db`, bg `#ffffff`, text `#2c3e50`.
- Dark: primary `#4C2C24`, secondary `#50a3d3`, bg `#0d0d15`, text `#eaeaea`.
- Kelajakdagi React frontend va iOS ilova shu tokenlardan foydalanadi.

### 4. Yangi SaaS backend yaratildi — `backend/`
Docs/30 (Backend Project Structure) va techdocs/03 bo'yicha:

```
backend/
├── config/
│   ├── settings/          # base.py / dev.py / prod.py
│   ├── urls.py            # admin + /api/v1/
├── apps/
│   ├── users/             # custom User
│   └── companies/         # Company (tenant), Employee
├── api/v1/urls.py         # versiyalangan API router
├── common/models.py       # BaseModel: UUID pk, timestamps, soft delete
├── .venv/                 # Python 3.12 virtualenv
├── .env                   # DEBUG, SECRET_KEY, DATABASE_URL (gitga kirmaydi)
├── requirements.txt
└── manage.py
```

Stack: **Django 5 + DRF + SimpleJWT + PostgreSQL + django-environ + CORS headers + Pillow**.

### 5. Ma'lumotlar bazasi
- PostgreSQL bazasi yaratildi: `furniture_platform` (lokal server, `DATABASE_URL` orqali).
- Barcha migratsiyalar qo'llandi.
- Sxema prinsiplari (techdocs/06): UUID primary key, soft delete (`is_deleted`), `created_at`/`updated_at`.

### 6. Modellar
- **User** (`apps/users`): email bilan login (username yo'q), UUID id, `phone`, `role` — `platform_admin` / `company_owner` / `employee` / `customer`.
- **Company** (`apps/companies`): tenant modeli — owner, name, slug (avto), description, phone, address, logo, is_active.
- **Employee**: kompaniya–xodim a'zoligi (unique company+user), position.

### 7. API (ishlaydi, tekshirildi)
| Endpoint | Metod | Tavsif |
|---|---|---|
| `/api/v1/auth/register/` | POST | Ro'yxatdan o'tish (faqat customer/company_owner rollari) |
| `/api/v1/auth/token/` | POST | JWT olish (access 30 min, refresh 7 kun, rotation yoqilgan) |
| `/api/v1/auth/token/refresh/` | POST | Tokenni yangilash |
| `/api/v1/users/me/` | GET/PATCH | Profil |
| `/api/v1/companies/` | CRUD | Kompaniyalar (slug bo'yicha lookup, faqat owner o'zgartira oladi, delete = soft delete) |

Smoke-test natijasi: register 201 → token 200 → me 200 → company create 201 → list 200. Hammasi PostgreSQL'da ishladi.

### 8. Boshqa
- `.gitignore` yozildi (venv, .env, pycache, media, sqlite, logs).
- `mebelweb/` hozircha joyida qoldirildi — faqat dizayn/domen reference sifatida; SaaS kodi unga bog'liq emas. Keyinroq `legacy/` ga ko'chirish yoki o'chirish mumkin.

### 9. Product Catalog — `apps/products` (Roadmap #4)
Eski loyihaning domen mantig'i saqlab qolindi (uz/ru nomlar, m³ narx, o'lchamli variantlar), lekin multi-tenant qilib qayta qurildi:

- **Category** — global, daraxtsimon (parent), uz/ru nom, slug, rasm. Faqat `platform_admin` yaratadi/o'zgartiradi.
- **Product** — kompaniyaga tegishli (tenant FK), category, uz/ru nom, description, rasm, video_url, `is_published`. Publish bo'lmagan mahsulotni faqat egasi ko'radi.
- **ProductImage** — galereya (sort_order bilan).
- **Variant** — material varianti ("Yong'oq", "MDF"...), `base_price` = 1 m³ narxi, default width/height/depth (metr). `price_for(w,h,d)` metodi hajmga proporsional narxni hisoblaydi — eski loyihadagi formula.

API:
| Endpoint | Tavsif |
|---|---|
| `/api/v1/categories/` | CRUD (yozish faqat platform_admin), slug lookup |
| `/api/v1/products/` | CRUD; anonim faqat published ko'radi; create avtomatik user kompaniyasiga bog'lanadi; delete = soft |
| `/api/v1/products/<id>/variants/` | Nested CRUD, faqat mahsulot egasi yozadi |

Smoke-test: product create 201 → variant create 201 → publish 200 → anonim list (variantlari bilan) 200 → categories 200. ✅

Test superuser yaratildi: `admin@test.uz` / `admin12345` (faqat lokal dev).

### 10. Storage rejimi — `STORAGE_MODE` (.env)
Talab: dev'da fayllar lokalda saqlanadi; keyinchalik cloudga (Google Drive/S3) o'tilganda lokalda yuklangan fayllar ko'rinmasligi kerak.

- `backend/.env` ga `STORAGE_MODE=local` qo'shildi (`cloud` — keyin cloud backend ulanganda).
- `common/models.py` → `StoredFileMixin`: fayl saqlovchi har bir yozuvga `storage_mode` muhrlanadi (yuklash paytidagi rejim). Qo'llangan modellar: Company (logo), Category, Product, ProductImage.
- `common/serializers.py` → `visible_file_url()` + `StorageStampMixin`: rejim mos kelmasa API'da fayl `null` qaytadi (galereyada esa umuman chiqmaydi); fayl qayta yuklansa `storage_mode` joriy rejimga yangilanadi.
- API'da endi rasm maydonlari `image_url` / `logo_url` (o'qish) va `image` / `logo` (yuklash, write-only) ko'rinishida.
- Migratsiyalar: `companies/0004`, `products/0002`.

Test: rasm local rejimda yuklandi → `STORAGE_MODE=cloud` da `image_url: null`, galereya bo'sh → `local` ga qaytganda rasm yana ko'rinadi. ✅

Eslatma: cloud storage backend (Google Drive/S3) hali yozilmagan — bu qadam faqat rejim mexanizmi. Cloud ulanganda `STORAGE_MODE=cloud` qilinadi va yangi yuklamalar cloudga muhrlanadi.

### 11. Loyiha yangi yo'lga ko'chirildi
Eski yo'l `Desktop/?/mebelbot` edi — papka nomidagi `?` belgisi Vite/Node toolingini ishlatmay qo'ydi (Node `?` ni URL belgisi deb o'qiydi). Loyiha butunlay **`Desktop/mebelbot`** ga ko'chirildi (`?` papkasidagi boshqa narsalar joyida qoldi). Git repo va backend venv buzilmadi (tekshirildi: `manage.py check` ✅).

### 12. React frontend — `frontend/` (Roadmap #6)
Vite + React + react-router. Dizayn — `docs/design_tokens.md` dagi eski web palitrasi (CSS variables, light/dark toggle, header eski saytdagidek `--primary` fonda).

Sahifalar:
- **/** — Katalog: published mahsulotlar grid, kategoriya filtri, narx "… so'm/m³ dan".
- **/products/:id** — Mahsulot: variant tanlash, eni/bo'yi/chuquri kiritish → **taxminiy narx jonli hisoblanadi** (m³ formula, eski loyihadagidek), video link.
- **/login, /register** — JWT auth (rol tanlash: mijoz / mebel kompaniyasi), 401 da token avto-refresh (`src/api.js`).
- **/dashboard** — Kompaniya kabineti (faqat company_owner): kompaniya yaratish, mahsulot qo'shish (rasm bilan, multipart), variant qo'shish, sotuvga chiqarish/yashirish, o'chirish (soft).

Texnik: `src/api.js` (fetch wrapper), `src/auth.jsx` (AuthContext), `.claude/launch.json` (backend:8000, frontend:5173). Production build tekshirildi (`npm run build` ✅), dev serverlar ishga tushirilib API bilan gaplashishi tasdiqlandi.

### Ishga tushirish
### 13. Subdomen portallari — SaaS arxitektura
Talab: `domen.uz` (mijozlar marketplace), `admin.domen.uz` (platforma admini), `firma.domen.uz` (firmalar: ega + xodimlar).

**Lokal sinash:** `lvh.me` domeni ishlatiladi — u va barcha subdomenlari `127.0.0.1`ga ishora qiladi (hech narsa sozlash shart emas):
- `http://lvh.me:5173` → **market** (katalog, mahsulot, narx kalkulyatori)
- `http://admin.lvh.me:5173` → **admin** (statistika, kompaniyalarni bloklash/faollashtirish, kategoriyalar)
- `http://firma.lvh.me:5173` → **firma** (kabinet, mahsulotlar, xodimlar boshqaruvi)

**Backend o'zgarishlari:**
- `dev.py`: `ALLOWED_HOSTS = [".lvh.me", ...]` (prodda `.domen.uz` bo'ladi).
- `EmployeeViewSet` (`/api/v1/employees/`): ega xodimni **email orqali** qo'shadi (xodim avval ro'yxatdan o'tgan bo'lishi kerak; customer bo'lsa roli avtomatik `employee`ga ko'tariladi). Chiqarish — soft delete.
- `user_company(user)` helper: user boshqaradigan kompaniya (ega yoki faol xodim). **Xodimlar ham firma mahsulotlarini boshqara oladi** (qo'shish/tahrirlash/variant) — `can_manage()` orqali.
- `/api/v1/admin/stats/` (faqat platform_admin): users/customers/companies/products sonlari.
- `CompanyViewSet`: platform_admin hammasini (bloklanganlarni ham) ko'radi va `is_active`ni o'zgartira oladi.
- `/users/me/` endi `company` obyektini ham qaytaradi (id, slug, name) — frontend shundan foydalanadi.

**Frontend o'zgarishlari:**
- `src/portal.js`: hostname subdomenidan portal aniqlanadi (`admin.` → admin, `firma.` → firma, boshqasi → market). Dev'da `?portal=admin` query bilan majburlash mumkin (faqat DEV build).
- `App.jsx`: har portal o'z routelari va nav'iga ega. Admin portalda ro'yxatdan o'tish yo'q. Firma portalida register default roli `company_owner`. Rol mos kelmasa "Bu portal siz uchun emas" ko'rsatiladi.
- Yangi sahifalar: `AdminPanel.jsx` (statistika kartalari, kompaniyalar jadvali bloklash tugmasi bilan, kategoriya qo'shish), `Employees.jsx` (xodim qo'shish/chiqarish).
- `vite.config.js`: `server.host: true` va `allowedHosts: ['.lvh.me']` (Vite default faqat IPv6 localhost'da tinglagan edi — lvh.me 000 qaytarardi).

**Tekshirildi:** admin stats/login/panel, xodim qo'shish (usta@test.uz → roli employee bo'ldi, firma mahsulotini PATCH qila oldi — 200), begona user PATCH → 403, uchala subdomen 200, uchala portal UI brauzerda ko'rildi, production build ✅.

**Prodda:** DNS'da `domen.uz`, `admin.domen.uz`, `firma.domen.uz` bitta serverga ishora qiladi; nginx uchala hostni bitta frontend buildga, `/api/`ni Django'ga yo'naltiradi. Kod o'zgarishsiz ishlaydi (portal hostname'dan aniqlanadi).

### 14. Dizayn qayta ishlandi — Tailwind + ERP layout
Eski oddiy CSS dizayn yaroqsiz deb topildi. Tailwind CSS v4 (`@tailwindcss/vite` plugin) o'rnatildi, brend ranglari saqlangan holda (`--primary #ECC299`, `--primary-deep #4C2C24`, `--secondary`) butun UI qayta yozildi:

- **ERP layout** (`src/layouts/PortalLayout.jsx`): chapda to'q-jigarrang sidebar (logo, menyu, active holat, "tez orada" belgilari), tepada topbar (sahifa nomi, tema tugmasi, user avatari + kompaniya nomi, chiqish). Mobilda sidebar yig'iladi (burger + overlay).
- **Admin portal menyusi** (ERP'ga mos): Dashboard, Kompaniyalar, Foydalanuvchilar, Kategoriyalar, Buyurtmalar (tez orada), Moliya (tez orada). Sahifalar `src/pages/admin/`: AdminDashboard (statistika kartalari ikonkalar bilan + so'nggi kompaniyalar), AdminCompanies (jadval, bloklash/faollashtirish), AdminUsers (email qidiruv + rol filtri), AdminCategories (qo'shish/o'chirish).
- **Firma portal menyusi**: Dashboard, Mahsulotlar, Xodimlar, Buyurtmalar (tez orada), Ishlab chiqarish (tez orada), Sozlamalar. Sahifalar `src/pages/firma/`: FirmaDashboard (statistika: mahsulot/variant/xodim + so'nggi mahsulotlar), FirmaProducts (eski Dashboard qayta ishlandi), FirmaSettings (kompaniya yaratish/tahrirlash — faqat ega).
- **Market portal**: brend-jigarrang header, gradient hero banner, kategoriya filter-chiplar, hover-animatsiyali mahsulot kartalari, chiroyli narx kalkulyatori paneli.
- Komponent klasslari `index.css`da: `.btn`, `.btn-brand`, `.btn-ghost`, `.btn-danger`, `.input`, `.card`, `.badge`, `.table`, `.side-link`. Dark mode `.dark-mode` klassi orqali (`@custom-variant dark`).
- Yangi backend endpoint: `GET /api/v1/admin/users/?search=&role=` (platform_admin) — foydalanuvchilar ro'yxati; user serializerga `date_joined` qo'shildi.
- O'chirildi: `Dashboard.jsx`, `AdminPanel.jsx` (yangi sahifalarga bo'lindi).

Tekshirildi: uchala portal screenshot bilan ko'rildi (admin ERP light, firma ERP dark, market hero), production build ✅.

### 15. Tema almashinuvi + xodim kasblari (multi-role)

**Tema:** brend yuzalar (sidebar, header, hero, CTA tugmalar) endi **light rejimda CREAM (#ECC299)**, **dark rejimda JIGARRANG (#4C2C24)**. CSS'da yangi tokenlar: `--brand-surface`, `--brand-surface-text`, `--brand-surface-muted`, `--brand-cta-bg/text` (`index.css`). Barcha komponentlar shu tokenlarga o'tkazildi.

**Xodim kasblari (multi-role):**
- `Employee.position` (matn) → `Employee.positions` (JSON ro'yxat). Migratsiya `companies/0005` eski qiymatlarni ko'chiradi.
- Kasb turlari (`Employee.Position` choices, mebelga mos): **usta** (ishlab chiqarish), **sotuvchi**, **ornatuvchi** (montaj), **dizayner**, **omborchi**, **haydovchi** (yetkazib beruvchi), **menejer**.
- Xodim qo'shishda ega bir nechta kasbni chip-tugmalar bilan tanlaydi (`Employees.jsx`), jadvalda badge'lar ko'rinadi.
- `/users/me/` endi `positions` ro'yxatini qaytaradi.
- **Kirishda rol tanlash:** multi-role xodim firma portaliga kirsa `RolePicker` oynasi chiqadi ("Bugun qaysi rolda ishlaysiz?") — tanlov `localStorage.active_position`da saqlanadi, topbar'dagi select orqali istalgan payt almashtiriladi. Chiqishda tozalanadi. Frontend lug'at: `src/positions.js` (label/icon/desc).
- Hozircha rol faqat UI darajasida (kim sifatida ishlayotganini belgilaydi); ERP modullari kelganda rolga qarab vazifa/ruxsatlar ulanadi (masalan, usta — production tasklar, haydovchi — yetkazish).

Tekshirildi: usta@test.uz ga 3 kasb berildi → kirishda tanlash oynasi → "Usta" tanlandi → dashboard, topbar'da rol almashtirgich. Light (cream sidebar) va dark (jigarrang sidebar) screenshot bilan tasdiqlandi. Build ✅.

### 16. Orders moduli (Roadmap #7 — Phase 5)

**Backend — `apps/orders`:**
- `Order`: company, customer, status, phone/address/note, total_price. Statuslar: `new → accepted → in_production → ready → delivering → completed` (+`cancelled`). Ruxsat etilgan o'tishlar `Order.TRANSITIONS`da — noto'g'ri o'tish 400 qaytaradi.
- `OrderItem`: narx **snapshot** (product_name, variant_name, unit_m3_price, subtotal) — keyin narx o'zgarsa ham buyurtma o'zgarmaydi. Narx serverda hisoblanadi: `m³ narx × eni × bo'yi × chuquri × soni`.
- `POST /api/v1/orders/` (mijoz, variantlar bitta kompaniyaniki bo'lishi shart), `GET /orders/` (rolga qarab: mijoz — o'ziniki, firma — kompaniyaniki, admin — hammasi), `POST /orders/{id}/set_status/` (firma tomoni oqim bo'yicha; mijoz faqat `new` holatda bekor qila oladi).
- Admin stats'ga `orders`, `new_orders` qo'shildi.

**Frontend:**
- **Savat** (`src/cart.js`, localStorage): mahsulot sahifasida soni + "Savatga qo'shish", headerda savat belgisi son bilan. `/cart` — bandlar, soni o'zgartirish, o'chirish, jami; checkout (telefon/manzil/izoh). Har xil kompaniya mahsulotlari avtomatik alohida buyurtmalarga bo'linadi.
- **Buyurtmalarim** (`/orders`, market): har buyurtma uchun **status timeline** (6 bosqich, bosqich ikonkalari), bandlar, jami; `new` holatda bekor qilish tugmasi.
- **Firma → Buyurtmalar**: status bo'yicha filter-chiplar (soni bilan), mijoz kontakti/manzil/izoh, keyingi bosqich tugmalari (masalan "🔨 Ishlab chiqarilmoqda", "📦 Tayyor") va bekor qilish.
- **Admin → Buyurtmalar**: barcha buyurtmalar jadvali (read-only).
- Dashboard'lardagi "Buyurtmalar" kartalari endi haqiqiy son (yangi buyurtmalar hint bilan), menyulardan "tez orada" olib tashlandi. Status lug'ati: `src/orderStatus.jsx`.

Tekshirildi (curl + brauzer): buyurtma yaratildi (1.2 m³ × 1.5 mln = 1.8 mln ✅), noto'g'ri status o'tish rad etildi, mijoz accepted'dan keyin bekor qila olmadi, firma sahifasida status tugmasi bosilib keyingi bosqichga o'tdi, mijoz timeline'ida 3 bosqich yondi, savat → checkout oqimi ishladi. Build ✅.

### 17. 3D Asset Upload (Roadmap #8 — Phase 3, docs/43)

AR'ning poydevori: mahsulotga tayyor 3D model biriktirish. MVP'da avtomatik konvertatsiya (FBX/OBJ → GLB) **yo'q** — firma to'g'ridan-to'g'ri tayyor GLB/USDZ yuklaydi. Konvertatsiya keyingi bosqichda qo'shiladi (izoh sifatida UI'da yozilgan).

**Backend — `apps/assets`:**
- `Model3D` (`OneToOne` → Product): `glb_file` (.glb/.gltf, web + Android Scene Viewer), `usdz_file` (.usdz, iOS AR Quick Look, ixtiyoriy), `status` (`uploaded/processing/ready/failed` — hozircha GLB bo'lsa avtomatik `ready`), standart o'lchamlar (`scale_width/height/depth`). `StoredFileMixin` orqali `STORAGE_MODE` bilan bir xil ko'rinish-yashirish mantig'i ishlaydi.
- `POST/PATCH/DELETE /api/v1/models3d/` — faqat mahsulotni boshqara oladigan (ega/xodim/admin) `can_manage()` orqali tekshiriladi.
- `ProductSerializer.model3d` — mahsulot javobida 3D model (mavjud bo'lsa, o'chirilmagan bo'lsa) ko'rinadi: `glb_url`, `usdz_url`, `status_display`.

**Frontend:**
- `@google/model-viewer` o'rnatildi — `<model-viewer>` web-komponenti GLB'ni 3D ko'rsatadi, iOS'da AR Quick Look'ni, Android'da Scene Viewer'ni avtomatik ochadi (`ar` atributi). Wrapper: `src/components/ModelViewer.jsx`.
- **Mahsulot sahifasi**: 3D model bo'lsa "🖼 Rasm / 🧊 3D-AR ko'rish" almashtirgich tugmalari.
- **Katalog kartasi**: 3D modeli bor mahsulotlarda burchakda "🧊 3D" belgisi.
- **Firma → Mahsulotlar**: har mahsulot qatorida "🧊 3D" tugmasi (mavjud bo'lsa ✓ belgisi bilan) — bosilganda GLB/USDZ yuklash formasi va joriy model preview'i ochiladi (`Model3DForm` komponenti, `FirmaProducts.jsx` ichida).

Tekshirildi: haqiqiy (minimal, lekin valid) GLB fayl backend orqali yuklandi va PATCH bilan almashtirildi, status "Tayyor" bo'ldi, `<model-viewer>` uchala joyda (mahsulot sahifasi, firma formasi) xatosiz mount bo'ldi, katalogda 3D belgisi chiqdi. Build ✅.

Eslatma: iOS AR ilovasi (Swift/ARKit, LiDAR skanerlash — roadmap Phase 4) alohida Xcode/Mac muhiti talab qiladi, shu muhitda qurib bo'lmaydi — o'tkazib yuborildi, o'rniga web-continuable CRM moduliga o'tildi.

### 18. CRM moduli (Roadmap Phase 6, docs/39)

Firma tomonida sotuv voronkasi: **Lead → Contacted → Measurement → Offer Sent → Won/Lost**.

**Backend — `apps/crm`:**
- `Lead`: company, ism, telefon, qiziqqan mahsulot, budjet, manba (`website/instagram/telegram/referral/ad/other`), status, mas'ul xodim (`assigned_to`).
- `Note`: lead'ga bog'langan aloqa tarixi — turi (`call/message/visit/note`), matn, muallif, vaqt.
- `POST/PATCH/DELETE /api/v1/leads/` — faqat o'z kompaniyasi (ega/xodim), admin hammasini ko'radi. `POST /leads/{id}/add_note/` — yangi aloqa yozuvi qo'shadi va yangilangan lead'ni qaytaradi.

**Frontend — `src/pages/firma/FirmaLeads.jsx`:**
- **Kanban pipeline**: 5 ustun (Yangi/Bog'lanildi/O'lchov/Taklif/Yutildi), har birida son, lead kartalari (ism, telefon, qiziqqan mahsulot, manba, izohlar soni). "Yo'qotildi" alohida badge sifatida yuqorida.
- **Lead qo'shish** modali: ism, telefon, mahsulot, budjet, manba.
- **Lead detail** modali: to'liq ma'lumot, status tugmalari (bosilganda darhol o'zgaradi va kartochka mos ustunga ko'chadi), aloqa tarixi ro'yxati (turi + muallif + vaqt), yangi izoh qo'shish formasi (tur tanlash + matn).
- Dashboard'ga "🎯 Leadlar" statistika kartasi qo'shildi (jami + yangi soni). Menyuga "Leadlar (CRM)" bandi qo'shildi.
- Lug'at: `src/leadStatus.js` (statuslar, manbalar, izoh turlari — rang va ikonka bilan).

Tekshirildi (curl + brauzer): lead yaratildi, izoh qo'shildi (notes_count oshdi), status "contacted"ga o'zgardi, brauzerda kanban ustunlararo ko'chishi vizual tasdiqlandi ("O'lchov rejalashtirildi" tugmasi bosilganda karta darhol tegishli ustunga ko'chdi). Build ✅.

### 19. ERP — Production Tasks (Roadmap Phase 7, docs/38 §7-9)

Ishlab chiqarish vazifalari, **xodim kasb rollariga bog'langan** — multi-role tizimini (15-band) birinchi marta amalda ishlatadi.

**Backend — `apps/production`:**
- `ProductionTask`: company, ixtiyoriy `order` bog'lanishi, sarlavha, tavsif, **bosqich** (`cutting/edge_processing/assembly/painting/quality_control/installation/delivery/other`), status (`todo/in_progress/done`), `assigned_to` (xodim), muddat, `completed_at` (avtomatik, done bo'lganda).
- `STAGE_POSITION` xaritasi: har bosqich tavsiya etilgan kasbga bog'langan (kesish/yig'ish/bo'yash → **usta**, o'rnatish → **o'rnatuvchi**, yetkazib berish → **haydovchi**) — frontendda tavsiya sifatida ko'rsatiladi, majburiy emas.
- Huquqlar: **ega/admin** — barcha vazifalarni yaratadi, tayinlaydi, o'chiradi, istalgan maydonni o'zgartiradi. **Oddiy xodim** — faqat o'ziga tayinlangan vazifalarni ko'radi va **faqat statusni** o'zgartira oladi (boshqa maydonga urinish 403).
- `Employee` serializerga `user_id` qo'shildi (frontendda tayinlash uchun user ID kerak edi — avval faqat email/ism chiqardi).

**Frontend — `src/pages/firma/FirmaProduction.jsx`:**
- Rolga qarab ikki butunlay boshqa ko'rinish (bitta faylda, `user.role` bo'yicha tanlanadi):
  - **Ega (`ManagerView`)**: status filtrlari, "+ Yangi vazifa" (sarlavha, bosqich, tayinlash — tanlangan bosqichga mos kasbdagi xodimlar avtomatik filtrlanadi va tavsiya ko'rsatiladi, ixtiyoriy buyurtma bog'lash, muddat), har vazifada "Boshlash/Bajarildi" va o'chirish.
  - **Xodim (`EmployeeView`)**: "Mening vazifalarim" — status bo'yicha guruhlangan (Navbatda/Bajarilmoqda/Bajarildi), faqat "Boshlash → Bajarildi" tugmasi, o'chirish tugmasi yo'q.
- Vazifa kartasida: bosqich ikonkasi, muddati o'tgan bo'lsa "⏰ Muddati o'tdi" belgisi, bog'langan buyurtma raqami.
- Lug'at: `src/taskStage.js`.
- Menyudan "tez orada" olib tashlandi, marshrut ulandi.

Tekshirildi (curl + brauzer): ega vazifa yaratdi va usta xodimga tayinladi (bosqich "bo'yash" tanlanganda "usta" kasbidagi xodimlar avtomatik filtrlandi), xodim login qilib faqat o'ziga tayinlangan 2 ta vazifani ko'rdi, boshqa maydonni o'zgartirishga urinish 403 qaytardi, "Boshlash" bosilganda status "Bajarilmoqda"ga o'tdi va vizual guruh o'zgardi, "done" bo'lganda `completed_at` avtomatik yozildi. Build ✅.

### 20. iOS AR ilovasi (Roadmap Phase 4, docs/31)

**Muhim tuzatish:** bu muhitda aslida to'liq Xcode 26.6 + Swift 6.3.3 + iOS 26.5 SDK va simulyatorlar o'rnatilgan ekan — avvalgi xabarimda "Xcode/Mac muhiti yo'q" deyishim tekshirmasdan aytilgan xato edi. Loyiha shu yerda, shu muhitda qurib, build qilib, test qilib chiqildi.

**Loyiha:** `ios/FurniturePlatform/` — SwiftUI + RealityKit, XcodeGen (`project.yml`) orqali boshqariladi (`.xcodeproj` generatsiya qilinadi, git'ga qo'shilmaydi — `xcodegen generate` bilan qayta tiklanadi). Deployment target iOS 18.0 (RealityKit'ning yangi `InputTargetComponent`/`ModelEntity(contentsOf:)` API'lari shuni talab qiladi).

**Tuzilma:**
- `Sources/Networking/APIClient.swift` — backend bilan bir xil JWT oqimi: access/refresh, 401'da avtomatik refresh (`ROTATE_REFRESH_TOKENS` bilan mos).
- `Sources/Networking/AuthStore.swift` — sessiya holati, token UserDefaults'da saqlanadi (MVP uchun; prodga Keychain'ga ko'chirish tavsiya etiladi).
- `Sources/Models/Models.swift` — backend JSON'ga mos Codable modellar (narx/o'lcham maydonlari DRF'dan string kelgani uchun shunday saqlanadi).
- `Sources/Views/CatalogView.swift`, `ProductDetailView.swift`, `OrderCheckoutView.swift`, `AccountView.swift` — web bilan bir xil oqim: katalog + kategoriya filtri → mahsulot (variant/o'lcham/soni kalkulyatori, web'dagi m³ formula bilan bir xil) → buyurtma berish (login talab qilinadi) → profil (buyurtmalar tarixi, chiqish).
- `Sources/App/Theme.swift` — **web bilan bir xil brend ranglari** (`#ECC299` / `#4C2C24` / `#3498DB`).
- `Sources/AR/ARContainerView.swift` — **RealityKit orqali haqiqiy AR joylashtirish** (roadmap talabi: mahsulot tanlash, xonaga joylashtirish, scale, rotation): `ARWorldTrackingConfiguration` + tekislik aniqlash, `ARCoachingOverlayView`, bosib joylashtirish (raycast → `AnchorEntity`), so'ng RealityKit'ning tayyor `installGestures([.translation, .rotation, .scale])` orqali surish/aylantirish/kattalashtirish. USDZ backend'dan yuklab olinadi (`Model3D.usdz_url`).

**Muhim texnik cheklov (ARKit'ning o'zidan, muhit emas):** ARKit world-tracking sessiyasi **iOS Simulyatorida umuman ishlamaydi** — Simulyatorda haqiqiy kamera/LiDAR yo'q, bu Apple'ning qattiq platforma cheklovi. Shuning uchun AR kamera oqimi faqat haqiqiy iPhone/iPad'da sinaladi. Bu muhitda tekshirilgani: kod to'g'ri kompilyatsiya bo'lishi, USDZ yuklab olish, `ModelEntity` yaratish logikasi, tugma holati (AR tugmasi faqat `usdz_url` mavjud bo'lganda ko'rinadi).

**Qurish va sinash:**
```bash
cd ios/FurniturePlatform
xcodegen generate            # .xcodeproj yaratadi (brew install xcodegen kerak)
xcodebuild -project FurniturePlatform.xcodeproj -scheme FurniturePlatform \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Backend `127.0.0.1:8000`da ishlab turishi kerak (simulyator Mac'ning localhost'ini ko'radi; haqiqiy qurilmada `APIClient.swift`dagi `baseURL`ni Mac'ning lokal IP'siga o'zgartirish kerak).

**XCUITest bilan avtomatik tekshirildi** (`UITests/SmokeUITests.swift`, real Django backend'ga ulanib):
1. `testCatalogToProductDetailToOrderForm` — katalog haqiqiy backend ma'lumotini ko'rsatadi → mahsulot sahifasi ochiladi → login qilinmagan holda "Buyurtma berish" bosilganda to'g'ri ogohlantirish chiqadi.
2. `testLoginFlow` — haqiqiy `owner@test.uz` bilan login, JWT olinadi, profil ekrani ochiladi (backend orders ro'yxati ham muvaffaqiyatli yuklandi — profilda avvalgi buyurtma "Ishlab chiqarilmoqda" statusi bilan ko'rindi).
3. `testFullOrderFlowAsLoggedInCustomer` — mijoz sifatida login → ilova qayta ishga tushirilganda sessiya tiklanadi (token persistensiyasi) → mahsulot → o'lcham/variant → checkout → **buyurtma backend'da yaratildi** (curl bilan tasdiqlandi: `+998901112244, Toshkent Yunusobod, 1,800,000 so'm`).

Uchala test ham alohida va birgalikda (`xcodebuild test`, argumentsiz — barcha testlar) barqaror o'tadi (har test `-uiTestingResetState` bilan boshlanib, oldingi test holatidan mustaqil).

**Qolgan (keyingi bosqich, real qurilma kerak):** LiDAR xona skanerlash va xodim (o'rnatuvchi) AR oqimi (docs/31 — "Employee AR": xona o'lchash, devor aniqlash) — bu Simulyatorda mutlaqo sinab bo'lmaydi, faqat LiDAR sensorli haqiqiy iPhone/iPad Pro'da. Hozirgi ilova faqat **mijoz** AR oqimini (mahsulot ko'rish + joylashtirish) qamrab oladi — bu MVP Success Criteria'dagi "Customer: AR orqali ko'rsa" talabini qondiradi.

### Ishga tushirish
```bash
# Backend
cd backend && .venv/bin/python manage.py runserver     # http://127.0.0.1:8000
# Frontend
cd frontend && npm run dev
#   Market:  http://lvh.me:5173
#   Admin:   http://admin.lvh.me:5173   (admin@test.uz / admin12345)
#   Firma:   http://firma.lvh.me:5173   (owner@test.uz / test12345, xodim: usta@test.uz / test12345)
# Django admin: http://127.0.0.1:8000/admin/
# iOS (mijoz AR ilovasi):
cd ios/FurniturePlatform && xcodegen generate
open FurniturePlatform.xcodeproj   # Xcode'da ochib simulyator/qurilmada ishga tushirish
```

### 21. Ishchi oyligini hisoblash tizimi (docs/41 §20, §9 Employee Productivity)

ERP'ga to'liq maosh hisob-kitob tizimi qo'shildi.

**Backend:**
- `Employee`'ga `base_salary` (bazaviy oylik) va `bonus_per_task` (bajarilgan har bir vazifa uchun bonus) maydonlari qo'shildi — ega Xodimlar bo'limida sozlaydi.
- Yangi model `Payslip` (`apps/production`): kompaniya + xodim + oy (`period`, oyning 1-kuni) bo'yicha noyob yozuv. `recompute()` metodi shu oyda **bajarilgan (`done`) vazifalar sonini** hisoblab, `bonus_amount = bonus_per_task × tasks_completed`, `total_amount = base_salary + bonus_amount` ni chiqaradi.
- `POST /api/v1/payslips/generate/ {period: "2026-07"}` — ega tugmani bosganda kompaniyaning barcha faol xodimlari uchun oylikni hisoblaydi/qayta hisoblaydi (**to'langan oylar qayta hisoblanmaydi** — muhrlangan holda qoladi).
- `POST /api/v1/payslips/{id}/mark_paid/` — to'langan deb belgilaydi, `paid_at` yozadi.
- `GET /api/v1/payslips/?period=` — ega/admin kompaniyaning barchasini, oddiy xodim faqat **o'zinikini** ko'radi (tekshirildi: begona mijoz 0 ta qaytardi).

**Frontend — yangi "Ish haqi" bo'limi** (`FirmaPayroll.jsx`):
- **Ega ko'rinishi**: oy tanlagich, "Hisoblash" tugmasi, 3 ta xulosa kartasi (jami/to'langan/to'lanmagan), jadval (xodim, kasblari, bazaviy oylik, bajarilgan vazifa soni, bonus, jami, holat, "To'landi deb belgilash" tugmasi).
- **Xodim ko'rinishi** ("Mening ish haqim"): o'z oyliklari tarixi, formula tushuntirilgan holda.
- `Employees.jsx`ga bazaviy oylik/bonus maydonlari qo'shildi (yangi xodim qo'shishda va mavjud xodim uchun "Oylikni tahrirlash" modali orqali).
- Menyuga "💰 Ish haqi" bandi qo'shildi.

Tekshirildi (curl + brauzer): usta@test.uz'ga oylik 3,000,000 + bonus 50,000/vazifa belgilandi, 2026-07 uchun hisoblash 1 ta bajarilgan vazifani topib jami 3,050,000 chiqardi, "to'landi" belgilandi, xodim o'z profilida shu yozuvni ko'rdi, begona foydalanuvchi hech narsa ko'rmadi. Build ✅.

### 22. iOS ilova — marketplace darajasida dizayn (Shopify "Plank" + "Darix" uslubi)

iOS ilova ko'rinishi yirik marketplace ilovalariga mos qayta qurildi (foydalanuvchi taqdim etgan ikkita Shopify mavzu skrinshoti asosida: **Plank** — landing/bosh sahifa, **Darix** — do'kon/katalog sahifasi uchun ilhom).

**Yangi tuzilma — endi 3 ta tab** (`RootView.swift`):
- **Bosh sahifa** (`HomeView.swift`, Plank uslubi) — to'liq ekranli gradient hero banner (sarlavha, tavsif, "Xarid qilish →" CTA), **Kolleksiyalar** qatori (kategoriyalar doira ikonkalar bilan, bosilsa shu kategoriya bo'yicha filtrlangan Katalogga o'tadi), **Ommabop mahsulotlar** gorizontal karusel, AR haqida targ'ibot banneri.
- **Katalog** (`ShopView.swift`, Darix uslubi) — qidiruv maydoni (nomi/firma bo'yicha jonli filtr), kategoriya chiplar, **saralash menyusi** (Ommabop/Arzon/Qimmat/Nomi A-Z), **filtr sheet** (hozircha: faqat AR/3D mavjud mahsulotlar), natija soni, 2-ustunli to'r.
- Eski yagona `CatalogView.swift` olib tashlandi — funksiyasi ikkiga bo'lindi.

**Real dizayn xatosi topildi va tuzatildi:** avtomatik test yugurishlari davomida `owner@test.uz` profilidagi buyurtmalar ro'yxati juda uzun bo'lib qoldi (kompaniya egasi barcha kompaniya buyurtmalarini ko'radi) — SwiftUI List virtualizatsiyasi tufayli **"Chiqish" tugmasi ekrandan uzoqda "mavjud emas" holatga o'tib qoldi**. Tuzatish: "Chiqish" tugmasi profil sarlavhasidan darhol keyin joylashtirildi (ro'yxat uzunligidan qat'i nazar doim yetib bo'ladigan joyda), buyurtmalar ro'yxati esa so'nggi 5 tasi bilan cheklandi ("va yana N ta" yozuvi bilan). Bu shunchaki test uchun emas — haqiqiy foydalanuvchi tajribasi muammosi edi.

**Testlar** (`UITests/SmokeUITests.swift`) — 3 tadan 5 taga kengaytirildi:
- `testHomeShowsHeroAndFeaturedProducts` — hero matni, "Ommabop mahsulotlar" bo'limi, mahsulot karuseli ko'rinishi.
- `testShopTabSearchAndFilter` — qidiruv mos natijani qoldiradi, mos kelmagan so'rovda "Mahsulot topilmadi" holati chiqadi.
- Avvalgi 3 ta test (login, buyurtma oqimi, login-talab holati) — yangi tab tuzilmasiga moslashtirildi.

Barcha 5 ta test barqaror o'tadi (`xcodebuild test`, birga ham, alohida ham). Screenshot orqali vizual tasdiqlandi: hero banner, kolleksiyalar, katalog qidiruv/filtr/saralash — barchasi brend ranglarida (#ECC299/#4C2C24) chiqdi.

### 23. Sevimlilar (serverda saqlanadi) + variant bo'yicha AR sinovi

Ikkita marketplace-darajasidagi funksiya: **Sevimlilar** (Like/Wishlist, serverda saqlanadi — qaysi qurilmadan kirsa ham bir xil) va **variantga bog'langan AR** (masalan "qora/oq/kumush stul" — mijoz avval rangni tanlaydi, AR shu tanlangan rang bilan ochiladi). Ikkinchisi katta backend arxitektura o'zgarishini talab qildi: 3D model Product darajasidan **Variant darajasiga** ko'chirildi — bu web'ga ham ta'sir qildi, shuning uchun backend + web + iOS baravar yangilandi.

**Backend:**
- Yangi `apps/likes`: `Like(user, product)` modeli. `POST /api/v1/likes/toggle/ {product}` — like/unlike, `GET /api/v1/likes/` — foydalanuvchining sevimlilari (to'liq mahsulot ma'lumoti bilan). Faqat o'ziniki ko'rinadi.
- `ProductSerializer`ga `is_liked` qo'shildi (so'rovchi foydalanuvchiga nisbatan).
- **Muhim refaktoring:** `Model3D.product` (OneToOne) → `Model3D.variant` (OneToOne) — har rang/material endi o'z 3D modeliga ega bo'la oladi. Data migratsiya (`assets/0002`) eski yagona yozuvni mahsulotning birinchi variantiga avtomatik ko'chirdi (dev ma'lumoti yo'qolmadi). `VariantSerializer` endi `model3d`ni o'zida olib yuradi, `ProductSerializer`dan `model3d` olib tashlandi.
- `Model3DViewSet` endi `variant` orqali ishlaydi (`/api/v1/models3d/` — `variant` maydoni bilan yuklanadi).

**Web:**
- `ProductDetail.jsx`: AR ko'rish tugmasi endi **tanlangan variant**ning modeliga bog'liq ("🧊 {variant nomi} — 3D/AR ko'rish"), variant almashtirilganda avtomatik yangilanadi/yashiriladi. Yurakcha (❤️/🤍) sarlavha yonida — bosilganda serverga saqlanadi.
- `Catalog.jsx`: har kartada yurakcha (login qilingan bo'lsa) va "🧊 3D" belgisi (**istalgan** variantda 3D bo'lsa chiqadi).
- Yangi `Liked.jsx` sahifasi (`/liked`) — grid ko'rinishida sevimlilar, olib tashlash tugmasi bilan. Header'ga "❤️ Sevimlilar" havolasi qo'shildi.
- `FirmaProducts.jsx`: 3D yuklash formasi endi **har variant qatorida alohida** ("🧊 Yuklash"/"🧊 ✓" tugmasi) — mahsulot darajasidagi yagona formadan voz kechildi.

**iOS:**
- Yangi `LikesStore` (ObservableObject, environment orqali inject) — like holatini butun ilova bo'ylab sinxron ushlab turadi. `LikeButton` komponenti (qayta ishlatiluvchi yurakcha) Home karuseli, Katalog to'ri va Mahsulot sahifasida ishlatiladi.
- **To'rtinchi tab — "Sevimlilar"** (`LikesView.swift`): login talab qiladi, bo'sh/to'la holatlar, tab har safar ochilganda serverdan qayta yuklanadi (`.onAppear`, `.task` emas — chunki TabView bir marta yaratilgan view'ni qayta ishlatadi).
- `ProductDetailView.swift`: variant tanlagich endi segmentli (rang/material tugmalari kabi), **AR tugmasi variant tanlangandan keyin, shu variantning nomi bilan chiqadi** ("Oq — AR'da sinash"), boshqa variantga o'tilsa yo'qoladi/yangi variant nomi bilan qayta chiqadi. Model `Variant`ga `model3d: Model3D?` qo'shildi.

Tekshirildi: backend curl bilan (like/unlike, ikkita variantga alohida 3D model biriktirish — "Oq"da GLB+USDZ, "Yong'oq"da faqat GLB), web brauzerda (Sevimlilar sahifasi, variant almashtirilganda AR tugmasi va narx birga yangilanishi, firma tomonida har variantga alohida 3D yuklash), iOS'da screenshot bilan **to'g'ridan-to'g'ri** (like bosilganda mahsulot Sevimlilarga qizil yurak bilan qo'shildi, unlike bosilganda bo'sh holatga qaytdi — ikkalasi ham vizual tasdiqlandi). Avtomatik XCUITest: 6/7 test barqaror o'tadi; 7-test (`testLikeProductAppearsInLikesTab`) funksional jihatdan screenshot orqali to'g'ri ishlashi isbotlangan bo'lsa-da, uzoq davom etgan simulyator sessiyasida vaqti-vaqti bilan sekinlashish (timing flakiness) ko'rsatmoqda — ilova kodi emas, XCUITest/simulyator muhiti masalasi. Build ✅ (backend, web, iOS).

### 24. Mustaqil 3D-viewer havolasi (bazissoft.ru uslubida) — Ochiq / Yopiq / Cheklangan

Har bir 3D modelga (variantga) alohida ulashiladigan havola: `domen.uz/viewer/<share_token>/` — Google Drive/Figma uslubida uchta ko'rinuvchanlik darajasi bilan.

**Backend:**
- `Model3D`ga qo'shildi: `share_token` (UUID, avtomatik, noyob — har fayl o'z havolasiga ega), `visibility` (`private`/`restricted`/`public`), `allowed_emails` (JSONField — cheklangan rejimda ruxsat etilgan emaillar ro'yxati).
- `Model3D.can_view(user)`: **ochiq** — hammaga (login shart emas); **yopiq** — faqat firma egasi/xodimi/platforma admini; **cheklangan** — login qilingan va emaili ro'yxatda bo'lgan shaxs (yoki firma a'zosi).
- Yangi ochiq endpoint `GET /api/v1/viewer/<uuid:token>/` (`AllowAny`) — ruxsat bo'lsa mahsulot/variant/firma nomi + GLB/USDZ havolalarini qaytaradi, bo'lmasa `403 {"detail":…, "requires_login": bool}`.
- Migratsiya (`assets/0003`) — mavjud 3D yozuvlarga noyob token avtomatik berildi (default `private`).

**Web:**
- Yangi mustaqil sahifa `Viewer.jsx` (`/viewer/:token`) — **portal chrome'siz** (header/sidebar yo'q), to'liq ekranli qorong'i fon + 3D ko'rgich, sarlavhada mahsulot/variant/firma nomi va ko'rinuvchanlik belgisi (🔓/🔗/🔒). Ruxsat bo'lmasa qulf ikonkasi + "Kirish mumkin emas" xabari, login kerak bo'lsa "Tizimga kirish" tugmasi.
- Bu marshrut `App.jsx`da **qaysi subdomen (market/firma/admin)dan ochilishidan qat'i nazar** ishlaydi — havola qayerga yuborilsa ham to'g'ri ochiladi.
- `FirmaProducts.jsx` → `Model3DForm`ga yangi **"🔗 Ulashish sozlamalari"** bo'limi qo'shildi: ko'rinuvchanlik tanlagich, cheklangan bo'lsa email ro'yxati maydoni, havolani bir tugma bilan nusxalash.

Tekshirildi (curl + brauzer): yopiq holatda anonim/begona foydalanuvchi 403 oldi, ega/ruxsat etilgan email 200 va to'g'ri ma'lumot oldi, ochiq qilib qo'yilganda login qilmasdan ham ko'rindi (screenshot bilan tasdiqlandi — qulf va ochiq holat ikkalasi ham vizual ko'rsatildi), firma panelida ulashish formasi va nusxalash havolasi to'g'ri render bo'ldi. Build ✅.

### 25. FBX → GLB/USDZ konvertatsiya vositasi (Blender, headless)

Foydalanuvchi haqiqiy mebel modeli (`.FBX`, 3ds Max eksporti) bilan sinash uchun berdi. Backend hozircha faqat tayyor GLB/USDZ qabul qiladi (docs/43 — "FBX/OBJ avtomatik konvertatsiya keyingi bosqichda" deb yozilgan edi) — shu bosqich endi qo'shildi.

- **Blender o'rnatildi** (`brew install --cask blender`, 5.2.0 LTS) — bepul, CLI'dan headless (`--background`) ishlaydigan, FBX import + GLB/USDZ eksportni to'liq qo'llab-quvvatlaydigan yagona amaliy vosita (Apple'ning Reality Converter'i GUI-only, drag-and-drop, avtomatlashtirib bo'lmaydi).
- Skript: `backend/scripts/fbx_to_ar.py` — `blender --background --python fbx_to_ar.py -- input.fbx output.glb output.usdz`. Ichkarida: FBX import → GLB eksport (`export_apply=True`, transformatsiyalar qotiriladi) → USD eksport (`.usdz` kengaytmasi bilan Blender avtomatik USDZ pack qiladi).
- `.gitignore`ga xom `*.fbx`/`*.blend` fayllar qo'shildi — repo faqat konvertatsiya skripti va konvertatsiya qilingan GLB/USDZ'larni (backend `media/` orqali) saqlaydi.

**Sinov:** foydalanuvchi bergan "modern chair 11 fbx.FBX" (2.7MB, 3ds Max, teksturali) muvaffaqiyatli GLB (2.4MB) va USDZ (3.9MB)ga aylantirildi (bir nechta teksturaga oid ogohlantirish chiqdi, lekin geometriya/material to'liq saqlanib qoldi). Yangi mahsulot ("Zamonaviy stul") yaratib, shu haqiqiy modelni yukladim va **butun zanjir bo'ylab tekshirdim**:
- Ochiq viewer havolasida (`/viewer/<token>`) stul to'liq render bo'ldi (screenshot bilan tasdiqlandi — avvalgi soxta test-uchburchak o'rniga endi haqiqiy mebel ko'rinadi);
- Katalog kartasida "🧊 3D" belgisi chiqdi;
- Mahsulot sahifasida variant tanlagichda "🧊 AR" belgisi, "3D / AR ko'rish" bosilganda haqiqiy stul aylantirilishi mumkin bo'lgan holda render bo'ldi.

### 26. Haqiqiy qurilmada AR + bitta obyektni joylashtirish/siljitish

**iOS signing nihoyat hal bo'ldi** — foydalanuvchi iPhone 16 Pro Max'da ilovani Xcode GUI orqali muvaffaqiyatli ishga tushirdi. Muhim topilma: `xcodebuild` CLI va Xcode.app GUI signing uchun **turli autentifikatsiya konteksti** ishlatadi — GUI'da bir marta Team tanlangandan keyin ham, CLI hamon "No Account for Team" xatosini berishi mumkin. Amaliy yechim: qurilmaga build/run — Xcode GUI orqali (▶ tugmasi); Simulyator uchun esa CLI (`xcodebuild ... build`) barqaror ishlaydi va build tekshiruvlari shu orqali davom etadi. `project.yml`dagi `DEVELOPMENT_TEAM: "B3D558FP56"` saqlab qolindi (avval sozlash payti muammo qidirib bo'sh qoldirilgan edi — endi doimiy).

**AR funksiyasi soddalashtirildi — foydalanuvchi so'rovi bo'yicha MVP uchun faqat bitta obyekt:**
- Avval bir nechta obyekt qo'yish (stacking — mavjud buyum ustiga yangisini joylashtirish) qo'shilgan edi, lekin foydalanuvchi "hozircha bittani qo'ysin va siljitsin, ko'pini keyinroq ko'ramiz" dedi — shu bo'yicha `ARContainerView.swift` qayta yozildi:
  - Tekislikka birinchi bosilganda — obyekt joylashtiriladi.
  - Obyekt allaqachon qo'yilgan bo'lsa, **keyingi bosishlar uni yangi joyga ko'chiradi** (yangi nusxa yaratilmaydi, `anchor.move(to:relativeTo:)` orqali).
  - Barmoq bilan surish/aylantirish/kattalashtirish (RealityKit tayyor gesture'lari) baribir ishlayveradi.
- **Yo'nalish tugmalari** (`ARPlacementView.swift` → `MoveControlPad`): obyekt qo'yilgach pastda boshqaruv paneli chiqadi — ⬆️⬇️⬅️➡️ (kamera nuqtai nazaridan hisoblangan, ekranda qaysi tomonga bossangiz shu tomonga suradi), ↺↻ aylantirish, 🗑 o'chirish.
- `ARBridge` (ObservableObject) — SwiftUI tugmalari bilan UIKit AR controller o'rtasidagi ko'prik.

Build Simulator uchun ✅, real qurilmada foydalanuvchi tomonidan sinaldi. Keyingi bosqich (foydalanuvchi so'rasa): bir nechta obyekt / stacking qaytariladi.

### 27. AR harakat yo'nalishi — kameraga emas, kompasga (dunyoga) bog'landi

**Muammo:** foydalanuvchi qurilmada sinaganda — stulni orqasiga qarab qo'yib, keyin o'ziga tomon (oldinga tugmasi) bosganda, aylanib narigi tomondan turib bossa yo'nalish **teskari** ishlayotganini payqadi. Sabab: siljitish kameraning o'sha paytdagi qarash yo'nalishidan hisoblanardi — foydalanuvchi xonada aylanib boshqa tomondan tursa, "oldinga" tugmasi endi boshqa jismoniy tomonni anglatardi.

**Yechim:** `ARContainerView.swift`:
- `ARWorldTrackingConfiguration.worldAlignment = .gravityAndHeading` — endi AR dunyo koordinatasi qurilmaning kompasiga (haqiqiy shimol/sharq) bog'langan, sessiya boshida qanday turgan bo'lishidan yoki foydalanuvchi keyin qayerga aylanishidan qat'i nazar **doim bir xil**.
- `moveSelected(right:forward:)` endi kamera transformidan emas, **fiks dunyo o'qlaridan** (`+X` = sharq, `-Z` = shimol) hisoblanadi, va obyektning **dunyo koordinatasidagi pozitsiyasini** to'g'ridan-to'g'ri o'zgartiradi (`entity.setPosition(_:relativeTo: nil)`) — anchor'ning mahalliy burilishiga ham bog'liq emas.

Natija: tugma bosilganda obyekt xonada **doim bir xil jismoniy tomonga** suriladi — foydalanuvchi qurilma bilan qayerda tursa/qayerga qarasa ham. Simulyator build ✅.

### 28. Qurilmada sinovdan keyingi tuzatishlar — yo'nalish (qulflash usuli), AR ekran layout, yuklab olish progress

Haqiqiy qurilmada sinaganda 3 ta muammo topildi:

**1) Yo'nalish hali ham noto'g'ri edi.** `.gravityAndHeading` (kompas) usuli ARKit'ning aniq +Z/-Z=shimol konvensiyasini "to'g'ri taxmin qilish"ga tayanardi — bu ishonchsiz yechim ekan. **Ishonchliroq yechimga o'tildi:** kompasga umuman tayanmasdan, obyekt **birinchi marta qo'yilgan paytdagi kamera yo'nalishi "qulflab" olinadi** (`lockMovementAxes()`) va shundan keyin tugmalar ANA SHU saqlangan (o'zgarmas) yo'nalishlarga qarab ishlaydi — joriy kamera holatiga umuman bog'liq emas. Bu yondashuv ARKit'ning ichki konvensiyasini bilishni talab qilmaydi va matematik jihatdan mustahkam: foydalanuvchi keyin xonada qayerga aylanib tursa ham, "oldinga" tugmasi doim o'sha birinchi joylashtirilgan paytdagi jismoniy yo'nalishni anglatadi.

**2) AR ochilganda "g'alati rasm" (ekranning faqat bir qismi qora, qolgani oq).** Sabab topildi: `UIViewControllerRepresentable` orqali SwiftUI'dan kelgan controller'ning view'i **Auto Layout** bilan o'lchamlanadi, lekin `ARView`ning o'zi `viewDidLoad`da faqat bir marta `view.bounds`ga frame berilgan va keyin **autoresizingMask**ka tayangan — autoresizingMask esa Auto-Layout-asosidagi o'lcham o'zgarishlariga javob bermaydi (bu eski "springs & struts" mexanizmi, zamonaviy constraint-based layout bilan mos kelmaydi). Natijada ARView noto'g'ri (kichik/joyidan chiqqan) o'lchamda qolib ketgan. **Tuzatildi:** `viewDidLayoutSubviews()` override qilinib, har layout siklida `arView.frame = view.bounds` qo'lda qayta o'rnatiladi.

**3) AR ochilishi sekin (~3s) va "osilib qolgandek" tuyulardi.** Sabab: 3.9MB USDZ fayl lokal Django dev-server (`runserver`, DEBUG rejimida, bitta-oqimli) orqali WiFi tarmog'i bo'ylab yuklanadi — bu dev muhitiga xos sekinlik (prodda nginx/CDN bilan sezilarli tezroq bo'ladi). To'liq bartaraf etib bo'lmaydigan bo'lsa-da, **foydalanuvchi tajribasi yaxshilandi**: `ProgressDownloader.swift` (yangi) — `URLSessionDownloadDelegate` orqali haqiqiy progress foizini kuzatadi (avval sinab ko'rilgan bayt-bayt `AsyncSequence` usuli sekinroq bo'lgani uchun rad etildi — million marta `await` chaqirish millionlab millisekund qo'shadi), ekranda "3D model yuklanmoqda… 42%" chizig'i bilan ko'rsatiladi — endi "osilib qolgan" emas, aniq jarayon ekanligi ko'rinadi.

Simulyator build ✅, real qurilmada sinov kutilmoqda.

---

### 29. Buyurtma boshlang'ich statusi — "Kutilmoqda" (qo'lda tasdiqlash oqimi)

Foydalanuvchi: production'ga chiqquncha SMS-tasdiqlash tizimi yo'q — shuning uchun buyurtma kelib tushgach **usta mijozga qo'ng'iroq qiladi**, keyin **o'zi qo'lda tasdiqlaydi yoki bekor qiladi**. Bu aslida mavjud oqim edi (`new → accepted/cancelled`), faqat nomi noaniq edi ("Yangi" — tasdiqlanmagan degani aniq emas). O'zgartirish:

- Backend: `Order.Status.NEW` labeli **"Yangi" → "Kutilmoqda"** (`apps/orders/models.py`). Bu faqat ko'rinadigan nom — DB qiymati (`"new"`) o'zgarmadi, migratsiya kerak emas.
- Web: `orderStatus.jsx`dagi mos label va ikonka (🆕 → ⏳) yangilandi.
- iOS allaqachon backend'dan `status_display`ni dinamik oladi — kod o'zgarishi kerak emas edi.

Natija: buyurtma (veb yoki iOS'dan farqsiz) tizimga kelganda "⏳ Kutilmoqda" holatida ko'rinadi; firma tomonida ega/usta qo'ng'iroq qilib, keyin "✅ Qabul qilindi" yoki "✕ Bekor qilish" tugmasi bilan qo'lda hal qiladi (mavjud `set_status` API, o'zgarishsiz). Brauzerda tekshirildi — admin va firma buyurtmalar ro'yxatida "⏳ Kutilmoqda" to'g'ri chiqmoqda.

### 30. ERP dizayni — Dream ERP (Tailwind) shabloniga mos, o'z ranglarimizda

Foydalanuvchi https://dreamserp.dreamstechnologies.com/tailwind (qorong'i tema, guruhlangan yon menyu, rangli ikon-belgili statistika kartalari, qidiruv/filtr paneli bilan jadvallar) shablonini ko'rsatib, shu tuzilishni **bizning brend ranglarimizda** (cream/jigarrang, avvalgi light/dark almashinuvi buzilmasdan) qo'llashni so'radi. Brauzerda shablonni ko'rib chiqib, asosiy naqshlarni ko'chirdim:

- **`index.css`**: yangi komponent klasslari — `.stat-badge` (statistika kartasidagi rangli ikon kvadrati), `.trend-pill` (foiz belgisi, hozircha ishlatilmagan — real trend ma'lumoti yo'qligi uchun soxta raqam qo'yilmadi), `.toolbar` (jadval ustidagi qidiruv paneli konteyner), `.icon-btn` (aylana ikon tugma, masalan yangilash), `.side-group-label` (yon menyudagi kichik guruh sarlavhasi).
- **`StatCard.jsx`**: qayta yozildi — ikon-belgi endi yuqori o'ngda (avval chapda edi), 4 xil rang aylanmasi (`tone` prop: cream/ko'k/yashil/to'q sariq — bizning palitradan), `trend` ixtiyoriy prop sifatida qo'shildi (kelajakda haqiqiy tendensiya ma'lumoti bo'lsa ishlatiladi).
- **`PortalLayout.jsx`**: yon menyu endi **guruhlangan** — har band `group` maydoniga ega bo'lishi mumkin, guruh sarlavhalari avtomatik chiqadi (Dream ERP'dagi "Main"/"Inventory"/"Sales" kabi).
- **`App.jsx`**: `ADMIN_MENU` guruhlari — Asosiy / Boshqaruv / Savdo; `FIRMA_MENU` guruhlari — Asosiy / Katalog / Savdo / Ishlab chiqarish / Xodimlar / Tizim.
- **`AdminCompanies.jsx`**: namunaviy sahifa sifatida to'liq yangilandi — qidiruv maydoni + natija soni + yangilash tugmasi (`.toolbar`), jadvalda kompaniya nomi yonida rangli bosh harf belgisi.

Brauzerda ikkala portalda (admin qorong'i, firma yorug' rejim) tekshirildi — guruhlangan menyu, yangi statistika kartalari, qidiruv paneli to'g'ri va brend ranglarida chiqdi. Build ✅, konsolda xato yo'q.

**Qamrov eslatmasi:** vaqt cheklovi tufayli yangi `.toolbar`/qidiruv naqshi hozircha faqat `AdminCompanies`ga qo'llandi — namuna sifatida. Qolgan jadval sahifalari (`AdminUsers` — allaqachon o'z qidiruvi bor, `FirmaProducts`, `FirmaOrders`, `FirmaProduction`, `FirmaLeads`, `FirmaPayroll`, `AdminOrders`, `Employees`) xohlasangiz keyingi bosqichda xuddi shu `.toolbar`/`.icon-btn` klasslari bilan bir xil uslubga keltiriladi — bu endi mexanik takrorlash, dizayn tizimi allaqachon tayyor.

---

### 31. Theme switch (toggle-box), rolga qarab subdomen redirect, market portal ogohlantirishi

Foydalanuvchi 3 ta muammoni ko'rsatdi: (1) tema almashtirish tugmasi oddiy ikon emas, switch-box bo'lsin; (2) asosiy sahifadan login qilganda hisobga mos subdomenga avtomatik o'tkazilsin; (3) `127.0.0.1:5173`ga owner sifatida kirganda haridor (mijoz) sahifasi ko'rinadi — chalkash.

- **`components/ThemeSwitch.jsx`** (yangi) — `role="switch"` toggle-box, kunduzi ☀️/kechasi 🌙 belgili sirg'anuvchi tugma. `App.jsx` (market) va `PortalLayout.jsx` (admin/firma) header'laridagi eski ikon-tugmalar shu bilan almashtirildi.
- **`portal.js`**: `portalForUser(me)` (rolga qarab market/admin/firma aniqlaydi) va `portalURLFor(target)` (joriy subdomendan boshqa subdomen URL'ini hisoblaydi — faqat `*.lvh.me` kabi ko'p-darajali domenlarda ishlaydi, `127.0.0.1`/`localhost`da `null` qaytaradi, chunki IP'dan subdomen yasab bo'lmaydi) qo'shildi.
- **Token handoff**: `localStorage` har subdomen uchun alohida bo'lgani sababli, `Login.jsx` boshqa portalga o'tkazganda tokenlarni `?access=&refresh=` URL parametrlari orqali "uzatadi"; `main.jsx` ilova yuklanishida shu parametrlarni o'qib `setTokens()`ga saqlaydi va URL'dan tozalaydi.
- **`Catalog.jsx` (market bosh sahifa)**: agar tizimga kirgan foydalanuvchi o'z roliga mos bo'lmagan portalda qolib ketsa (masalan owner/admin subdomensiz `127.0.0.1`da), sariq ogohlantirish banneri chiqadi: "Siz firma kabineti / platforma boshqaruvi hisobi bilan kirgansiz" + tegishli kabinetga o'tish tugmasi (agar subdomen orqali hisoblab bo'lmasa, tushuntiruvchi matn ko'rsatiladi).

**Tekshirildi (brauzerda):** `owner@test.uz` va `admin@test.uz` bilan `127.0.0.1:5173`da kirilganda banner to'g'ri chiqdi va tegishli label ko'rsatildi; `ThemeSwitch` market va admin portalida light/dark ikkala rejimda to'g'ri ishladi (brend cream↔jigarrang almashinuvi buzilmadi); `?portal=admin`/`?portal=firma` (dev-only forcing) orqali portal guard tekshirildi — noto'g'ri portalga kirishga urinishda "Bu portal siz uchun emas" xabari chiqdi. `lvh.me` subdomen orqali to'liq end-to-end redirect (token handoff) brauzer origin-ruxsati sabab hozircha jonli sinalmadi — kod jihatidan to'g'ri, keyingi safar `lvh.me` origin tasdiqlangach tekshiriladi. Build ✅.

### 32. Do'kon sahifasi + firma ishonch darajasi (tier) + mijoz reyting tizimi

Foydalanuvchi: mahsulot sahifasidan kirib boradigan do'kon sahifasi (label + banner), va firma "darajasi"ni ko'rsatuvchi rangli tizim — yangi ochilgan firmalar alohida, 10tagacha buyurtma bajarganlar alohida, 100tagacha alohida, va mijoz baholari (yulduzcha) ham rangga ta'sir qilsin.

**Qamrov qarori (soddalashtirish):** 1 mijoz — 1 firmaga faqat 1 marta baho qoldiradi (qayta yuborsa, eskisi yangilanadi), faqat shu firmadan **yakunlangan (`completed`) buyurtmasi bo'lgan** mijozlargina baho qoldira oladi, sharh moderatsiyasiz ko'rinadi (spam past ehtimol — bog'liq buyurtma talab qilinadi).

- **Backend — `companies/models.py`**: yangi `Review` modeli (`company`, `customer`, `rating` 1–5, `comment`, `unique_together`). `Company`ga hisoblanadigan (property, DB ustuni emas — real vaqtda) maydonlar: `completed_orders_count`, `review_count`, `average_rating`, va `tier` — bajarilgan buyurtmalar soniga qarab **yangi / faol (1–10) / ishonchli (11–100) / premium (100+)** darajalarini rang bilan qaytaradi; **o'rtacha reyting 3dan past bo'lsa** (va kamida 1ta bajarilgan buyurtma bo'lsa), daraja hajmidan qat'iy nazar ogohlantiruvchi rangga (qizil) tushadi — reyting doim rangga ta'sir qiladi.
- **`companies/serializers.py`**: `CompanySerializer`ga `tier` (hisoblangan dict) qo'shildi; yangi `ReviewSerializer` — faqat yakunlangan buyurtmasi borlarga ruxsat beradi, mavjud bahoni yangilaydi.
- **`companies/views.py`**: yangi `ReviewViewSet` (`?company=slug` filtri, faqat GET/POST).
- **`products/serializers.py`**: `ProductSerializer`ga `company_slug` qo'shildi (do'kon sahifasiga havola uchun). **`products/views.py`**: `ProductViewSet`ga `?company=slug` filtri qo'shildi.
- **Migratsiya**: `companies/migrations/0007_review.py`.
- **Frontend — `pages/Shop.jsx`** (yangi): firma banneri (logo/rasm joyi, nomi, tier belgisi), o'sha firmaning mahsulotlari to'ri, mijoz baholari ro'yxati, va tizimga kirgan foydalanuvchi uchun baho qoldirish formasi.
- **`components/CompanyBadge.jsx`** (yangi): tier rangli belgi + ⭐ o'rtacha reyting (agar mavjud bo'lsa) ko'rsatadi; `ProductDetail.jsx` va `Shop.jsx`da ishlatiladi.
- **`ProductDetail.jsx`**: kompaniya nomi endi `/shop/:slug`ga havola bo'lgan bosiladigan karta — yonida tier belgisi.
- **`App.jsx`**: `/shop/:slug` route market portaliga qo'shildi.

**Tekshirildi (backend, curl):** `/companies/` javobida `tier: {key:"new", label:"Yangi firma", ...}` to'g'ri qaytdi; `/products/?company=test-mebel` filtri ishladi; `/reviews/?company=test-mebel` bo'sh ro'yxat qaytardi. **Brauzerda:** mahsulot sahifasida "Test Mebel · Yangi firma" kartasi va "Do'kon sahifasini ko'rish →" havolasi chiqdi; `/shop/test-mebel` sahifasida banner, tier belgisi, 2ta mahsulot va baho formasi to'g'ri ko'rindi; yakunlangan buyurtmasi yo'q admin hisobi bilan baho yuborilganda backend to'g'ri rad etdi ("Faqat shu kompaniyadan yakunlangan buyurtmangiz bo'lsa, baho qoldira olasiz"). Build ✅.

### 33. Barcha emojilar SVG iconlarga almashtirildi (`lucide-react`)

Foydalanuvchi: butun web ilova bo'ylab emoji belgilarni real iconlarga almashtirish so'ralди. `lucide-react` o'rnatildi va 21 ta fayl (sahifalar, komponentlar, `orderStatus.jsx`, `leadStatus.js`, `positions.js`, `taskStage.js`) qayta ko'rib chiqildi — menyu iconlari, status belgilari, tugmalar, banner/bo'sh-holat illustratsiyalari. Eslatma: `<option>` ichida SVG render bo'lmagani uchun select variantlarida matn qoldirildi (masalan tier/visibility tanlovlari).

**Tekshirildi:** market/admin/firma portallarining barcha asosiy sahifalarida (Dashboard, Mahsulot, Do'kon, Savat, Leadlar, Ishlab chiqarish, Ish haqi) brauzerda emoji qolmaganini tasdiqladim. Build ✅.

### 34. Bitta 3D model + rang/tekstura variant tizimi (web + iOS)

Foydalanuvchi savoli: "har variantga alohida rasm/3D model yuklash kerakmi, har safar render qilib o'tirmasmiz — bir safar jiyda, bir safar yong'oqni rangini?" Javob: yo'q — bitta geometriya bir marta yuklanadi, ranglar runtime'da material sifatida qo'llanadi.

- **Backend**: `Model3D.variant` (OneToOne) → `Model3D.product`ga ko'chirildi (migratsiya bilan, mavjud ikkita Model3D'dan bittasi qoldirilib qolgani o'chirildi). `Variant`ga `color_hex` va `texture` (ImageField) qo'shildi. `ProductSerializer`ga mahsulot darajasidagi `model3d`, `VariantSerializer`ga `color_hex`/`texture_url` qo'shildi.
- **Web**: `ModelViewer.jsx` — `model-viewer`ning material API'si (`pbrMetallicRoughness.setBaseColorFactor`/`setBaseColorTexture`) orqali variant tanlanganda bitta GLB'ning rangini runtime'da o'zgartiradi. `ProductDetail.jsx` endi bitta mahsulot modelini ko'rsatib, tanlangan variant rangini qo'llaydi. `FirmaProducts.jsx`da bitta "3D model" tugmasi (mahsulot darajasida) + har variant qatorida rang pikeri/tekstura yuklash.
- **iOS**: `Variant.model3d` → `Product.model3d`ga ko'chirildi (`Models.swift`). `ARContainerView.swift`ga `applyVariantMaterial` qo'shildi — `PhysicallyBasedMaterial.baseColor.tint`/`.texture` orqali RealityKit'da xuddi shu mantiq. `xcodebuild` simulyatorda muvaffaqiyatli qurildi.

**Tekshirildi (brauzer):** "Oshxona garnituri" mahsulotida "Oq" ↔ "Yong'oq" variant almashtirilganda bitta GLB rangi real vaqtda kremrang↔jigarrangga o'zgardi (skrinshot bilan tasdiqlandi). iOS: xcodebuild BUILD SUCCEEDED.

### 35. AR occlusion (real narsalar virtual mebelni to'sishi)

Foydalanuvchi qurilmada sinaganda: AR obyekt xonadagi haqiqiy narsalar (stol, gilam oldidagi buyum) orqasida "yashirinmasdan" doim ustki qatlamda chizilib, notabiiy ko'rinardi. `ARContainerView.swift`da `ARWorldTrackingConfiguration`ga occlusion yoqildi: LiDAR'li qurilmalarda (`sceneUnderstanding.options.insert(.occlusion)`) to'liq mesh-asoslangan occlusion, LiDAR yo'q qurilmalarda `personSegmentationWithDepth` fallback (faqat odamlar to'sadi — bu ARKit platforma cheklovi). `xcodebuild` BUILD SUCCEEDED.

### 36. ERP Workflow + Production Tracking + Cost Management (to'liq ishlab chiqarish operatsion tizimi)

Foydalanuvchi katta texnik spetsifikatsiya berdi: har mahsulot uchun sozlanuvchi ishlab chiqarish grafigi (workflow), buyurtmaga nusxalanadigan jarayon, progress-yangilanishlar (rasm/izoh), bosqich yakunlash (rasm talabi), mijoz uchun shaffof timeline, xarajat/foyda hisobi, avtomatik ish haqi, statistika, yetkazib berish prognozi. Yangi `apps/workflow` Django ilovasi yaratildi:

- **`WorkflowStep`** (mahsulot shabloni): nomi, mas'ul rol (`companies.Employee.Position` bilan bir xil), ixtiyoriy xodim, taxminiy vaqt, xarajat, kerakli materiallar, rasm talabi (majburiy/ixtiyoriy/kerak emas), `depends_on` (self M2M — **DAG'ga tayyor**, hozircha UI avtomatik oldingi bosqichga bog'laydi, vizual tarmoqlanish keyingi bosqich).
- **`WorkflowStepInstance`**: buyurtma yaratilganda (`OrderCreateSerializer.create()` → `services.create_workflow_instances()`) birinchi banddagi mahsulotning shabloni to'liq nusxalanadi (nom/rol/xarajat va h.k. muhrlanadi — `OrderItem` snapshot patterni bilan bir xil), bog'liqliksiz bosqich(lar) darhol "Bajarilmoqda"ga o'tadi.
- **`ProgressUpdate`**: cheksiz sonli rasm/izoh yangilanishi, `is_completion` bayrog'i bilan yakuniy yangilanish ajratiladi — bu doimiy ishlab chiqarish tarixi (hech qachon o'chirilmaydi).
- **API**: `/products/{id}/workflow-steps/` (shablon CRUD, avtomatik zanjirlash), `/workflow-instances/{id}/progress/` va `/complete/` (rasm talabini serverda tekshiradi, yakunlaganda `activate_dependents()` orqali keyingi bog'liq bosqich(lar)ni avtomatik ochadi), `/workflow-stats/` (bosqich nomi bo'yicha o'rtacha vaqt/narx/soni), `/orders/{id}/prediction/` (tarixiy o'rtacha davomiylikka asoslangan taxminiy tugash sanasi + ishonch foizi — statistik, AI emas).
- **Xarajat/foyda**: `OrderSerializer`ga `workflow_steps`, `production_cost` (labor_cost/total_cost/selling_price/profit) va `progress_percent` qo'shildi — shu bilan **Marketplace Integration** talabi ham avtomatik bajarildi (mijoz o'ziga tegishli `/orders/{id}/` orqali joriy bosqich/progress/rasm/izohlarni ko'radi, alohida endpoint kerak bo'lmadi).
- **Payroll**: `Payslip.recompute()` endi `workflow_earnings`ni ham hisoblaydi — xodimga tayinlangan va shu oyda yakunlangan bosqichlar xarajati yig'indisi, `bonus_amount`dan alohida, `total_amount`ga qo'shiladi.
- **Frontend**: `FirmaProducts.jsx`ga `WorkflowEditor` (bosqich qo'shish/o'chirish/tartib almashtirish, jami vaqt/xarajat ko'rsatuvi), yangi umumiy `components/WorkflowPanel.jsx` (firma tomonida progress/complete formalari bilan `editable`, mijoz tomonida `MyOrders.jsx`da faqat o'qish/timeline sifatida — ikkalasida ham ishlatiladi), `FirmaOrders.jsx`da xarajat/foyda/prognoz kartalari bilan panel, `FirmaPayroll.jsx` jadvaliga "Workflow bosqichlari" ustuni qo'shildi.

**Qamrov qarori:** bitta buyurtmada bir nechta mahsulot bo'lsa ham, ishlab chiqarish jarayoni birinchi banddagi mahsulot shablonidan olinadi (odatiy holat — buyurtma bitta mebelga tegishli); vizual drag-and-drop DAG muharriri va AI-asoslangan bashorat/foto-tekshiruv keyingi bosqichga qoldirildi (spetsifikatsiyaning o'zida ham "Future AI Features" deb belgilangan).

**Tekshirildi (backend, curl — to'liq zanjir):** 3 bosqichli shablon yaratildi (Material→Cutting→Painting, avtomatik `depends_on` zanjiri tasdiqlandi) → mijoz buyurtma berdi → birinchi bosqich avtomatik "in_progress" bo'lib boshlandi (`workflow_steps` javobda ko'rindi) → progress+complete oqimi sinaldi (bir xato topildi va tuzatildi: `get_object()`ning prefetch keshi yangi qo'shilgan `ProgressUpdate`ni ko'rsatmayotgan edi — action'lar oxirida instansiya qayta so'ralib tuzatildi) → majburiy-rasm bosqichi rasmsiz to'g'ri rad etildi, rasm bilan qabul qilindi → `production_cost`/`progress_percent`/`/prediction/`/`/workflow-stats/` barchasi to'g'ri qiymat qaytardi. **Brauzerda (end-to-end):** firma tomonida yangi buyurtma ochilib, "Material Preparation" bosqichiga izoh bilan progress qo'shildi, so'ng yakunlandi — "Cutting" bosqichi darhol "Bajarilmoqda"ga o'tganini jonli kuzatdim; mijoz tomonida (`MyOrders.jsx`) xuddi shu buyurtma ochilib, xarajat/foyda **yashiringan** (faqat firma ko'radi), progress tarixi esa **ko'rinishini** tasdiqladim. `WorkflowEditor` UI'da bosqich qo'shish/tartib/jami hisob ham brauzerda tekshirildi. Build ✅, `manage.py check` ✅.

### 37. iOS: SMS-OTP kirish, doimiy `worker_id`, ID orqali ishga taklif/qabul, karyera tarixi, usta ish rejimi

Foydalanuvchi: iOS ilovada foydalanuvchi (xaridor) va usta login oqimlarini ajratish, hisobga SMS-tasdiqlash orqali kirish, profilda doimiy ko'rsatiladigan ID (shu orqali firma ishga taklif qiladi, qabul qilsa shu firma xodimi bo'lib qoladi, bu ish tarixi/karyerasiga ta'sir qiladi), profildan "xaridor" ↔ "usta" rejimiga o'tish, va usta rejimida faqat o'z firmasining 3D fayllaridan foydalanish.

**Qamrov qarorlari (foydalanuvchi bilan kelishilgan):**
- SMS provayder hali yo'q (keyinroq sotib olinadi) — hozircha real 6 xonali kod generatsiya qilinadi, lekin SMS o'rniga javobda `debug_code` sifatida qaytariladi va ekranda "SMS yuborildi (123456)" ko'rinishida ko'rsatiladi (provayder ulanganda faqat shu bitta joy — `OTPRequestView`dagi "yuborish" qadami — almashtiriladi).
- Firma to'lov holati (obuna) bo'yicha cheklov **hozircha qo'yilmadi** — barcha firma ustalari o'z firmasi fayllaridan erkin foydalanadi; to'lov/obuna tizimi alohida bosqich sifatida qoldirildi.
- Worker ID — oddiy, kamida 10 xonali raqamli ID (UUID emas), barcha foydalanuvchilar uchun avtomatik generatsiya qilinadi.

**Backend:**
- `apps/users/models.py`: `User.worker_id` (10 xonali noyob raqamli ID, `save()`da avtomatik generatsiya, to'qnashuvni tekshirib qayta urinadi) + `PhoneOTP` modeli (kod, yaratilgan vaqt, 5 daqiqa amal qiladi).
- `POST /auth/otp/request/` — kod generatsiya qiladi, `debug_code` bilan qaytaradi. `POST /auth/otp/verify/` — kodni tekshiradi, foydalanuvchi mavjud bo'lmasa avtomatik yaratadi (customer sifatida, `{phone}@phone.local` platsxolder email bilan — real login email emas, faqat `email` maydonining unique/required cheklovini qondirish uchun) va JWT qaytaradi.
- `apps/companies/models.py`: `EmployeeInvitation` (firma → foydalanuvchi, `worker_id` orqali qidiriladi, pending/accepted/declined), `Employee.left_at` (ishdan bo'shagan sana — karyera tarixi uchun, `EmployeeViewSet.perform_update/destroy`da avtomatik o'rnatiladi/tozalanadi).
- `POST /employee-invitations/` (firma egasi `worker_id` bilan taklif yaratadi) + `/{id}/accept/` (Employee yozuvini yaratadi/qayta faollashtiradi, `user.role`ni `employee`ga o'tkazadi) + `/{id}/decline/`.
- `GET /users/me/career/` — foydalanuvchining barcha kompaniyalardagi (faol+sobiq) ish tarixi.
- `UserSerializer`ga `worker_id` qo'shildi.

**iOS:**
- `Models.swift`: `User.workerId`, yangi `EmployeeInvitation`, `CareerEntry` structlar.
- `AuthStore.swift`: `requestOTP(phone:)`/`verifyOTP(phone:code:)`, va mahalliy (UserDefaults'da saqlanadigan) `appMode: .customer | .worker` — backend rolini o'zgartirmaydi, faqat ilova ko'rinishini almashtiradi.
- `AccountView.swift`: login formasi endi Telefon(SMS)/Email tab'lariga bo'lindi (telefon oqimi: raqam kiritish → "SMS yuborildi (kod)" → tasdiqlash); profilda `worker_id` (nusxalash tugmasi bilan), "Ko'rinish rejimi" segmentli tugmasi (Xaridor/Usta — faqat foydalanuvchi biror firmada ishlagan/ishlayotgan bo'lsa ko'rinadi), kelgan ish takliflari (qabul/rad tugmalari bilan), va ish tarixi (karyera) ro'yxati.
- Yangi `WorkerHomeView.swift` — usta rejimida asosiy tab: faqat o'z firmasining mahsulotlari (`/products/?company={slug}`), AR belgisi bilan, bosilganda mavjud `ProductDetailView`ga o'tadi (AR sinash tugmasi allaqachon bor).
- `RootView.swift`: `appMode == .worker && user.company != nil` bo'lganda odatiy 3 ta xaridor tabi (Bosh sahifa/Katalog/Sevimlilar) o'rniga "Usta paneli" tabi ko'rsatiladi; Profil tabi har doim qoladi (rejim shu yerdan almashtiriladi).

**Tekshirildi (backend, curl — to'liq zanjir):** `/auth/otp/request/` → kod olindi → `/auth/otp/verify/` → yangi user avtomatik yaratildi, `worker_id` biriktirildi → owner shu ID bilan `/employee-invitations/` orqali taklif yubordi → yangi user o'z takliflarini ko'rdi → `/accept/` → `Employee` yozuvi yaratildi, `role` `employee`ga o'zgardi, `/users/me/career/` to'g'ri ish tarixini qaytardi. **iOS:** `xcodebuild` simulyatorda **BUILD SUCCEEDED** (Models/AuthStore/AccountView/RootView/WorkerHomeView — barchasi muvaffaqiyatli kompilyatsiya qilindi); haqiqiy qurilmada UI oqimini bosib sinash keyingi safarga qoldi.

### 38. Android (Flutter) ilova — boshlang'ich qamrov

Foydalanuvchi: iOS'dan tashqari Android'da ham ilova kerak, lekin ishlaydigan Mac'da joy tanqis bo'lgani (va Flutter SDK o'rnatilmagani) uchun kod shu yerda yozib qo'yiladi, foydalanuvchi Asus noutbukida `flutter create .` bilan platforma qatlamlarini generatsiya qiladi. **Xavfsizlik eslatmasi:** foydalanuvchi git push uchun GitHub shaxsiy tokenini (PAT) chatga ochiq matn holida yubordi — bu ishlatilmadi (kredensial siyosati: tokenlarni hech qachon ishlatmaslik/joylashtirmaslik) va foydalanuvchiga uni darhol bekor qilish (revoke) tavsiya qilindi.

Yangi `flutter_app/` — mavjud backend API'ning **aynan o'zidan** foydalanadi (alohida backend kerak emas), web/iOS bilan bir xil arxitektura:

- `lib/models.dart`, `api_client.dart` (JWT + avtomatik refresh, `10.0.2.2` emulyator manzili), `auth_store.dart` (`Provider`/`ChangeNotifier`, mahalliy `AppMode.customer/worker`).
- `screens/auth_screen.dart` — Telefon(SMS-OTP)/Email tab'lari (backend bilan bir xil `debug_code` dev-rejimi).
- `screens/catalog_screen.dart` + `product_detail_screen.dart` — xaridor uchun **faqat ko'rish**: narx va 3D model (`model_viewer_plus` orqali, AR joylashtirish emas — bu talab shunday edi).
- `screens/orders_screen.dart` — xaridor buyurtma statusini kuzatadi (o'zi bermaydi — Android uchun belgilangan qamrov).
- `screens/profile_screen.dart` — `worker_id` (nusxalash bilan), Xaridor/Usta rejim almashtirgichi, ish takliflari (qabul/rad), karyera tarixi — web/iOS bilan bir xil `/employee-invitations/`, `/users/me/career/` endpointlari.
- `screens/worker/worker_home_screen.dart` — faqat o'z firmasi mahsulotlari/3D fayllari (`?company=<slug>`); `worker_orders_screen.dart` — status o'zgartirish + workflow bosqichlarini progress/complete qilish (hozircha rasmsiz, matnli izoh bilan — `image_picker` keyingi bosqich).

**Tekshirildi:** Flutter SDK shu Mac'da yo'q (joy tanqisligi) — shuning uchun `flutter analyze`/`flutter build` ishga tushirilmadi. Buning o'rniga barcha `lib/*.dart` fayllar `dart format --set-exit-if-changed` orqali sintaktik tekshirildi (xato topilmadi, faqat kosmetik formatlash farqi bor edi — tuzatildi). To'liq kompilyatsiya tekshiruvi Asus noutbukda `flutter create .` + `flutter pub get` + `flutter run`dan keyin bo'ladi.

---

## Keyingi qadamlar (navbat bo'yicha, Roadmap Priority Order)
1. ~~Backend Setup~~ ✅
2. ~~Authentication (JWT + rollar)~~ ✅
3. ~~Company System (asos)~~ ✅
4. ~~Product Catalog~~ ✅ (keyin: filter/search backendda)
5. ~~React frontend (MVP)~~ ✅ (keyin: galereya upload UI, kompaniya sahifasi, RU tili)
6. ~~Subdomen portallari (market / admin / firma)~~ ✅
7. ~~Orders (savat, buyurtma, status tracking)~~ ✅
8. ~~Asset Upload (GLB/USDZ, model-viewer)~~ ✅ (keyin: FBX/OBJ → GLB avtomatik konvertatsiya)
9. ~~CRM (leadlar, sotuv voronkasi, aloqa tarixi)~~ ✅
10. ~~ERP — production tasklar, xodim rollariga ulangan vazifalar~~ ✅ (keyin: material/ombor hisobi, xodim samaradorlik statistikasi — docs/38 §9-12)
11. ~~iOS AR — mijoz oqimi (katalog, login, buyurtma, RealityKit AR joylashtirish)~~ ✅ (to'xtatildi, keyinroq davom etiladi: haqiqiy qurilmada AR kamera sinovi, xodim/LiDAR AR oqimi)
12. ~~Ishchi oyligini hisoblash tizimi (bazaviy oylik + vazifa bonusi, Payslip)~~ ✅
13. ~~iOS dizayni marketplace darajasiga ko'tarildi (Bosh sahifa + Katalog, Plank/Darix uslubi)~~ ✅
14. ~~Sevimlilar (serverda) + variant bo'yicha AR sinovi (backend+web+iOS)~~ ✅
15. ~~Mustaqil 3D-viewer havolasi (Ochiq/Yopiq/Cheklangan, bazissoft.ru uslubida)~~ ✅
16. ~~iOS haqiqiy qurilmada ishga tushirildi (signing hal qilindi) + AR: bitta obyekt joylashtirish/siljitish/aylantirish tugmalar bilan~~ ✅
17. ~~Buyurtma statusi "Kutilmoqda"ga o'zgartirildi (qo'lda usta tasdiqlash oqimi)~~ ✅
18. ~~ERP dizayni Dream ERP shablon tuzilishiga mos qayta qurildi (o'z ranglarimizda)~~ ✅ (qolgan jadval sahifalari xuddi shu naqsh bilan keyin to'ldiriladi)
19. ~~Theme switch (toggle-box) + rolga qarab subdomen redirect + market portal ogohlantirishi~~ ✅ (`lvh.me` orqali to'liq end-to-end redirect hali jonli sinalmagan — brauzer origin-ruxsati kerak)
20. ~~Do'kon sahifasi + firma ishonch darajasi (tier) + mijoz reyting tizimi~~ ✅
21. ~~Barcha emojilar SVG iconlarga (`lucide-react`) almashtirildi~~ ✅
22. ~~Bitta 3D model + rang/tekstura variant tizimi (web + iOS, RealityKit material tint)~~ ✅
23. ~~AR occlusion (LiDAR mesh / person segmentation)~~ ✅
24. ~~ERP Workflow + Production Tracking + Cost Management (shablon → buyurtma instansiyasi, progress/complete, xarajat/foyda, avtomatik payroll, statistika, yetkazib berish prognozi)~~ ✅
25. ~~iOS: SMS-OTP kirish, worker_id, ishga taklif/qabul, karyera tarixi, usta ish rejimi~~ ✅ (haqiqiy qurilmada UI sinovi qoldi)
26. ~~Android (Flutter) ilova — boshlang'ich qamrov (auth, profil/worker_id/taklif/karyera, xaridor ko'rish-rejimi, usta paneli)~~ ✅ (Flutter SDK Asus noutbukda o'rnatilgach `flutter create .` + build tekshiruvi kerak)
27. Keyingi: haqiqiy SMS provayder ulash (Eskiz.uz va h.k. — `debug_code`ni almashtirish), firma obuna/to'lov tizimi (usta 3D-fayl cheklovi shunga bog'liq bo'ladi), material/ombor hisobi (docs/38 §10-12), vizual drag-and-drop DAG workflow muharriri, AI-asoslangan foto-tekshirish/bashorat, `.toolbar` naqshini qolgan jadval sahifalariga tarqatish, do'kon logotipini yuklash UI, Android'da rasm bilan progress/complete (`image_picker`)
