"""GLB fayldan mahsulotning haqiqiy geometrik o'lchamini (bounding box) va
undan kelib chiqadigan "shakl" toifasini chiqarib olish — foydalanuvchi
qo'lda kiritgan `Variant.width/height/depth`dan farqli o'laroq, bu bevosita
3D fayl geometriyasidan hisoblanadi (qidiruv/filtr uchun ishonchli manba).

glTF-Binary (.glb) formati: 12 baytli sarlavha + JSON chunk + (ixtiyoriy)
BIN chunk. Har bir mesh primitive'ning POSITION accessor'ida glTF
spetsifikatsiyasi talabiga ko'ra `min`/`max` (3 ta son) allaqachon mavjud —
shuning uchun butun vertex buferini dekodlashning hojati yo'q, faqat JSON
chunkni o'qish yetarli (tez va yengil)."""

import json
import struct

# Node transformatsiyalari (rotation/scale) hisobga olinmaydi — oddiy
# mahsulot eksportlarida odatda bittagina object, ildiz darajasida identity
# transform bilan keladi. Murakkab sahna grafigi uchun taxminiy natija.


def extract_bbox(file_obj):
    """`{"width": ..., "height": ..., "depth": ...}` (metr) qaytaradi,
    GLB emas yoki parslab bo'lmasa — None."""
    try:
        file_obj.seek(0)
    except (AttributeError, ValueError):
        pass
    try:
        data = file_obj.read()
    except (AttributeError, OSError):
        return None
    if len(data) < 12 or data[:4] != b"glTF":
        return None

    offset = 12
    json_chunk = None
    while offset + 8 <= len(data):
        try:
            chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        except struct.error:
            break
        offset += 8
        chunk_data = data[offset : offset + chunk_length]
        offset += chunk_length
        if chunk_type == b"JSON":
            json_chunk = chunk_data
            break

    if json_chunk is None:
        return None
    try:
        gltf = json.loads(json_chunk)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None

    accessors = gltf.get("accessors", [])
    global_min = [None, None, None]
    global_max = [None, None, None]
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            pos_idx = prim.get("attributes", {}).get("POSITION")
            if pos_idx is None or not isinstance(pos_idx, int) or pos_idx >= len(accessors):
                continue
            acc = accessors[pos_idx]
            amin, amax = acc.get("min"), acc.get("max")
            if not (isinstance(amin, list) and isinstance(amax, list)) or len(amin) != 3 or len(amax) != 3:
                continue
            for i in range(3):
                global_min[i] = amin[i] if global_min[i] is None else min(global_min[i], amin[i])
                global_max[i] = amax[i] if global_max[i] is None else max(global_max[i], amax[i])

    if None in global_min or None in global_max:
        return None
    width = round(abs(global_max[0] - global_min[0]), 4)
    height = round(abs(global_max[1] - global_min[1]), 4)
    depth = round(abs(global_max[2] - global_min[2]), 4)
    if width <= 0 and height <= 0 and depth <= 0:
        return None
    return {"width": width, "height": height, "depth": depth}


# Nisbat shu chegaradan katta bo'lsa, o'sha o'q "aniq ustun" hisoblanadi —
# aks holda mutanosib ("kub_simon") deb belgilanadi.
_DOMINANT_RATIO = 1.4

SHAPE_LABELS = {
    "baland": "Baland (vertikal)",
    "keng": "Keng (gorizontal)",
    "chuqur": "Chuqur",
    "kub_simon": "Mutanosib (kub-simon)",
}


def classify_shape(bbox):
    """Bounding box'dan taxminiy shakl toifasi — qidiruv/filtr uchun teg."""
    if not bbox:
        return ""
    width, height, depth = bbox["width"], bbox["height"], bbox["depth"]
    dims = sorted([width, height, depth])
    smallest, mid = dims[0], dims[1]
    if mid <= 0:
        return "kub_simon"
    ratio = dims[2] / mid
    if ratio <= _DOMINANT_RATIO:
        return "kub_simon"
    if height == dims[2]:
        return "baland"
    if width == dims[2]:
        return "keng"
    return "chuqur"
