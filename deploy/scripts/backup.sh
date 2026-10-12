#!/usr/bin/env bash
# Eski serverda ishga tushiriladi: DB (sql.gz) + rasmlar (zip) + 3D fayllar (zip) + sozlamalar.
#   APP=/www/wwwroot/qrbite.uz/MebelMiniapp ./backup.sh   -> /root/vida-backup-YYYYmmdd-HHMM/
# DB parolini so'raydi (mysqldump -p). Natija papkasini yangi serverga rsync qiling.
set -euo pipefail
APP="${APP:-/www/wwwroot/qrbite.uz/MebelMiniapp}"
DB_NAME="${DB_NAME:-furniture_platform}"
DB_USER="${DB_USER:-root}"
OUT="${OUT:-/root/vida-backup-$(date +%Y%m%d-%H%M)}"
mkdir -p "$OUT"

echo ">> MySQL dump"
mysqldump -u "$DB_USER" -p --single-transaction --routines --default-character-set=utf8mb4 "$DB_NAME" | gzip > "$OUT/db.sql.gz"

command -v zip >/dev/null || { echo "zip o'rnatilmagan: apt install -y zip unzip"; exit 1; }
MEDIA="$APP/backend/media"

echo ">> media: rasmlar (3D'dan tashqari hamma narsa) -> media-images.zip"
( cd "$MEDIA" && zip -qr "$OUT/media-images.zip" . -x "assets/*" )

echo ">> media: 3D fayllar (glb/usdz/tekstura arxivlari) -> media-3d.zip"
if [ -d "$MEDIA/assets" ]; then
  ( cd "$MEDIA" && zip -qr "$OUT/media-3d.zip" assets )
else
  echo "(assets/ papkasi yo'q — 3D fayl yo'q)"
fi

echo ">> maxfiy fayllar (.env, firebase)"
cp "$APP/backend/.env" "$OUT/backend.env"
[ -f "$APP/backend/firebase-credentials.json" ] && cp "$APP/backend/firebase-credentials.json" "$OUT/" || true
[ -f "$APP/frontend/.env" ] && cp "$APP/frontend/.env" "$OUT/frontend.env" || true
chmod 600 "$OUT"/backend.env "$OUT"/frontend.env "$OUT"/firebase-credentials.json 2>/dev/null || true

echo ">> Qdrant (docker bo'lsa) — yo'q bo'lsa, yangi serverda backfill_embeddings ishlatiladi"
if [ -d "$APP/deploy/qdrant/storage" ]; then
  tar -C "$APP/deploy/qdrant" -czf "$OUT/qdrant-storage.tar.gz" storage
fi

echo "Tayyor: $OUT"
ls -lh "$OUT"
