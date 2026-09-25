"""Bazis (mebel CAD dasturi, "Базис-Мебельщик") eksport faylini (`.project`,
XML, odatda windows-1251 kodировkada) o'qib, mahsulot uchun workflow
bosqichlari (`WorkflowStep`) shablonini avtomatik tuzish uchun.

Fayl tuzilishi (importBMV="1.86"):
  <project>
    <good typeId="product" ...>
      <part dl="600" dw="350" count="1" name="01_001 дно" elt="..." .../>
      ...
    </good>
    <good typeId="sheet" name="ДСП бук 16">...</good>   # xom ashyo varaqlari
    <good typeId="band" name="PVX ...">...</good>        # kromka lentalari
    <operation typeId="CS" ...><material id=".."/><part id=".."/>...</operation>  # kesish
    <operation typeId="EL" ...><material id=".."/><part id=".."/>...</operation>  # kromkalash
    <operation typeId="XNC" ... program="&lt;program&gt;&lt;tool .../&gt;&lt;bf .../&gt;...&lt;/program&gt;"/>  # CNC teshish
  </project>

Eng muhimi — har bir XNC operatsiyasi ichidagi `program` (o'zi ham XML,
HTML-entity bilan escape qilingan) `<bf>`/`<bl>` (bore face/line — teshik)
buyruqlari va ularning `<tool d="...">` diametrini o'z ichiga oladi. Shu
yerdan butun mahsulot bo'yicha diametr bo'yicha guruhlangan umumiy teshik
soni hisoblanadi (bitta detalning teshiklari shu detal necha dona
kerakligiga — `part count` — ko'paytiriladi).
"""

import re
import xml.etree.ElementTree as ET
from collections import Counter
from dataclasses import dataclass, field


@dataclass
class BazisPart:
    name: str
    length: float
    width: float
    count: int


@dataclass
class BazisImportResult:
    product_name: str = ""
    parts: list = field(default_factory=list)
    # material nomi -> shu materialdan kesiladigan detallar soni (dona)
    sheet_usage: "Counter" = field(default_factory=Counter)
    # kromka nomi -> shu kromka bilan qoplanadigan qirralar umumiy uzunligi (metr)
    band_usage: "Counter" = field(default_factory=Counter)
    # Armatura (evro/ekssentrik/polka) bo'yicha guruhlangan TO'LOV birliklari
    # — qarang `_apply_hardware_grouping`. Xom (diametr bo'yicha) teshik
    # sonlari emas, balki usta HAQIQATDA nechta ISHNI bajarganini aks
    # ettiradi (bitta biriktirgich bir nechta jismoniy teshikdan iborat
    # bo'lsa ham, bir marta hisoblanadi).
    hole_groups: "Counter" = field(default_factory=Counter)


def _decode(raw: bytes) -> str:
    """Fayl deklaratsiya qilgan kodировkani (odatda windows-1251) o'qib,
    ElementTree har doim to'g'ri tushunadigan UTF-8'ga o'giradi."""
    head = raw[:200].decode("ascii", errors="ignore")
    m = re.search(r'encoding="([\w-]+)"', head)
    encoding = m.group(1) if m else "utf-8"
    text = raw.decode(encoding, errors="replace")
    return re.sub(r'encoding="[\w-]+"', 'encoding="utf-8"', text, count=1)


def _diameter_label(tool_name: str, diameter: str | None) -> str:
    """Asbob nomi/diametridan foydalanuvchiga tushunarli yorliq hosil qiladi:
    "Bore8" (d=8) -> "Ø8mm"; "BoreTh7" (o'tuvchi, d=7) -> "Ø7mm (o'tuvchi)"."""
    if diameter is None:
        num = re.search(r"[\d.]+", tool_name)
        diameter = num.group(0) if num else "?"
    label = f"Ø{diameter}mm"
    if re.search(r"th", tool_name, re.IGNORECASE):
        label += " (o'tuvchi)"
    return label


EVRO_LABEL = "Evro (konfirmat) biriktirgich"
EKSENTRIK_LABEL = "Ekssentrik (minifiks) biriktirgich"
POLKA_LABEL = "Polka derjateli"

_EVRO_RAW_LABEL = "Ø7mm (o'tuvchi)"
_EKSENTRIK_RAW_LABEL = "Ø15mm"
_EKSENTRIK_SIDE_LABEL = "Ø8mm"
_EKSENTRIK_PILOT_LABEL = "Ø4.5mm"


def _apply_hardware_grouping(raw_hole_groups: "Counter") -> "Counter":
    """Xom (faqat diametr bo'yicha) teshik sonlarini haqiqiy mebel
    armaturasi (usta ishlatadigan biriktirgich turlari) bo'yicha TO'LOV
    birliklariga aylantiradi — usta diametr uchun emas, BIRIKTIRGICH uchun
    ish haqi olishi kerak (foydalanuvchi tasdiqlagan qoida):

      - **Evro** (konfirmat shurup): ikkita detalda ikki xil diametrda
        teshiladi, lekin ikkalasi BITTA biriktirgich — faqat doimiy
        belgisi (Ø7mm o'tuvchi teshik) orqali sanaladi, chunki ikkinchi
        teshikning diametri qat'iy emas (armatura turiga qarab farqlanadi).
      - **Ekssentrik** (minifiks): 3 ta jismoniy teshik — Ø15mm (korpus)
        + Ø8mm (bir xil detalda) + Ø4.5mm (ikkinchi detalda) — BITTA
        biriktirgich, Ø15mm soniga teng sanaladi.
      - Ekssentrikka "yutilgan" Ø8mm/Ø4.5mm teshiklar (ekssentrik soniga
        teng miqdorda) alohida to'lanmaydi. Ø8mm'dan ORTIG'I (agar
        ekssentrikka sig'masa) YO'QOTILMAYDI — xavfsizlik uchun alohida
        "Ø8mm" guruhi sifatida qoladi (aks holda usta bajargan ish
        kuzatuvsiz, pulsiz qolib ketishi mumkin edi).
      - Ø4.5mm'dan ekssentrikka yutilganidan QOLGANI — mustaqil holdagi
        **Polka derjateli** teshiklari, har biri ALOHIDA to'lanadi.
      - Boshqa barcha diametrlar (Ø3mm, Ø5mm, Ø20mm, Ø35mm va h.k.) —
        armatura qoidasi berilmagani uchun o'zgarishsiz, diametr bo'yicha
        alohida guruh sifatida qoladi."""
    groups: Counter = Counter()

    evro = raw_hole_groups.get(_EVRO_RAW_LABEL, 0)
    if evro:
        groups[EVRO_LABEL] = evro

    eksentrik = raw_hole_groups.get(_EKSENTRIK_RAW_LABEL, 0)
    if eksentrik:
        groups[EKSENTRIK_LABEL] = eksentrik

    leftover_side = raw_hole_groups.get(_EKSENTRIK_SIDE_LABEL, 0) - eksentrik
    if leftover_side > 0:
        groups[_EKSENTRIK_SIDE_LABEL] = leftover_side

    polka = raw_hole_groups.get(_EKSENTRIK_PILOT_LABEL, 0) - eksentrik
    if polka > 0:
        groups[POLKA_LABEL] = polka

    handled = {_EVRO_RAW_LABEL, _EKSENTRIK_RAW_LABEL, _EKSENTRIK_SIDE_LABEL, _EKSENTRIK_PILOT_LABEL}
    for label, count in raw_hole_groups.items():
        if label not in handled:
            groups[label] = count

    return groups


def parse_bazis_project(raw: bytes) -> BazisImportResult:
    root = ET.fromstring(_decode(raw).encode("utf-8"))
    result = BazisImportResult()

    product_good = root.find('.//good[@typeId="product"]')
    if product_good is not None:
        result.product_name = product_good.get("name", "")
        for part_el in product_good.findall("part"):
            try:
                length = float(part_el.get("dl") or 0)
                width = float(part_el.get("dw") or 0)
                count = int(float(part_el.get("count") or 1))
            except ValueError:
                continue
            result.parts.append(
                BazisPart(name=part_el.get("name", ""), length=length, width=width, count=count)
            )

    part_counts = {p.name: p.count for p in result.parts}
    # id -> BazisPart.count (operatsiyalar part'larni id orqali ko'rsatadi, nom orqali emas)
    id_to_count = {}
    if product_good is not None:
        for part_el in product_good.findall("part"):
            try:
                id_to_count[part_el.get("id")] = int(float(part_el.get("count") or 1))
            except ValueError:
                pass

    sheet_by_good_id = {}
    band_by_good_id = {}
    for good in root.findall("good"):
        type_id = good.get("typeId")
        if type_id == "sheet":
            sheet_by_good_id[good.get("id")] = good.get("name", "Noma'lum material")
        elif type_id == "band":
            band_by_good_id[good.get("id")] = good.get("name", "Noma'lum kromka")

    hole_groups: Counter = Counter()

    for op in root.findall("operation"):
        type_id = op.get("typeId")
        material_el = op.find("material")
        material_id = material_el.get("id") if material_el is not None else None
        op_part_ids = [p.get("id") for p in op.findall("part") if p.get("id")]

        if type_id == "CS" and material_id in sheet_by_good_id:
            sheet_name = sheet_by_good_id[material_id]
            for pid in op_part_ids:
                result.sheet_usage[sheet_name] += id_to_count.get(pid, 1)

        elif type_id == "EL" and material_id in band_by_good_id:
            band_name = band_by_good_id[material_id]
            for pid in op_part_ids:
                result.band_usage[band_name] += id_to_count.get(pid, 1)

        elif type_id == "XNC":
            program_xml = op.get("program")
            # XNC operatsiya ID'si part ID bilan bir xil emas (dastur alohida
            # id ketma-ketligida) — shu operatsiya aynan qaysi detalga
            # tegishli ekanini `typeName` (detal nomi bilan bir xil) orqali
            # topamiz, shu detalning nechta kerakligiga (`count`) ko'paytiramiz.
            part_count = part_counts.get(op.get("typeName", ""), 1)
            if not program_xml:
                continue
            try:
                prog_root = ET.fromstring(program_xml)
            except ET.ParseError:
                continue
            tool_diameter = {
                t.get("name"): t.get("d") for t in prog_root.findall("tool") if t.get("name")
            }
            for hole_el in list(prog_root.findall("bf")) + list(prog_root.findall("bl")):
                tool_name = hole_el.get("name", "")
                if not tool_name:
                    continue
                label = _diameter_label(tool_name, tool_diameter.get(tool_name))
                hole_groups[label] += part_count

    result.hole_groups = _apply_hardware_grouping(hole_groups)
    return result
