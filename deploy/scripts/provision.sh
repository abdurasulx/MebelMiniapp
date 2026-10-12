#!/usr/bin/env bash
# YANGI serverda (Ubuntu 22.04/24.04, root) bir marta ishga tushiriladi:
# paketlar, foydalanuvchi, papkalar, MySQL baza+foydalanuvchi, Redis, Docker, nginx, certbot.
#   sudo DB_PASS='<kuchli-parol>' bash provision.sh
# Natijada: /srv/vida/{app,backup} tayyor, MySQL'da `furniture_platform` + `vida` foydalanuvchisi.
# Kodni klonlash, .env, SSL va nginx'ni keyingi qadamlarda (deploy/MIGRATION.md) qilasiz.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "root sifatida ishga tushiring"; exit 1; }
DB_NAME="${DB_NAME:-furniture_platform}"
DB_USER="${DB_USER:-vida}"
DB_PASS="${DB_PASS:?DB_PASS=parol korsating (faqat harf va raqam)}"
export DEBIAN_FRONTEND=noninteractive

echo ">> 1/9 tizim yangilash va asosiy paketlar"
apt-get update -y
apt-get install -y software-properties-common curl git unzip zip ufw ca-certificates gnupg \
    build-essential pkg-config libmysqlclient-dev libjpeg-dev zlib1g-dev libwebp-dev libavif-dev

echo ">> 2/9 Python 3.12"
if ! command -v python3.12 >/dev/null; then
  add-apt-repository -y ppa:deadsnakes/ppa
  apt-get update -y
fi
apt-get install -y python3.12 python3.12-venv python3.12-dev

echo ">> 3/9 MySQL"
apt-get install -y mysql-server
systemctl enable --now mysql
mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"

echo ">> 4/9 Redis"
apt-get install -y redis-server
sed -i 's/^# *supervised .*/supervised systemd/' /etc/redis/redis.conf || true
systemctl enable --now redis-server

echo ">> 5/9 Docker (Qdrant uchun)"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

echo ">> 6/9 Node.js 20 (frontend build)"
if ! command -v node >/dev/null || [ "$(node -v | cut -c2-3)" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo ">> 7/9 nginx + certbot"
apt-get install -y nginx certbot python3-certbot-nginx
systemctl enable --now nginx

echo ">> 3D model ishlov berish vositalari (Blender, unar, assimp, zip)"
# Backend (process_model3d) FBX/OBJ/DAE -> GLB va GLB -> USDZ uchun `blender`, RAR uchun `unar`,
# DAE uchun `assimp` ishlatadi. Skriptlar `bpy.ops.wm.obj_import` (Blender >= 3.2) talab qiladi,
# shuning uchun apt'dagi eski versiya (22.04'da 3.0) emas, rasmiy 4.2 LTS o'rnatiladi.
apt-get install -y unar assimp-utils zip unzip xz-utils \
    libxi6 libxrender1 libgl1 libxkbcommon0 libsm6 libxxf86vm1 libxfixes3 libegl1 libxext6
BLENDER_URL="${BLENDER_URL:-https://download.blender.org/release/Blender4.2/blender-4.2.3-linux-x64.tar.xz}"
if ! command -v blender >/dev/null; then
  mkdir -p /opt/blender
  curl -fL "$BLENDER_URL" -o /tmp/blender.tar.xz
  tar -xJf /tmp/blender.tar.xz -C /opt/blender --strip-components=1
  ln -sf /opt/blender/blender /usr/local/bin/blender
  rm -f /tmp/blender.tar.xz
fi
blender --background --python-expr "import bpy; print('BLENDER_OK', bpy.app.version_string)" 2>&1 | grep BLENDER_OK || echo "OGOHLANTIRISH: blender ishga tushmadi"

echo ">> 9/9 foydalanuvchi, papkalar, xavfsizlik devori"
id vida >/dev/null 2>&1 || useradd -m -s /bin/bash vida
mkdir -p /srv/vida/app /srv/vida/backup
chown -R vida:vida /srv/vida
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo
echo "Tayyor. Versiyalar:"
python3.12 --version; blender --version | head -1; unar -v 2>&1 | head -1; mysql --version; redis-server --version | head -1; docker --version; node -v; nginx -v 2>&1
echo "Keyingi qadamlar: deploy/MIGRATION.md (3 -> kod/venv, 4 -> nginx/SSL)."
