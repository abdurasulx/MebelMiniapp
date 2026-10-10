"""GLB faylni render'dan oldin tekshirish (server resurslarini himoya qilish
va sotuvchiga aniq xabar berish). Barcha xabarlar o'zbekcha."""
import io
import json
import struct

from PIL import Image

MAX_BYTES = 50 * 1024 * 1024
MAX_TRIANGLES = 500_000
MIN_TEXTURE_PX = 1024
MIN_DIM_CM = 5
MAX_DIM_CM = 400


class RenderValidationError(Exception):
    """Doimiy xato (qayta urinishning foydasi yo'q) — sotuvchiga ko'rsatiladi."""


def _chunks(data: bytes):
    if len(data) < 12 or data[:4] != b"glTF":
        raise RenderValidationError("Fayl GLB formatida emas.")
    offset, json_chunk, bin_chunk = 12, None, b""
    while offset + 8 <= len(data):
        length, ctype = struct.unpack_from("<I4s", data, offset)
        offset += 8
        body = data[offset : offset + length]
        offset += length
        if ctype == b"JSON":
            json_chunk = body
        elif ctype == b"BIN\x00":
            bin_chunk = body
    if json_chunk is None:
        raise RenderValidationError("GLB ichida model ma'lumoti topilmadi.")
    try:
        return json.loads(json_chunk), bin_chunk
    except (ValueError, UnicodeDecodeError) as exc:
        raise RenderValidationError("GLB fayli buzilgan.") from exc


def count_triangles(gltf: dict) -> int:
    accessors = gltf.get("accessors", [])
    total = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            mode = prim.get("mode", 4)
            if mode not in (4, 5, 6):
                continue
            idx = prim.get("indices")
            if isinstance(idx, int) and idx < len(accessors):
                n = accessors[idx].get("count", 0)
            else:
                pos = prim.get("attributes", {}).get("POSITION")
                n = accessors[pos].get("count", 0) if isinstance(pos, int) and pos < len(accessors) else 0
            total += n // 3 if mode == 4 else max(n - 2, 0)
    return total


def texture_sizes(gltf: dict, bin_chunk: bytes) -> list:
    sizes = []
    views = gltf.get("bufferViews", [])
    for image in gltf.get("images", []):
        view_idx = image.get("bufferView")
        if not isinstance(view_idx, int) or view_idx >= len(views):
            continue  # tashqi fayl yoki data-URI — GLB'da kam uchraydi
        v = views[view_idx]
        start = v.get("byteOffset", 0)
        blob = bin_chunk[start : start + v.get("byteLength", 0)]
        try:
            with Image.open(io.BytesIO(blob)) as im:
                sizes.append(im.size)
        except Exception:  # noqa: BLE001 — tekstura formatini o'qib bo'lmasa, o'tkazib yuboramiz
            continue
    return sizes


def validate_glb_bytes(data: bytes) -> dict:
    """Xatolik bo'lsa `RenderValidationError`; aks holda statistikani qaytaradi."""
    if len(data) > MAX_BYTES:
        raise RenderValidationError(
            f"Model fayli juda katta ({len(data) // (1024 * 1024)} MB). Ruxsat etilgan: {MAX_BYTES // (1024 * 1024)} MB gacha."
        )
    gltf, bin_chunk = _chunks(data)
    triangles = count_triangles(gltf)
    if triangles > MAX_TRIANGLES:
        raise RenderValidationError(
            f"Modelda uchburchaklar soni juda ko'p ({triangles:,}). Ruxsat etilgan: {MAX_TRIANGLES:,} gacha — modelni soddalashtiring."
        )
    for w, h in texture_sizes(gltf, bin_chunk):
        if max(w, h) < MIN_TEXTURE_PX:
            raise RenderValidationError(
                f"Tekstura sifati past ({w}×{h} px). Kamida {MIN_TEXTURE_PX} px bo'lishi kerak."
            )
    return {"triangles": triangles, "bytes": len(data)}


def validate_dimensions_cm(w: float, h: float, d: float) -> None:
    longest = max(w, h, d)
    if longest < MIN_DIM_CM or longest > MAX_DIM_CM:
        raise RenderValidationError(
            f"Model o'lchami noto'g'ri ({w:.0f}×{h:.0f}×{d:.0f} sm). "
            f"Eng katta tomon {MIN_DIM_CM}–{MAX_DIM_CM} sm oralig'ida bo'lishi kerak (model metr birligida bo'lishi lozim)."
        )
