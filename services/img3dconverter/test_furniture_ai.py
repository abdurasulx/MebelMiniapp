import json
import pytest
from PIL import Image
from furniture_ai import AnalysisError, crop_view, effective_dimensions, parse_analysis


def response(**updates):
    data = {"is_furniture": True, "object_type": "chair",
            "views": [{"role": "front", "bbox": [0.2, 0.1, 0.8, 0.95], "confidence": 0.9}],
            "estimated_dimensions_cm": {"height": 110, "width": 65, "depth": 70},
            "warnings": []}
    data.update(updates)
    return json.dumps(data)


def test_user_targets_override_ai():
    dims, sources = effective_dimensions({"height": 120, "width": 80}, {"height": 90, "width": 60, "depth": 70})
    assert dims == {"height": 120, "width": 80, "depth": 70}
    assert sources["height"] == "user" and sources["depth"] == "ai_estimate"


@pytest.mark.parametrize("bad", [float("nan"), float("inf"), -1, 0, True, "100"])
def test_untrusted_dimensions_rejected(bad):
    dims, _ = effective_dimensions({}, {"height": bad})
    assert dims["height"] is None


def test_crop_is_padded_and_original_unchanged():
    image = Image.new("RGBA", (1000, 800), "white")
    cropped, applied = crop_view(image, {"bbox": [0.2, 0.1, 0.8, 0.95], "confidence": 0.9})
    assert applied and cropped.width > 600 and cropped.height > 680
    assert image.size == (1000, 800)


def test_low_confidence_keeps_original():
    image = Image.new("RGB", (500, 500))
    out, applied = crop_view(image, {"bbox": [0.2, 0.2, 0.6, 0.6], "confidence": 0.2})
    assert not applied and out.size == image.size


@pytest.mark.parametrize("box", [[0.8, 0, 0.2, 1], [0, 0, 2, 1], [0, 0, float('nan'), 1]])
def test_invalid_boxes_are_rejected(box):
    with pytest.raises(AnalysisError):
        parse_analysis(response(views=[{"role": "front", "bbox": box, "confidence": 0.9}]), ["front"])


def test_missing_view_rejected():
    with pytest.raises(AnalysisError):
        parse_analysis(response(), ["front", "back"])


def test_non_furniture_rejected():
    with pytest.raises(AnalysisError):
        parse_analysis(response(is_furniture=False), ["front"])


def test_valid_schema_and_fences():
    data = parse_analysis('```json\n' + response() + '\n```', ["front"])
    assert data["estimated_dimensions_cm"]["height"] == 110
    assert data["dimension_confidence"] == "low"


def test_explicit_dimensions_fit_all_axes(tmp_path):
    import trimesh
    from scale_model import scale_glb
    src, dst = tmp_path / "source.glb", tmp_path / "scaled.glb"
    trimesh.creation.box(extents=[1, 2, 1]).export(src)
    result = scale_glb(src, dst, 120, 80, 65, exact_dimensions=True)
    assert result["scale_mode"] == "exact"
    assert (result["width_cm"], result["height_cm"], result["depth_cm"]) == (80, 120, 65)
    assert not result["dimension_mismatch"]


def test_failed_ai_request_does_not_echo_credentials(monkeypatch, tmp_path):
    import furniture_ai
    import requests
    cfg = tmp_path / "config.json"
    cfg.write_text(json.dumps({"enabled": True, "api_key": "test-private-key"}))
    monkeypatch.setattr(furniture_ai, "CONFIG_PATH", cfg)
    monkeypatch.delenv("FURNITURE_AI_API_KEY", raising=False)
    def unavailable(*a, **k):
        raise requests.ConnectionError("sensitive upstream context")
    monkeypatch.setattr(requests, "post", unavailable)
    with pytest.raises(AnalysisError) as error:
        furniture_ai.analyze_and_prepare([("front", Image.new("RGB", (100, 100)))])
    assert "sensitive" not in str(error.value) and "private-key" not in str(error.value)
