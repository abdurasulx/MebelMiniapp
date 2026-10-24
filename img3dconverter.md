# Rasm va o‘lchamlardan 3D model yaratish: mobil integratsiya

Sana: 2026-10-24. Loyiha: MebelMiniapp / VIDA Market.

Bu hujjat Ubuntu’dagi mavjud konvertorni iOS va keyinchalik Android ilovasiga
ulash uchun texnik spetsifikatsiya. **Mobil integratsiya hali amalga oshirilmagan.**
Quyida mavjud imkoniyatlar va taklif qilinayotgan yangi API alohida ko‘rsatilgan.

**Natija formati: faqat GLB. USDZ yaratish yoki kutish talab qilinmaydi.**
Ushbu ishning qamrovi: rasm yuklash, doimiy navbat, bosqichma-bosqich progress,
GLB olish va uni ilovaning model ko‘rish oqimiga uzatish. Bu hujjatning o‘zi
iOS’dagi mavjud native AR renderer GLB’ni bevosita qabul qilishini kafolatlamaydi;
mos rendererga uzatish alohida tekshiriladi. AR tugmasini avtomatik yoqish qamrovga kirmaydi.

## 1. Tekshirilgan mavjud servis

Ubuntu: `100.90.116.106`, loyiha: `/home/banda/Desktop/imageto3d`.
Flask servis: `http://100.90.116.106:5000`.

Asosiy fayllar:

- `app.py`: HTTP API, HTML interfeys, navbat va generatsiya worker’i.
- `scale_model.py`: GLB’ni haqiqiy balandlikka masshtablash va polga qo‘yish.
- `estimate_height.py`: CLIP orqali mebel turi va odatiy balandlikni taxmin qilish.
- `test_scale_model.py`: masshtab, proporsiya, tekstura va o‘lcham farqi testlari.
- `3dfiles/<collection>/<name>.glb`: tayyor fayllar.

Bir rasm uchun `tencent/Hunyuan3D-2.1`, ko‘p rasm uchun
`tencent/Hunyuan3D-2mv` ishlatiladi. Tekstura uchun Hunyuan3D Paint va PBR
materiallari qo‘llanadi. GPU: RTX 4070 Ti, 12 GB VRAM. Bitta worker ishlarni
ketma-ket bajaradi; HTTP `threaded=True` bo‘lishi parallel GPU generatsiyasi degani emas.

### Hozirgi endpointlar

| So‘rov | Vazifa |
|---|---|
| `GET /api/collections` | Kolleksiya nomlari |
| `POST /api/convert` | Rasm(lar)ni qabul qilib navbatga qo‘yish |
| `GET /api/jobs?client=<client_id>` | Shu client identifikatoriga tegishli oxirgi 50 ish |
| `GET /files/<collection>/<filename>` | Tayyor GLB fayli |

`POST /api/convert` — `multipart/form-data`:

| Maydon | Mavjud ma’nosi |
|---|---|
| `image` | Takrorlanadigan maydon, 1–4 ta rasm |
| `roles` | Rasm tartibiga mos `front,back,left,right`; har rol bir marta |
| `collection` | Majburiy kolleksiya nomi |
| `client` | Brauzer yaratadigan identifikator; autentifikatsiya emas |
| `height_cm` | Balandlik, sm; bo‘sh bo‘lsa avtomatik taxmin |
| `width_cm`, `depth_cm` | En va chuqurlik, sm; nazorat uchun |
| `remove_bg` | `1` yoki `0`, standart `1` |
| `textured` | `1` yoki `0`, standart `1` |

Bir rasm avtomatik `front` hisoblanadi. Bir nechta rasmda `front` majburiy.
Mavjud javobda `id`, `name`, `collection`, `status`, `stage`, `percent`,
`position`, `textured`, `n_images`, `error`, `result` bor. Statuslar:
`queued`, `running`, `done`, `error`. Qabul qilish hozir `200` qaytaradi.
Job’ni ID bo‘yicha olish, bekor qilish va idempotency endpointlari hozir yo‘q.

Mavjud `result` maydonlari: `file`, `path`, `url`, `note`, `dims`, `auto_height`.
`dims`: `scale`, `width_cm`, `height_cm`, `depth_cm`, `volume_m3`,
`dimension_mismatch`. Fayl URL’i hozir nisbiy manzil.

### Hozirgi cheklovlar

- `JOBS`, `WAITING`, `JOB_QUEUE` va yuklangan rasm baytlari faqat RAM’da.
  Servis qayta ishga tushsa, navbat va job tarixi yo‘qoladi; tayyor GLB diskda qoladi.
- Har so‘rov Tailscale IP va `tailscale whois` orqali belgilangan egaga tekshiriladi.
  Mobil qurilmadan internet orqali to‘g‘ridan-to‘g‘ri foydalanish uchun bu yetarli emas.
- `client` qiymatini bilish ishlar egasi ekanini isbotlamaydi.
- Progressning bir qismi vaqtga qarab taxminiy; bosqich o‘zgarganda qiymat pasayishi mumkin.
- Fayl hajmi, navbat sig‘imi va job tarixini tozalash uchun aniq limitlar belgilanmagan.
- Tekstura xatosida geometriya GLB sifatida saqlanadi, ogohlantirish `note`ga yoziladi.

## 2. Mobil integratsiya arxitekturasi

```text
iOS / Android
    | HTTPS + mavjud VIDA JWT
    v
VIDA Django API /api/v1/image-to-3d/jobs/
    | job, egasi, fayllar va progress — DB + doimiy storage
    | ichki autentifikatsiya + Tailscale
    v
Ubuntu konvertor / GPU worker
    | bitta faol generatsiya
    v
GLB tekshirish -> VIDA media/storage -> mobil ilovaga HTTPS URL
```

Mobil ilova Ubuntu IP’siga yoki AI Collections API kalitlariga bog‘lanmaydi.
Ilovaning mavjud VIDA API bazasi ishlatiladi; `api.ai.burchaksoft.uz` alohida
AI Gateway loyihasi bo‘lib, ushbu integratsiyada avtomatik public endpoint hisoblanmaydi.

VIDA backend JWT’ni tekshiradi, foydalanuvchi/kompaniya egaligini belgilaydi va
ichki servisga alohida server kaliti bilan ulanadi. Ushbu kalit ilovaga kiritilmaydi.
Konvertorning browser uchun owner tekshiruvini global o‘chirish o‘rniga, backend
uchun alohida autentifikatsiyalangan ichki API yaratiladi. Faqat Tailscale IP yoki
`X-Forwarded-For` headeriga qarab ishonch berilmaydi.

## 3. Rasm va navbatni yo‘qotmasdan saqlash

Quyidagilar **yangi implementatsiya talablari**, mavjud servisda hali yo‘q:

1. Har job uchun server UUID yaratadi. Rasm fayllari foydalanuvchi nomi bilan
   emas, UUID asosidagi alohida katalog/storage prefiksiga yoziladi.
2. Yuklash avval vaqtinchalik faylga yoziladi, tekshiriladi va atomik yakunlanadi.
   Barcha rasmlar saqlanmaguncha job `queued` bo‘lmaydi.
3. Job yozuvi va navbatga chiqarish outbox yoki DB’dan qayta skan qilinadigan
   mexanizm bilan bog‘lanadi. DB commit va broker xabari orasida ish yo‘qolmaydi.
4. DB — asosiy haqiqat manbasi. Broker ishlatilsa, u yagona navbat nusxasi bo‘lmaydi.
5. GPU worker faqat bitta ishni atomik lease/claim bilan oladi. Heartbeat,
   `lease_expires_at`, `attempt` va maksimal urinishlar saqlanadi.
6. Worker uzilib qolsa, muddati o‘tgan lease qayta ko‘rib chiqiladi.
   Tugallanmagan ish checkpoint bo‘lmasa boshidan qayta bajariladi; 60% dan
   aynan davom etayotgandek ko‘rsatilmaydi.
7. Qayta urinishga `attempt` oshiriladi. Oldingi urinish progressi tarixda qoladi;
   yangi urinish progressi alohida boshlanadi.
8. Bir job qayta yuborilganda ikkita faol generatsiya yoki ikkita natija yaratilmaydi.
9. GLB vaqtinchalik nomga yozilib, validatsiyadan keyin yakuniy nomga o‘tkaziladi.
   Backend natijani qabul qilib saqlaganidan keyingina worker ishni yakunlangan deb tasdiqlaydi.
10. Rasmlar/natijalarni saqlash muddati konfiguratsiyada belgilanadi. Kutilayotgan
    yoki ishlayotgan job fayllari avtomatik tozalanmaydi; tozalash orphan fayllarni ham hisobga oladi.

Job yozuvi uchun minimal maydonlar:

`id`, `user_id`, `company_id`, `product_id/variant_id` (ixtiyoriy), `status`,
`stage_code`, `stage_progress`, `overall_progress`, `progress_kind`, `attempt`,
`stage_attempt`, `revision`, `created_at`, `updated_at`, `started_at`, `finished_at`,
`lease_expires_at`, `input_files`, `input_dimensions`, `options`, `warnings`,
`error_code`, `result_file`, `result_dimensions`, `idempotency_key`.

`input_files` har rasm uchun storage key, rol, format, hajm va checksum saqlaydi.
DB yozuvi doim foydalanuvchiga bog‘lanadi. Navbat o‘rni serverdan hisoblanadi va
aktiv GPU ishini hisobga olmasdan kutayotganlar ichidagi 1 dan boshlanuvchi o‘rin bo‘ladi.

## 4. Taklif etilayotgan public API

Bu endpointlar **hali mavjud emas**; ular VIDA Django backendiga qo‘shiladi.
Hammasi `Authorization: Bearer <VIDA access token>` talab qiladi.

| So‘rov | Natija |
|---|---|
| `POST /api/v1/image-to-3d/jobs/` | Rasm va parametrlarni saqlab job yaratish, `202 Accepted` |
| `GET /api/v1/image-to-3d/jobs/` | Faqat ruxsat berilgan job’lar, sahifalash bilan |
| `GET /api/v1/image-to-3d/jobs/<uuid>/` | Status, navbat o‘rni, progress, natija |
| `POST /api/v1/image-to-3d/jobs/<uuid>/retry/` | Xatoga tushgan job’ni mavjud rasmlar bilan qayta navbatga qo‘yish |

Yaratish formasi mavjud `image`, `roles`, `height_cm`, `width_cm`, `depth_cm`,
`remove_bg`, `textured` maydonlarini saqlaydi. `product_id` yoki `variant_id`
ixtiyoriy; ikkalasi birga berilmaydi va kompaniya ruxsati tekshiriladi.
`collection` ixtiyoriy guruhlash nomi; fayl yo‘li sifatida qabul qilinmaydi.
`client`, `user_id`, `company_id` orqali egalikni klient belgilamaydi.

`Idempotency-Key` klientda bir marta yaratiladi va shu upload qayta urinishlarida
saqlanadi. Bir foydalanuvchi va bir xil kalit bilan parallel so‘rovlar bitta job
qaytaradi. Kalitga boshqa rasm/parametr yuborilsa `409` qaytariladi. Multipart
boundary o‘rniga fayl checksumlari va normallashtirilgan parametrlar solishtiriladi.

Taklif etilgan job javobi (UTC vaqtlar, o‘lchamlar sm):

```json
{
  "id": "7b8d291a-833d-4d5a-8f58-c38db518f2b6",
  "status": "running",
  "stage_code": "geometry",
  "stage_progress": 42,
  "overall_progress": 18,
  "progress_kind": "measured",
  "queue_position": null,
  "attempt": 1,
  "stage_attempt": 1,
  "revision": 12,
  "created_at": "2026-10-24T10:00:00Z",
  "updated_at": "2026-10-24T10:00:35Z",
  "poll_after_seconds": 3,
  "warnings": [],
  "error": null,
  "result": null
}
```

Statuslar: `queued`, `running`, `succeeded`, `failed`.
`queued` holatida `queue_position` son; qolgan holatlarda `null`.
Yakuniy `succeeded` javobida `overall_progress=100` va `result` mavjud bo‘ladi:

```json
{
  "format": "glb",
  "glb_url": "https://api.vidamarket.uz/media/assets/glb/example.glb",
  "width_cm": 64.0,
  "height_cm": 120.0,
  "depth_cm": 68.0,
  "bbox_volume_m3": 0.522,
  "height_source": "user",
  "textured": true,
  "dimension_mismatch": false,
  "model3d_id": null
}
```

URL namuna; haqiqiy host mavjud VIDA media/storage sozlamasidan olinadi.
Yopiq faylda egaga ruxsatli download endpoint yoki muddati cheklangan URL
ishlatiladi; URL’ning amal muddati javobda alohida beriladi va yangilanishi mumkin.
Konvertorning lokal `path` qiymati mobil API’da oshkor qilinmaydi.

Xatolar: `400` noto‘g‘ri parametr, `401` sessiya, `403/404` ruxsat,
`409` idempotency/status konflikti, `413` fayl limiti, `429` navbat/foydalanuvchi
limiti, `503` xizmat mavjud emas. GPU’dagi xato job’da `failed` bo‘lib saqlanadi;
`error.code` va lokalizatsiya qilinadigan xabar bor, traceback qaytarilmaydi.

Backendda cheklangan fayl soni/hajmi, o‘qiladigan formatlar va rasm pixel limiti
konfiguratsiya bilan belgilanadi. HEIC qabul qilinsa server konvertatsiyasi kerak;
aks holda iOS yuborishdan oldin JPEG/PNG tayyorlaydi. O‘lchamlar chekli musbat son
bo‘lishi shart (`NaN` va `Infinity` rad etiladi). Yuklash limiti va navbat sig‘imi
amalga oshirishda belgilanadi, iOS’ga mos xato kodi bilan qaytariladi.

## 5. Jarayon bosqichlari va progress

UI serverdagi o‘zbekcha `stage` matnini mantiqiy kalit sifatida ishlatmaydi.
Server barqaror `stage_code` beradi, mobil ilova o‘z tiliga tarjima qiladi.

| `stage_code` | iOS’da ko‘rsatiladigan mazmun |
|---|---|
| `queued` | Navbatda, oldingizda N ta ish |
| `background_removal` | Orqa fon tozalanmoqda |
| `height_estimation` | O‘lcham taxmin qilinmoqda |
| `model_loading` | 3D modeli tayyorlanmoqda |
| `geometry` | Obyekt shakli yaratilmoqda |
| `mesh_cleanup` | Geometriya tozalanmoqda |
| `texture_loading` | Tekstura modeli yuklanmoqda |
| `texturing` | Rang va material yaratilmoqda |
| `glb_export` | GLB saqlanmoqda |
| `scaling` | Haqiqiy o‘lchamga moslanmoqda |
| `publishing` | Natija yuklab olishga tayyorlanmoqda |
| `completed` | Tayyor |
| `failed` | Yaratib bo‘lmadi |

Ixtiyoriy bosqichlar o‘tkazib yuboriladi. `geometry`da model callback’idan haqiqiy
qadamlar ulushi olinadi. Callback yo‘q bosqichlarda `estimated` yoki
`indeterminate` ko‘rsatiladi; taxminiy foiz aniq o‘lchov deb taqdim etilmaydi.

Bir xil `attempt` ichida `overall_progress` pasaymaydi, tayyor fayl nashr
etilmaguncha 100 bo‘lmaydi. Bosqich og‘irliklari teksturali/teksturasiz va
bir/ko‘p rasmli rejim uchun alohida belgilanadi. `revision` har yangilanishda
oshadi; eski HTTP javobi yangi progressni orqaga qaytarmaydi. Foiz va bosqich
bir DB yangilanishida saqlanadi. Vaqtga bog‘liq progress ham server snapshot’ida
yangilanadi; har GET’da nazoratsiz boshqa qiymat chiqarilmaydi.

Tekstura muvaffaqiyatsiz, ammo GLB geometriya yaroqli bo‘lsa:
`succeeded`, `result.textured=false`, `warnings=[{"code":"texture_failed"}]`.
UI ogohlantirishni yashirmaydi. Masshtab qo‘llanmasa ham shunga o‘xshash
`scale_failed` ogohlantirishi va `height_source`/o‘lchamlarning haqiqiy holati beriladi.

## 6. iOS oqimi

1. Foydalanuvchi 1–4 rasm va rollarni tanlaydi, o‘lchamlarni kiritadi.
2. Upload boshlanishidan oldin rasmlar va so‘rov parametrlari ilovaning doimiy
   katalogiga yoziladi; faqat Photos picker’ning vaqtinchalik URL’iga tayanilmaydi.
3. Multipart body disk fayli sifatida tayyorlanadi. `URLSession` upload progressi
   alohida **“Rasmlar yuklanmoqda”** deb ko‘rsatiladi; u GPU generatsiya foizi emas.
4. `202`dan keyin job ID, idempotency key va so‘rov holati diskka saqlanadi.
   Server qabul qilgan job uchun original rasmlarni retention qoidasiga muvofiq tozalash mumkin.
5. Aktiv ekranda `poll_after_seconds` bo‘yicha polling qilinadi (boshlang‘ich 3 s).
   Polling so‘rovlari ustma-ust yuborilmaydi; xatoda backoff bilan qayta uriniladi.
6. Ilova yopilishi/navbat ekranidan chiqish server job’ini bekor qilmaydi.
   Fon rejimida doimiy polling kafolatlanmaydi; qayta ochilganda saqlangan ID
   yoki job ro‘yxati orqali joriy holat olinadi.
7. Internet uzilsa “Ulanish kutilmoqda” ko‘rsatiladi; job server javobisiz
   `failed` deb belgilanmaydi va takroriy generatsiya yaratilmaydi.
8. JWT yangilanishi mavjud `APIClient` mexanizmi orqali bajariladi. Logoutda
   mahalliy job ma’lumotlari boshqa hisobga ko‘rsatilmaydi; serverdagi ish davom etadi.
9. `succeeded`dan keyin GLB yuklab olinadi, keshga atomik saqlanadi va model
   ko‘rish oqimiga uzatiladi. URL muddati tugasa job’dan yangisi olinadi.
10. `failed` holatida foydalanuvchi qayta urinishni tanlay oladi; eski job va
    urinishlar tarixi saqlanadi. Avtomatik retry soni cheklangan bo‘ladi.

`URLSessionConfiguration.background` upload ilova fonida qolsa davom etishga
yordam beradi, ammo foydalanuvchi ilovani majburan yopsa iOS uni kafolatlamaydi.
Qayta ochilganda sessiya tasklari va server job’i tekshiriladi. Fon upload
uchun multipart body fayli va task identifikatori saqlanadi. APNs/FCM orqali
“3D tayyor” bildirishnomasi keyingi bosqich; bildirishnoma job holatining o‘rnini bosmaydi.

Tavsiya etilgan iOS qismlari: `ImageTo3DJob` (Codable), `ImageTo3DStore`
(@MainActor ObservableObject), upload servisi, yaratish ekrani va job tafsilot ekrani.
Matnlar mavjud lokalizatsiya tizimiga qo‘shiladi; noma’lum yangi bosqichda UI
umumiy “Qayta ishlanmoqda” holatini ko‘rsatadi.

## 7. O‘lcham va mavjud Model3D bilan bog‘lash

- Hozirgi converter’da balandlik butun modelga bir xil masshtab beradi;
  en/chuqurlik faqat 15% farqni tekshiradi. Bu xatti-harakat mobil UI’da tushuntiriladi.
- Balandlik avtomatik taxmin qilinsa foydalanuvchiga mebel turi, taxmin va ishonch
  ko‘rsatiladi. AR uchun haqiqiy o‘lcham deb yashirincha qabul qilinmaydi.
- `volume_m3` — bounding-box hajmi; API’da `bbox_volume_m3` deb aniqlashtiriladi.
  Bu material sarfi yoki aniq obyekt hajmi emas.
- GLB birliklari metr, Y yuqoriga, min Y=0; X/Z markazlangan.
- Mavjud `apps.assets.Model3D`da product/variant bog‘lanishi, GLB va bbox
  maydonlari mavjud. Ruxsat tekshirilgach natija shu modelga biriktirilishi mumkin.
- Converter job’dagi batafsil status alohida saqlanadi; umumiy `Model3D.status`
  generatsiya progressining yagona manbasi bo‘lmaydi.
- **Mavjud `Model3DSerializer.save()` avtomatik umumiy processing oqimini ishga
  tushirishi mumkin.** Converter natijasini shu oqimga ko‘r-ko‘rona uzatmaslik kerak:
  GLB-only natijani saqlash, bbox hisoblash va `READY` qilish uchun aniq xizmat
  funksiyasi qo‘shiladi. USDZ generatsiyasi ishga tushirilmaydi va tayyorlik sharti emas.
- Yangi natija tekshirilmaguncha avvalgi tayyor model o‘chirilmaydi. Shu product/variant
  uchun parallel generatsiyalar bo‘lsa, qaysi job yakuniy modelni almashtirishi
  versiya/aktiv job tekshiruvi orqali belgilanadi.

## 8. Implementatsiya tartibi va qabul mezonlari

Tartib: (1) doimiy input storage va job DB, (2) recoverable GPU queue va ichki
servis autentifikatsiyasi, (3) VIDA JWT API, (4) iOS upload/polling/recovery UI,
(5) GLB ko‘rish va ixtiyoriy product/variantga biriktirish.

Qabul qilishda tekshiriladi:

- Uploaddan keyin ilova yopilib ochilganda xuddi shu job tiklanadi.
- Bir xil idempotency key takroran yuborilsa bitta job yaratiladi.
- Worker/API qayta ishga tushganda navbatdagi rasmlar va ishlar yo‘qolmaydi.
- Bir GPU’da bir vaqtda faqat bitta generatsiya ishlaydi.
- Navbat o‘rni, bosqich va progress iOS’da ko‘rinadi; eski javob progressni pasaytirmaydi.
- Qayta urinish yangi `attempt` bilan aniq ko‘rsatiladi.
- Bir foydalanuvchi boshqa foydalanuvchi/kompaniya job’i yoki faylini ko‘ra olmaydi.
- Fayl/rasm limitlari, noto‘g‘ri rollar, manfiy/cheksiz o‘lchamlar tekshiriladi.
- Tekstura xatosi GLB tayyor bo‘lsa ogohlantirish bilan yakunlanadi.
- GLB tayyorligi, proporsiya, polga joylash va tekstura saqlanishi tekshiriladi.
- O‘lcham 15% dan ko‘p farq qilsa yoki avtomatik taxmin bo‘lsa UI buni ko‘rsatadi.
- GLB-only oqimi hech qachon USDZ’ni kutmaydi yoki avtomatik yaratmaydi.
- Tarmoq uzilishi, JWT refresh va URL muddati tugashi job’ni yo‘qotmaydi.

2026-10-24 dagi tekshiruv: converter sahifasi va kolleksiya endpointi HTTP 200;
`test_scale_model.py` — 7 test muvaffaqiyatli. **Bu natija yangi mobil navbat/API
implementatsiyasi tayyor yoki sinovdan o‘tgan degani emas.**
