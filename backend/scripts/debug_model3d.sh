#!/usr/bin/env bash
# 3D model (GLB->USDZ) konvertatsiyasi nima uchun "Xatolik" bilan tugayotganini
# aniqlash uchun bir martalik diagnostika skripti. Ishlatish (backend/ papkasida,
# venv faol holda):
#
#   bash scripts/debug_model3d.sh [MODEL3D_ID]
#
# MODEL3D_ID berilmasa, eng oxirgi "failed" holatdagi yozuv avtomatik topiladi.
# Natija ekranga VA /tmp/model3d_debug.log fayliga yoziladi.

set -uo pipefail

LOG=/tmp/model3d_debug.log
: > "$LOG"

log() { echo "$@" | tee -a "$LOG"; }

log "=== blender --version ==="
blender --version 2>&1 | tee -a "$LOG"

log ""
log "=== which blender / unar ==="
{ which blender; which unar; } 2>&1 | tee -a "$LOG"

MODEL_ID="${1:-}"
if [ -z "$MODEL_ID" ]; then
    log ""
    log "=== eng oxirgi 'failed' Model3D qidirilmoqda ==="
    MODEL_ID=$(python manage.py shell -c "
from apps.assets.models import Model3D
m = Model3D.objects.filter(status='failed').order_by('-created_at').first()
print(m.id if m else '')
" 2>>"$LOG" | tail -n 1)
fi

if [ -z "$MODEL_ID" ]; then
    log "Hech qanday 'failed' Model3D topilmadi va ID berilmagan — to'xtatildi."
    exit 1
fi

log ""
log "=== process_model3d $MODEL_ID (to'liq chiqish) ==="
python manage.py process_model3d "$MODEL_ID" 2>&1 | tee -a "$LOG"

log ""
log "=== Tayyor. To'liq log: $LOG ==="
