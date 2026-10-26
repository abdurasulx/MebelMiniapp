"""Private server-side furniture analysis. Does not generate or redesign images."""
import base64
import io
import json
import math
import os
import re
from pathlib import Path

import requests
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = Path(os.environ.get(
    "FURNITURE_AI_CONFIG", str(Path.home() / ".config/imageto3d/ai.json")))


class AnalysisError(RuntimeError):
    pass


def settings():
    try:
        data = json.loads(CONFIG_PATH.read_text())
    except FileNotFoundError:
        data = {}
    return {
        "enabled": bool(data.get("enabled", False)),
        "base_url": data.get("base_url", "https://api.burchaksoft.uz/v1").rstrip("/"),
        "api_key": os.environ.get("FURNITURE_AI_API_KEY") or data.get("api_key", ""),
        "model": data.get("model", "sable-3.5"),
        "set_model": data.get("set_model", data.get("model", "sable-3.5")),
        "timeout": min(180, max(10, int(data.get("timeout", 150)))),
    }


def enabled():
    cfg = settings()
    return cfg["enabled"] and bool(cfg["api_key"])


def dimension(value):
    if isinstance(value, bool) or not isinstance(value, (float, int)):
        return None
    return float(value) if math.isfinite(value) and 0 < value <= 5000 else None


def effective_dimensions(user, estimated):
    """Explicit targets always win; guesses remain tagged as estimates."""
    result, sources = {}, {}
    for key in ("width", "height", "depth"):
        manual = dimension(user.get(key))
        guess = dimension(estimated.get(key))
        result[key] = manual if manual is not None else guess
        sources[key] = "user" if manual is not None else "ai_estimate" if guess else "unknown"
    return result, sources


def parse_analysis(content, roles):
    if not isinstance(content, str) or len(content) > 32000:
        raise AnalysisError("AI javobi noto'g'ri formatda")
    text = content.strip()
    if text.startswith("```") and text.endswith("```"):
        text = text.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
    recovered = False
    try:
        result = json.loads(text)
    except (ValueError, TypeError, RecursionError):
        # Some gateway responses contain a truncated streaming prefix followed
        # by the final object. Accept one complete furniture result only;
        # conflicting complete responses must never be guessed between.
        decoder = json.JSONDecoder()
        candidates = {}
        for match in list(re.finditer(r"\{", text))[:128]:
            try:
                obj, _ = decoder.raw_decode(text, match.start())
            except (ValueError, RecursionError):
                continue
            if isinstance(obj, dict) and "is_furniture" in obj:
                candidates[json.dumps(obj, sort_keys=True)] = obj
        if len(candidates) != 1:
            raise AnalysisError("AI JSON formatida javob bermadi") from None
        result = next(iter(candidates.values()))
        recovered = True
    if isinstance(result, dict) and recovered:
        result["response_format_recovered"] = True
    if not isinstance(result, dict) or result.get("is_furniture") is not True:
        raise AnalysisError("AI kerakli mebelni aniq ajrata olmadi; yaqinroq rasm yuboring")
    if result.get("reconstruction_ready") is False:
        raise AnalysisError("Mebelning to‘liq tuzilishi ko‘rinmayapti. Mebelni oyoqlari va suyanchig‘i bilan to‘liq, old yoki yon tomondan qayta suratga oling")
    if "reconstruction_ready" in result and not isinstance(result["reconstruction_ready"], bool):
        raise AnalysisError("AI rekonstruksiya sifatini noto‘g‘ri formatda qaytardi")
    views = result.get("views")
    if not isinstance(views, list) or len(views) != len(roles):
        raise AnalysisError("AI barcha ko'rinishlarni qaytarmadi")
    seen = set()
    for view in views:
        if not isinstance(view, dict) or view.get("role") not in roles or view["role"] in seen:
            raise AnalysisError("AI rasm rollarini noto'g'ri qaytardi")
        seen.add(view["role"])
        # Gemini's documented grounding format is YXYX / 0..1000. Accept
        # that explicit field, never guess units/order from an unlabeled bbox.
        native = view.get("box_2d")
        if native is not None:
            if (not isinstance(native, list) or len(native) != 4
                    or any(isinstance(v, bool) or not isinstance(v, (int, float))
                           or not math.isfinite(v) or not 0 <= v <= 1000 for v in native)
                    or not native[0] < native[2] or not native[1] < native[3]):
                raise AnalysisError("AI box_2d chegaralari noto'g'ri")
            canonical = [native[1] / 1000, native[0] / 1000,
                         native[3] / 1000, native[2] / 1000]
            if view.get("bbox") is not None and view["bbox"] != canonical:
                raise AnalysisError("AI kesish koordinatalari bir-biriga zid")
            view["bbox"] = canonical
        box = view.get("bbox")
        if box is not None:
            if (not isinstance(box, list) or len(box) != 4
                    or any(isinstance(v, bool) or not isinstance(v, (int, float))
                           or not math.isfinite(v) or not 0 <= v <= 1 for v in box)
                    or not box[0] < box[2] or not box[1] < box[3]):
                raise AnalysisError("AI kesish chegaralari noto'g'ri")
        confidence = view.get("confidence", 0)
        view["confidence"] = (float(confidence) if isinstance(confidence, (int, float))
                              and not isinstance(confidence, bool)
                              and math.isfinite(confidence) and 0 <= confidence <= 1 else 0)
    estimates = result.get("estimated_dimensions_cm")
    if not isinstance(estimates, dict):
        estimates = {}
    result["estimated_dimensions_cm"] = {k: dimension(estimates.get(k)) for k in ("width", "height", "depth")}
    result["dimension_confidence"] = (result.get("dimension_confidence")
                                      if result.get("dimension_confidence") in ("low", "medium", "high") else "low")
    result["object_type"] = str(result.get("object_type", "furniture"))[:100]
    result["description"] = str(result.get("description", ""))[:1500]
    warnings = result.get("warnings", [])
    result["warnings"] = [w[:300] for w in warnings[:10] if isinstance(w, str)] if isinstance(warnings, list) else []
    return result


def crop_view(image, view):
    """Conservative crop from the original resolution, with safety padding."""
    box = view.get("bbox")
    if box is None or view["confidence"] < 0.65:
        return image.copy(), False
    left, top, right, bottom = box
    if (right - left) * (bottom - top) < 0.025:
        return image.copy(), False
    padding = 0.035
    w, h = image.size
    pixels = (max(0, int((left - padding) * w)), max(0, int((top - padding) * h)),
              min(w, math.ceil((right + padding) * w)), min(h, math.ceil((bottom + padding) * h)))
    if pixels[2] - pixels[0] < 32 or pixels[3] - pixels[1] < 32:
        return image.copy(), False
    return image.crop(pixels), True


def analyze_and_prepare(images, user_dimensions=None, reconstruction_scope="single"):
    if reconstruction_scope not in ("single", "set"):
        raise AnalysisError("Rekonstruksiya turi noto'g'ri")
    cfg = settings()
    if not cfg["enabled"] or not cfg["api_key"]:
        raise AnalysisError("AI tahlili serverda sozlanmagan")
    if reconstruction_scope == "set":
        cfg = dict(cfg, model=cfg.get("set_model", cfg["model"]))
    user_dimensions = user_dimensions or {}
    roles = [role for role, _ in images]
    content = [{"type": "text", "text": json.dumps({
        "task": "Locate the requested furniture, suggest dimensions and prepare crop coordinates.",
        "reconstruction_scope": reconstruction_scope,
        "view_roles": roles, "user_target_dimensions_cm": user_dimensions,
    })}]
    originals = []
    for role, im in images:
        original = ImageOps.exif_transpose(im).convert("RGBA")
        originals.append((role, original))
        thumbnail = original.copy()
        thumbnail.thumbnail((1280, 1280))
        rgb = Image.new("RGB", thumbnail.size, "white")
        rgb.paste(thumbnail, mask=thumbnail.getchannel("A"))
        out = io.BytesIO()
        rgb.save(out, format="JPEG", quality=88)
        content.extend([{"type": "text", "text": "View role: " + role}, {
            "type": "image_url", "image_url": {
                "url": "data:image/jpeg;base64," + base64.b64encode(out.getvalue()).decode("ascii")}}])
    body = {"model": cfg["model"], "stream": False, "max_tokens": 1800,
            "messages": [{"role": "system", "content": (ROOT / "furniture_intake_system.txt").read_text()},
                         {"role": "user", "content": content}]}
    try:
        response = requests.post(cfg["base_url"] + "/chat/completions", json=body,
                                 headers={"Authorization": "Bearer " + cfg["api_key"]},
                                 timeout=(10, cfg["timeout"]), allow_redirects=False)
    except requests.RequestException:
        raise AnalysisError("AI bilan ulanish uzildi yoki kutish vaqti tugadi; qayta urinib ko'ring") from None
    if response.status_code != 200:
        raise AnalysisError("AI tahlili bajarilmadi (HTTP %d)" % response.status_code)
    try:
        raw = response.json()["choices"][0]["message"]["content"]
    except (ValueError, KeyError, IndexError, TypeError):
        raise AnalysisError("AI javobida tahlil natijasi yo'q") from None
    analysis = parse_analysis(raw, roles)
    analysis["reconstruction_scope"] = reconstruction_scope
    views = {v["role"]: v for v in analysis["views"]}
    prepared = []
    for role, image in originals:
        if reconstruction_scope == "set":
            # A group box can omit a foreground bench/stool. Preserve the
            # whole frame until foreground extraction; never clip set pieces.
            cropped, applied = image.copy(), False
            views[role]["crop_policy"] = "preserve_complete_set"
        else:
            cropped, applied = crop_view(image, views[role])
        views[role]["crop_applied"] = applied
        prepared.append((role, cropped))
        if not applied and reconstruction_scope == "single":
            analysis["warnings"].append(role + ": ishonchli kesish aniqlanmadi, asl rasm saqlandi")
    analysis["effective_dimensions_cm"], analysis["dimension_sources"] = effective_dimensions(
        user_dimensions, analysis["estimated_dimensions_cm"])
    analysis["model"] = cfg["model"]
    return prepared, analysis
