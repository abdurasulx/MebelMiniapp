# 3D modeldan avtomatik mahsulot rasmlari (brauzerda skrin)

Rasmlar **sotuvchining brauzerida** 3D ko'rinishdan "skrin" qilib olinadi (model-viewer `toBlob`),
serverga yuklanadi va server ularni standartlab saqlaydi. Serverda Chromium/GPU/Playwright **kerak emas**.

## Oqim

1. Sotuvchi variantga model (GLB) yuklaydi -> **ekran bloklanadi** (yuklanish foizi, qayta ishlash).
2. Model tayyor bo'lgach `render_stale=true` -> firma paneli avtomatik 3D'dan rasmlar oladi
   (yashirin iframe `/render/index.html`, har variant/rakurs: hero, front, side, back, top).
3. Har rakurs `POST /products/{id}/render-image/` (PNG) -> server kvadratlaydi (85% kadr), WebP/AVIF 400/800/1600.
4. `POST /products/{id}/render-complete/` {dimensions_cm} -> status `ready`, hero asosiy rasm, eski galereya yashirinadi,
   o'lcham farqi >10% bo'lsa `needs_moderation`.
5. Xato bo'lsa `POST .../render-failed/`; qo'lda — kartadagi "Rasmlarni modeldan qayta olish".

## Fayllar

| Fayl | Vazifa |
|---|---|
| `frontend/public/render/index.html` | Render sahifa (model-viewer 4.0.0 `vendor/`da pinlangan; neytral muhit, AgX, FOV 30deg) |
| `frontend/src/lib/captureRenders.js` | Brauzerda olish + yuklash |
| `frontend/src/components/BlockingLoader.jsx` | Butun ekranni bloklaydigan yuklanish oynasi |
| `rendering/store.py` | Qabul qilish, standartlash, saqlash, `source_key`/`is_stale` |
| `rendering/imaging.py` | PNG -> kvadrat, WebP/AVIF |

## Eslatmalar

- Variantlar: GLB ichidagi `KHR_materials_variants` bo'lsa shular; aks holda DB variantlari (rang, tekstura, asl); o'z GLB'i bor variant alohida render.
- Saqlash: `default_storage` (hozir lokal `MEDIA_ROOT`; R2 uchun `django-storages` — `STORAGES["default"]`). Kalitlar content-hash'li -> immutable kesh xavfsiz.
- WebGL'siz qurilmada rasm olinmaydi (`render_status=failed` + xabar), qurilmani almashtirib qayta urinish mumkin.
- Server GLB'ni tekshirmaydi (hajm/uchburchak cheklovi yo'q) — kerak bo'lsa `Model3D` yuklashda qo'shish mumkin.
- Testlar: `python manage.py test apps.products.test_render`.
