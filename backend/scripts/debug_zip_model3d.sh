#!/usr/bin/env bash
# Zip/rar arxivdagi 3D modelning teksturasi nega ulanmayotganini aniqlash uchun
# diagnostika. Ishlatish (backend/ papkasida, venv faol):
#
#   bash scripts/debug_zip_model3d.sh /yo'l/model.zip
#
# Natija ekranga va /tmp/zip_debug.log fayliga yoziladi.

set -uo pipefail

ARCHIVE="${1:-}"
LOG=/tmp/zip_debug.log
: > "$LOG"
log() { echo "$@" | tee -a "$LOG"; }

if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
    log "Ishlatish: bash scripts/debug_zip_model3d.sh /to'liq/yo'l/model.zip"
    exit 1
fi

WORK=$(mktemp -d)
log "=== Arxiv: $ARCHIVE  (ishchi papka: $WORK) ==="

case "${ARCHIVE,,}" in
    *.zip) python - "$ARCHIVE" "$WORK" <<'PY' 2>&1 | tee -a "$LOG"
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
    ;;
    *.rar) unar -quiet -force-overwrite -output-directory "$WORK" "$ARCHIVE" 2>&1 | tee -a "$LOG" ;;
esac

log ""
log "=== Arxiv ichidagi fayllar ==="
(cd "$WORK" && find . -type f -printf '%10s  %p\n' | sort -k2) 2>&1 | tee -a "$LOG"

MODEL=""
for ext in glb gltf fbx obj dae; do
    MODEL=$(find "$WORK" -type f -iname "*.$ext" | head -n 1)
    [ -n "$MODEL" ] && break
done
log ""
log "=== Backend tanlaydigan model fayli: ${MODEL:-TOPILMADI} ==="
[ -z "$MODEL" ] && exit 1

log ""
log "=== Blender: model + teksturalar tahlili ==="
OUT="$WORK/out.glb"
case "${MODEL,,}" in
    *.fbx|*.obj|*.dae)
        blender --background --python scripts/to_glb.py -- "$MODEL" "$OUT" "$WORK" 2>&1 | tee -a "$LOG" ;;
    *)
        blender --background --python-expr "
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'''$MODEL''')
print('Rasmlar soni:', len(bpy.data.images))
for im in bpy.data.images:
    print('  -', im.name, '| packed:', bool(im.packed_file), '| filepath:', im.filepath)
print('Materiallar:', [m.name for m in bpy.data.materials])
" 2>&1 | tee -a "$LOG" ;;
esac

log ""
log "=== Tayyor. Log: $LOG ==="
