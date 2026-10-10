# qrbite.uz → vidamarket.uz va yangi serverga ko'chish

Bu hujjat ikki narsani qamrab oladi:

- **A. Joriy serverni yangilash** (hozirgi `qrbite.uz` serveri, kod yangilanishi).
- **B. Yangi serverga to'liq ko'chish** (vidamarket.uz, bir xil holat).

Joriy server (aaPanel): kod `/www/wwwroot/qrbite.uz/MebelMiniapp`, xizmat `qrbite-backend` (gunicorn :8180), MySQL, Qdrant (docker).

---

## A. Joriy serverni yangilash

```bash
cd /www/wwwroot/qrbite.uz/MebelMiniapp
git pull

# --- backend ---
cd backend && source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
sudo systemctl restart qrbite-backend

# --- frontend (render sahifa dist/render ga tushadi) ---
cd ../frontend && npm ci && npm run build
```

Tekshirish:

```bash
sudo systemctl status qrbite-backend --no-pager | head -5
curl -s -o /dev/null -w "%{http_code}\n" https://api.qrbite.uz/api/v1/categories/
```

**Eslatmalar**

- **3D'dan avtomatik rasmlar** sotuvchining brauzerida olinadi (server tomonida qo'shimcha xizmat, Chromium yoki Playwright kerak emas). Model yuklangach firma panelida ekran bloklanib rasmlar avtomatik olinadi. Mavjud mahsulotlar uchun modelni qayta yuklash yoki mahsulot sahifasida "Rasmlarni modeldan olish".
- **Migratsiya konflikti:** serverda `makemigrations` ishlatilgan bo'lsa va `git pull` "untracked file would be overwritten" desa — o'sha faylni `/tmp` ga ko'chirib, qayta `pull`. Serverda `makemigrations` ishlatmang.
- **Eskiz SMS:** `.env`da `ESKIZ_ENABLED=true` (moderatsiya tasdiqlangach), so'ng `systemctl restart qrbite-backend`.
- Bu serverda `config.settings.dev` ishlatilmoqda (`CORS_ALLOW_ALL_ORIGINS=True`). Yangi serverda `config.settings.prod`.

---

## B. Yangi serverga ko'chish (vidamarket.uz)

### 0. Reja va tartib (downtime ~10–20 daqiqa)

| # | Qadam | Joy |
|---|---|---|
| 1 | Yangi serverni tayyorlash, kodni o'rnatish, **bo'sh** DB bilan sinash | yangi |
| 2 | DNS TTL ni 300 s ga tushirish (1 kun oldin) | DNS |
| 3 | Cutover: eski serverda yozishni to'xtatish → DB/media nusxa → yangi serverda tiklash | ikkalasi |
| 4 | DNS'ni yangi IP'ga ko'chirish (`vidamarket.uz`, `*.vidamarket.uz`, **`api.qrbite.uz`** ham) | DNS |
| 5 | Tashqi xizmatlar (Google, Telegram, Firebase, Apple) | konsollar |
| 6 | Mobil ilovalarning yangi build'i (`api.vidamarket.uz`) | build |
| 7 | Eski serverni 2 hafta "sovuq zaxira" sifatida saqlash | eski |

> **Muhim:** bozordagi eski ilova versiyalari `api.qrbite.uz` ga ulanadi. Shuning uchun `api.qrbite.uz` yangi serverga ham yo'naltiriladi va kamida 6–12 oy ishlashda qoladi (`deploy/nginx/vidamarket.uz.conf` ikkala domenga xizmat qiladi). Veb manzillar `qrbite.uz → vidamarket.uz` ga 301 redirect.

### 1. Server talablari

- Ubuntu 22.04/24.04, **kamida 8 GB RAM** (3 gunicorn worker × CLIP ~2 GB), 6 yadro tavsiya, 60+ GB disk (media o'sadi).
- Paketlar:

```bash
sudo apt update && sudo apt install -y nginx mysql-server redis-server git curl \
    python3.12 python3.12-venv build-essential libmysqlclient-dev pkg-config \
    docker.io docker-compose-plugin certbot
# Node 20 (frontend build)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs
sudo useradd -m -s /bin/bash vida
sudo mkdir -p /srv/vida && sudo chown vida:vida /srv/vida
```

### 2. Kod va muhit

```bash
sudo -u vida git clone <repo-url> /srv/vida/app
cd /srv/vida/app/backend
sudo -u vida python3.12 -m venv venv
sudo -u vida venv/bin/pip install -r requirements.txt
```

`.env` — `deploy/env/backend.env.example` dan; **SECRET_KEY va DEVICE_HMAC_SECRET eski serverdagi bilan bir xil** bo'lsin (aks holda hamma tizimdan chiqib ketadi). Frontend uchun `deploy/env/frontend.env.example` → `/srv/vida/app/frontend/.env`.

MySQL:

```sql
CREATE DATABASE furniture_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'vida'@'localhost' IDENTIFIED BY '<PAROL>';
GRANT ALL ON furniture_platform.* TO 'vida'@'localhost';
```

### 3. Ma'lumotlarni ko'chirish (cutover paytida)

**Eski serverda:**

```bash
sudo systemctl stop qrbite-backend            # yozishni to'xtatish
cd /www/wwwroot/qrbite.uz/MebelMiniapp/deploy/scripts && sudo ./backup.sh   # → /root/vida-backup-YYYYmmdd-HHMM/
rsync -avz --progress /root/vida-backup-*/ vida@<YANGI_IP>:/srv/vida/backup/
```

**Yangi serverda:**

```bash
cd /srv/vida/app/deploy/scripts
sudo BACKUP=/srv/vida/backup DB_USER=root ./restore.sh
cd /srv/vida/app/backend
sudo -u vida venv/bin/python manage.py migrate          # eski dump'da yo'q migratsiyalar bo'lsa
sudo -u vida venv/bin/python manage.py collectstatic --noinput
```

**Qdrant (rasm qidiruvi):**

```bash
cd /srv/vida/app/deploy/qdrant && sudo docker compose up -d
# storage nusxalanmagan bo'lsa — embedding'larni qayta hisoblash (bir necha daqiqa):
cd /srv/vida/app/backend && sudo -u vida venv/bin/python manage.py backfill_embeddings
```

### 4. Xizmatlar va nginx

```bash
sudo cp /srv/vida/app/deploy/systemd/vida-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now vida-backend

cd /srv/vida/app/frontend && sudo -u vida npm ci && sudo -u vida npm run build

# SSL (wildcard, DNS-01) — ikkala domen uchun
sudo certbot certonly --manual --preferred-challenges dns -d vidamarket.uz -d '*.vidamarket.uz'
sudo certbot certonly --manual --preferred-challenges dns -d qrbite.uz -d '*.qrbite.uz'

sudo cp /srv/vida/app/deploy/nginx/vidamarket.uz.conf /etc/nginx/conf.d/vidamarket.uz.conf
sudo nginx -t && sudo systemctl reload nginx
```

Hosts-fayl orqali oldindan sinash (DNS o'zgarmasdan):

```bash
echo "<YANGI_IP> api.vidamarket.uz vidamarket.uz admin.vidamarket.uz firma.vidamarket.uz" | sudo tee -a /etc/hosts
/srv/vida/app/deploy/scripts/smoke_test.sh vidamarket.uz
```

### 5. DNS cutover

Ikkala zonada (`vidamarket.uz`, `qrbite.uz`) A yozuvlari yangi IP'ga: `@`, `www`, `admin`, `firma`, `api` (wildcard bo'lsa `*` ham). TTL 300 s.

> **Telegram webhook:** backend ishga tushganda `setWebhook` ni o'zi chaqiradi. Eski va yangi server bir vaqtda ishlab tursa, oxirgi ishga tushgani webhook'ni oladi — cutover'dan keyin **eski serverdagi backend to'xtatilgan** bo'lsin.

### 6. Tashqi xizmatlar

| Xizmat | Nima qilish |
|---|---|
| **Google Cloud Console** | OAuth client (Web): *Authorized redirect URIs* ga `https://api.vidamarket.uz/api/v1/auth/google/callback/` va `.../auth/google/link/callback/` qo'shing; *Authorized JavaScript origins* ga `https://vidamarket.uz`, `https://firma.vidamarket.uz`. Eski qrbite URI'larni 6–12 oy qoldiring. |
| **Telegram bot** | `.env`da `TELEGRAM_WEBHOOK_URL=https://api.vidamarket.uz/api/v1/auth/telegram/webhook/`; servis qayta ishga tushsa avtomatik o'rnatiladi. Tekshirish: `curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo` |
| **Firebase (push)** | Domen bog'liq emas. `firebase-credentials.json` yangi serverga ko'chirilgan bo'lsin. Web push uchun Authorized domains'ga `vidamarket.uz` qo'shing. |
| **Apple** | Sign in with Apple native ilova uchun domen talab qilmaydi. App Store Connect'da Privacy Policy URL: `https://vidamarket.uz/privacy`. |
| **Eskiz** | Domen bog'liq emas; `.env`da `ESKIZ_*`. |
| **Play/App Store** | Privacy Policy URL, "Support URL", "Marketing URL" ni `vidamarket.uz` ga yangilang. |

### 7. Mobil ilovalar

Kodda default API manzili allaqachon `https://api.vidamarket.uz/api/v1` (Flutter `api_client.dart`, iOS `APIClient.swift`). **DNS va server tayyor bo'lgandan KEYIN** yangi build chiqaring:

```bash
cd flutter_app && flutter build appbundle --release        # Android
cd ios/FurniturePlatform && xcodebuild -project VidaMarket.xcodeproj -scheme VidaMarket -configuration Release \
    -destination 'generic/platform=iOS' -archivePath /tmp/VidaMarket.xcarchive -allowProvisioningUpdates archive
```

Admin panelda "Versiya nazorati" orqali eski versiyalarni majburiy yangilashni (hamma ko'chgach) yoqing.

### 8. Cutover'dan keyingi tekshiruv

- [ ] `smoke_test.sh vidamarket.uz` — hammasi 200/400/301.
- [ ] Login: telefon OTP, Google, Telegram (web va mobil).
- [ ] Katalog, mahsulot rasmlari (media rsync to'liqmi), 3D/AR.
- [ ] Rasm bilan qidiruv (Qdrant).
- [ ] Bildirishnomalar WebSocket (`wss://api.vidamarket.uz/ws/`) va push.
- [ ] Buyurtma yaratish, firma ERP, admin panel.
- [ ] `journalctl -u vida-backend -f` da xato yo'q.
- [ ] Eski `api.qrbite.uz` orqali eski ilova ishlaydi.
- [ ] Zaxira: kunlik `backup.sh` cron'ga qo'yilgan.

### 9. Orqaga qaytish (rollback)

DNS'ni eski IP'ga qaytarish (TTL 300 s). Eski serverda `systemctl start qrbite-backend`. Yangi serverdagi yangi yozuvlar (cutover'dan keyingi buyurtmalar) yo'qolmasligi uchun avval ularning DB dump'ini oling.

### 10. Xavfsizlik eslatmalari

- Yangi serverda `config.settings.prod` (DEBUG o'chiq, CORS faqat ro'yxatdagi domenlar).
- `.env` va `firebase-credentials.json` huquqi `600`, git'ga qo'shilmaydi.
- `ufw`: faqat 22, 80, 443. MySQL, Redis, Qdrant (6333) faqat `127.0.0.1`.
- **Redis kerak:** 3 worker bilan WebSocket bildirishnomalari Redis'siz ishlamaydi (`REDIS_URL`).
- Bot tokeni va Eskiz kalitlarini chatda/loglarda ochiq qoldirmang; ochiq tushgan bo'lsa almashtiring.
- `ESKIZ_ENABLED=false` bo'lsa OTP kodi API javobida ochiq qaytadi — prod'ga chiqishdan oldin `true` qiling.
