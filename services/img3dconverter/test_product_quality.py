import json

import numpy as np
import pytest
import trimesh

import product_quality as quality


def test_preserves_disconnected_chair_legs_and_support():
    parts = [trimesh.creation.box([1, .1, 1]),
             trimesh.creation.box([1, 1, .1])]
    parts[1].apply_translation([0, .5, -.45])
    for x in [-.45, .45]:
        for z in [-.45, .45]:
            leg = trimesh.creation.box([.06, 1, .06])
            leg.apply_translation([x, -.55, z])
            parts.append(leg)
    chair = trimesh.util.concatenate(parts)
    prepared, _ = quality.texture_mesh(chair, 200000)
    assert len(prepared.faces) == sum(len(part.faces) for part in parts)
    np.testing.assert_allclose(prepared.vertices, chair.vertices)
    np.testing.assert_allclose(prepared.bounds, chair.bounds)


def test_texture_decimation_is_explicit_and_preserves_extent():
    sphere = trimesh.creation.icosphere(subdivisions=4)
    prepared, details = quality.texture_mesh(sphere, 2000)
    assert len(prepared.faces) <= 2000
    assert details["before"]["faces"] > details["after"]["faces"]
    np.testing.assert_allclose(prepared.bounds, sphere.bounds, atol=.02)


def test_rejects_decimation_that_loses_product_extremities(monkeypatch):
    monkeypatch.setattr(trimesh.Trimesh, "simplify_quadric_decimation",
                        lambda self, **kwargs: trimesh.creation.box([.1, .1, .1]))
    with pytest.raises(ValueError, match="bounds"):
        quality.texture_mesh(trimesh.creation.icosphere(), 10)


def test_rejects_invalid_geometry():
    mesh = trimesh.creation.box()
    mesh.vertices[0] = [np.nan, 0, 0]
    with pytest.raises(ValueError, match="invalid"):
        quality.mesh_info(mesh)


def test_preserves_completed_history_without_raw_image_bytes(tmp_path, monkeypatch):
    monkeypatch.setattr(quality, "HISTORY", tmp_path / "history.json")
    quality.save_completed({
        "a": {"id": "a", "status": "done", "client": "owner", "images": b"private"},
        "b": {"id": "b", "status": "queued", "images": b"pending"},
        "c": {"id": "c", "status": "error", "error": "failed"},
    })
    restored = quality.load_completed()
    assert set(restored) == {"a", "c"}
    assert restored["a"]["client"] == "owner"
    assert restored["a"]["images"] is None
    assert "private" not in quality.HISTORY.read_text()


def test_config_rejects_excessive_resolution(tmp_path, monkeypatch):
    config = quality.settings()
    config["shape_resolution"] = 4096
    (tmp_path / "hunyuan_product.json").write_text(json.dumps(config))
    monkeypatch.setattr(quality, "ROOT", tmp_path)
    with pytest.raises(ValueError, match="shape_resolution"):
        quality.settings()


def test_does_not_mistake_cabinet_bottom_for_floor():
    cabinet = trimesh.creation.box([2, 2, 2])
    output, info = quality.remove_generated_floor(cabinet)
    assert info["removed_faces"] == 0
    np.testing.assert_allclose(output.vertices, cabinet.vertices)


def test_floor_cleanup_preserves_wheel_below_floor_and_other_components():
    floor = trimesh.creation.box([2, .01, 2])
    floor.apply_translation([0, -.65, 0])
    body = trimesh.creation.box([.6, .8, .6])
    body.apply_translation([0, .1, 0])
    wheel = trimesh.creation.box([.08, .1, .08])
    wheel.apply_translation([.2, -.72, .2])
    mesh = trimesh.util.concatenate([floor, body, wheel])
    output, info = quality.remove_generated_floor(mesh)
    assert info["removed_faces"] > 0
    assert output.bounds[0, 1] == pytest.approx(wheel.bounds[0, 1])
    assert output.bounds[1, 1] == pytest.approx(body.bounds[1, 1])
    np.testing.assert_allclose(output.extents[[0, 2]], body.extents[[0, 2]])


def test_rejects_obscured_product_before_gpu_generation():
    from furniture_ai import AnalysisError, parse_analysis
    with pytest.raises(AnalysisError, match="to‘liq"):
        parse_analysis(json.dumps({"is_furniture": True, "reconstruction_ready": False}), ["front"])


def test_recovers_only_complete_result_after_truncated_gateway_prefix():
    from furniture_ai import parse_analysis
    result = {"is_furniture": True, "reconstruction_ready": True,
              "views": [{"role": "front", "bbox": [.1, .1, .9, .9], "confidence": .9}]}
    parsed = parse_analysis('{"is_furniture":true,"views":[```json\n' + json.dumps(result), ["front"])
    assert parsed["response_format_recovered"] is True
    assert parsed["views"][0]["bbox"] == [.1, .1, .9, .9]


def test_rejects_two_conflicting_complete_gateway_objects():
    from furniture_ai import AnalysisError, parse_analysis
    first = {"is_furniture": True, "object_type": "chair", "views": []}
    second = dict(first, object_type="table")
    with pytest.raises(AnalysisError, match="JSON"):
        parse_analysis(json.dumps(first) + json.dumps(second), ["front"])
