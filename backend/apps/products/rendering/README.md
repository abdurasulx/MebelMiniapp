# 3D modeldan avtomatik mahsulot rasmlari

Sotuvchi yuklagan GLB modeldan standart, bir xil sifatdagi rasmlar yaratiladi.
**Faqat serverda render qilingan rasmlar xaridorga ko'rinadi**; sotuvchi
brauzeridagi preview hech qachon saqlanmaydi.

## Qismlar

| Fayl | Vazifa |
|---|---|
| `frontend/public/render/index.html` | Yagona render sahifa (model-viewer 4.0.0, `vendor/` ichida pinlangan). Brauzer preview va server (Playwright) bir xil sahifani ishlatadi. |
| `rendering/validate.py` | GLB tekshiruvi: ≤50 MB, ≤500k uchburchak, tekstura ≥1024 px, o'lcham 5–400 sm. Xabarlar o'zbekcha. |
| `rendering/imaging.py` | PNG → kvadrat, mahsulot kadrning 85%i, WebP/AVIF 400/800/1600 (shaffoflik saqlanadi). |
| `rendering/runner.py` | Job bajarish: yuklash → tekshirish → Playwright → rasm → storage → baza. Qayta urinish (jami 3 urinish). |
| `management/commands/render_worker.py` | Navbat ishchisi (concurrency 1, `nice 19`). |
| `deploy/systemd/vida-render-worker.service` | systemd xizmati (CPUQuota 400%, MemoryMax 3G). |

## Sozlash

```bash
cd backend && source venv/bin/activate
pip install -r requirements.txt
PLAYWRIGHT_BROWSERS_PATH=/srv/vida/playwright python -m playwright install --with-deps chromium
python manage.py migrate
sudo cp ../deploy/systemd/vida-render-worker.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now vida-render-worker
```

- **Render sahifa**: `RENDER_PAGE_DIR` (ixtiyoriy) — standart `frontend/dist/render`, bo'lmasa `frontend/public/render`. `npm run build` dist'ga nusxalaydi.
- **Muhit (HDRI)**: model-viewer'ning ichki doimiy `neutral` studiya muhiti ishlatiladi (`environment-image="neutral"`) — alohida HDRI fayl yo'q, shuning uchun repoga fayl qo'shilmaydi. Boshqa HDRI kerak bo'lsa, `index.html`dagi `environment-image` ni `./studio.hdr` ga o'zgartiring.
- **Saqlash**: `django.core.files.storage.default_storage`. Hozir lokal (`MEDIA_ROOT`); Cloudflare R2 uchun `django-storages[s3]` ni qo'shib `STORAGES["default"]`ni S3 backendga (endpoint = R2) sozlang va `OPTIONS.object_parameters = {"CacheControl": "public, max-age=31536000, immutable"}` qo'ying. Kalitlar content-hash'li (`products/{id}/{variant}/{shot}-{size}-{hash}.{ext}`), shuning uchun immutable kesh xavfsiz.
- **R2 CORS** (GLB'ni sayt domenidan yuklash uchun): `AllowedOrigins: [https://vidamarket.uz, https://firma.vidamarket.uz]`, `AllowedMethods: [GET, HEAD]`.
- **Navbat**: DB-asosli (`RenderJob`); Celery/Redis shart emas. GLB saqlanganda avtomatik (`apps/assets/signals.py`), qo'lda — `POST /products/{id}/rerender/`.

## API

`GET /products/{id}/` qo'shimcha maydonlari: `render_status` (`none|pending|processing|ready|failed`), `render_error`, `model_dims_cm`, `needs_moderation`, `moderation_note`, `renders` — variantlar bo'yicha guruhlangan `[{variant, slug, variant_id, shots:[{key, urls:{"400":{webp,avif},...}}]}]` (shotlar tartibi: hero, front, side, back, top).

## Cheklovlar / eslatmalar

- Render qilinadigan variantlar: GLB ichidagi `KHR_materials_variants` (bo'lsa), aks holda rangli (`color_hex`) DB variantlari, aks holda bitta "default". Tekstura-asosli DB variantlari hozircha rang bilan ifodalanmaydi.
- Mahsulotda sotuvchining o'z asosiy rasmi bo'lsa, render uni almashtirmaydi (`image_from_render=False`).
- Kiritilgan o'lcham modeldan >10% farq qilsa `needs_moderation=True` (admin `POST /products/{id}/approve-moderation/`); mavjud nashr qilingan mahsulotlar yashirilmaydi.
- Tekshiruv: `python manage.py test apps.products.test_render`.
