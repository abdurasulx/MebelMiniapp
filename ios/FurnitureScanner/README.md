# FurnitureScanner — o‘lchash va rasm → GLB

Xcode’da FurnitureScanner.xcodeproj’ni oching. project.yml orqali xcodegen generate bilan qayta yaratish ham mumkin. iOS 17+, haqiqiy iPhone/iPad kerak.

## Skan ekranidan avtomatik yuborish

Mebel tanlanganda kamera rasmi interfeys va sariq marker qo‘shilmasdan olinadi. Skan tugagach **3D yaratish** tugmasi shu rasm va o‘lchamlarni darhol konvertorga yuboradi; qaytadan galereyadan rasm tanlash talab qilinmaydi. So‘rovning progress oynasi avtomatik ochiladi. Ketma-ket ikki bosishdan himoya bor. Javob uzilsa xuddi shu skan avtomatik qayta yuborilmaydi; tarixdan tekshiriladi. Yangi skan uchun **Qayta skan** ishlatiladi.

## 3D so‘rovlar

1. Telefonda ruxsat berilgan Tailscale hisobiga kiring va tarmoqni yoqing.
2. **3D so‘rovlar** bo‘limida serverni tekshiring: http://100.90.116.106:5000.
3. Mebel rasmini tanlang. O‘lchamlarni sm’da kiriting yoki skandan olib tekshiring. Bo‘sh maydonlarni AI taxmin qiladi.
4. **3D yaratish** orqali yuboring. Tarixda sana, holat, navbat o‘rni, bosqich va progress ko‘rinadi. Bo‘lim faol bo‘lsa har 4 soniyada yangilanadi; pastga tortib qo‘lda yangilash ham bor.
5. So‘rov tafsilotida natija o‘lchamlari, ogohlantirish va xatolarni ko‘ring. **GLB modelni ochish** orqali modelni yuklash, aylantirish, yaqinlashtirish va faylni ulashish mumkin.

Tarix Application Support/Conversions/history.json’da atomik saqlanadi, ilova qayta ochilganda tiklanadi. GLB fayllari Caches’da; iOS ularni tozalasa serverdan qayta yuklanadi. Ilova o‘chirilsa tarix ham o‘chadi. Hisoblararo/qurilmalararo sinxronlash yo‘q.

Har yuborishga alohida client UUID beriladi. Yuklash javobi uzilsa avtomatik qayta POST qilinmaydi: noaniq holat saqlanib, GET orqali qabul qilingan ish qidiriladi. Konvertorda idempotency yo‘q; foydalanuvchi yana **3D yaratish** bossa yangi ish yaratiladi. Server va client har yozuvda saqlanadi; server sozlamasi almashtirilsa eski ishlar o‘z serveridan yangilanadi.

Fon rejimida doimiy polling yo‘q. Server ishni davom ettiradi, ilova ochilganda holat qayta olinadi.

## Integratsiya

Mavjud Flask API: POST /api/convert, GET /api/jobs?client=…, GET /files/…. Yuklash multipart: image, roles, collection, client, height_cm/width_cm/depth_cm, ai_prepare, remove_bg, textured, fit_dimensions.

Mobil ilovada AI kaliti yo‘q; u Ubuntu’da saqlanadi. Konvertor Tailscale egasini tekshiradi. Bu public internet uchun foydalanuvchi autentifikatsiyasi emas. Kelajakdagi VIDA JWT arxitekturasi ../../img3dconverter.md’da.

Skan o‘lchamlari taxminiy bo‘lgani uchun fit_dimensions=0: balandlik bo‘yicha proporsional masshtablash, en/chuqurlik farq qilishi mumkin. Yakuniy GLB o‘lchamlari tafsilotda ko‘rsatiladi. USDZ talab qilinmaydi; native AR viewer qo‘shilmagan.

model-viewer 4.1.0 skripti ilovaga biriktirilgan, viewer skriptini yuklash uchun CDN kerak emas. Ayrim siqilgan GLB’lar qo‘shimcha decoder talab qilishi mumkin. Litsenziya: Resources/model-viewer.LICENSE. Rasm tanlash PhotosPicker orqali, skan o‘lchamlarini alohida tugma bilan olish mumkin.

## LiDAR hujjati bilan solishtirish — 2026-10-24

| Talab | Hozirgi holat |
|---|---|
| AR kamera, raycast, mesh | Kod bor; qurilmada tekshirish kerak |
| Mebelni fondan ajratish | Yo‘q; bosilgan nuqtadan 0.95 m radiusdagi mesh olinadi |
| Haqiqiy qirra/tekisliklarni aniqlash | Yo‘q |
| Burilgan mebelning mahalliy koordinatalari | Yo‘q; global X/Y/Z min/max |
| Shovqinni filtrlash, nuqtalarni deduplikatsiya qilish | Yo‘q |
| Qamrov/noaniqlik/takroriy o‘lchovlar bo‘yicha sifat | Yo‘q; nuqtalar soni va minimal o‘lcham tekshiruvi bor |
| Qirralarni qo‘lda tuzatish | Yo‘q |
| 20–30 mebelda nazorat o‘lchovi | Dalil yo‘q |
| Flutter native channel | Yo‘q; mustaqil iOS ilova |
| Rasm → GLB, lokal tarix, progress, viewer | Ushbu o‘zgarishda qo‘shildi; iPhone sinovi kerak |

Hozirgi o‘lchov pol/devorni qo‘shib olishi, burilganda kattalashishi, katta mebelni to‘liq qamramasligi mumkin. Ishlab chiqarish aniqligidagi o‘lchov hali emas.

Konvertor navbati RAM’da. Server restartida tugallanmagan ishlar yo‘qolishi mumkin; ilova bunday ishni tayyor deb ko‘rsatmaydi, noaniq holatni bildiradi. Lokal tarix serverning doimiy navbati o‘rnini bosmaydi.

## Tekshirish

Windows’da Swift sintaksisi parser orqali, plist/YAML transport sozlamalari va Xcode source/resource bog‘lanishlari tekshirildi. Bu Xcode build o‘rnini bosmaydi. Ubuntu SSH ulanishi timeout berdi; ushbu o‘zgarishning jonli server/iPhone sinovi bajarilmadi.

Haqiqiy iPhone’da tekshirish:

- Rasm yuborish → navbat → progress → GLB; teksturali va teksturasiz.
- Ilovani yopib ochib faol so‘rovni qayta topish.
- Tailscale uzilganda saqlangan holat va aloqa xatosi ko‘rinishi.
- Yuklash javobi uzilganda yangi POSTsiz mavjud ishni topish.
- GLB aylantirish, zoom, ulashish va keshdan ochish.
- Server restartidan keyin yo‘qolgan ishning noaniq holatda ko‘rinishi.

Bundled viewer brauzer sinovi: test GLB blob muvaffaqiyatli ochildi, JavaScript xatosi yo‘q. Bu Chromium headless sinovi; iOS WKWebView qurilma sinovi hali kerak.

Keyingi jonli tekshiruvda Tailscale tiklandi: to‘rtta GPU so‘rovi GLB bilan yakunlandi va viewer’da ochildi. Batafsil natija: ../../docs/testing/furniture-ai-2026-10-24.md. Bu iPhone LiDAR aniqligini yoki native Xcode build’ni tasdiqlamaydi.

2026-10-26: O‘lchash va 3D so‘rovlar ekranlarida “Bitta mebel / Butun komplekt”
tanlovi qo‘shildi. Qiymat reconstruction_scope bilan yuboriladi. Komplekt
rejimida barcha mos mebel qismlari bitta GLB uchun tahlil qilinadi, ammo bir
rasmdan tuzilishning aniq tiklanishi kafolatlanmaydi. Bu yangi iOS build talab
qiladi; ushbu Windows muhitida native build tekshirilmagan.
