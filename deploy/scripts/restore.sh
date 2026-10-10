#!/usr/bin/env bash
# YANGI serverda: backup papkasini DB va media'ga tiklaydi.
#   BACKUP=/root/vida-backup-20261011-1200 ./restore.sh
# Oldindan: MySQL o'rnatilgan, `furniture_platform` bazasi va `vida` foydalanuvchisi yaratilgan,
# loyiha /srv/vida/app ga klonlangan.
set -euo pipefail
BACKUP="${BACKUP:?BACKUP=<papka> ko'rsating}"
APP="${APP:-/srv/vida/app}"
DB_NAME="${DB_NAME:-furniture_platform}"
DB_USER="${DB_USER:-root}"

echo ">> DB tiklash"
gunzip -c "$BACKUP/db.sql.gz" | mysql -u "$DB_USER" -p --default-character-set=utf8mb4 "$DB_NAME"

echo ">> media"
tar -C "$APP/backend" -xzf "$BACKUP/media.tar.gz"
chown -R vida:vida "$APP/backend/media"

echo ">> .env va firebase"
install -m 600 -o vida -g vida "$BACKUP/backend.env" "$APP/backend/.env"
[ -f "$BACKUP/firebase-credentials.json" ] && install -m 600 -o vida -g vida "$BACKUP/firebase-credentials.json" "$APP/backend/" || true
[ -f "$BACKUP/frontend.env" ] && install -m 600 -o vida -g vida "$BACKUP/frontend.env" "$APP/frontend/.env" || true

echo ">> Qdrant storage (bor bo'lsa)"
if [ -f "$BACKUP/qdrant-storage.tar.gz" ]; then
  mkdir -p "$APP/deploy/qdrant" && tar -C "$APP/deploy/qdrant" -xzf "$BACKUP/qdrant-storage.tar.gz"
fi
echo "Tayyor. .env'dagi domenlarni (ALLOWED_HOSTS, FRONTEND_URL, BACKEND_URL, ...) yangilashni unutmang."
