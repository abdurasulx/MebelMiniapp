import numpy as np
import trimesh
from PIL import Image

import scale_model as sm


def make_glb(path, ext=(1.03, 1.93, 1.09), offset=(0.3, -0.9, 0.2), textured=True):
    m = trimesh.creation.box(extents=ext)
    m.apply_translation(offset)
    if textured:
        uv = np.random.rand(len(m.vertices), 2)
        tex = Image.fromarray((np.random.rand(16, 16, 3) * 255).astype("uint8"))
        m.visual = trimesh.visual.TextureVisuals(uv=uv, material=trimesh.visual.material.PBRMaterial(baseColorTexture=tex))
    m.export(path)


def test_compute_scale():
    assert abs(sm.compute_scale(1.2, 1.93) - 1.2 / 1.93) < 1e-12


def test_office_chair_example(tmp_path):
    make_glb(tmp_path / "a.glb")
    r = sm.scale_glb(tmp_path / "a.glb", tmp_path / "b.glb", 120)
    assert r["height_cm"] == 120.0
    assert abs(r["width_cm"] - 64) < 1 and abs(r["depth_cm"] - 68) < 1
    assert abs(r["volume_m3"] - 0.52) < 0.02


def test_floor_and_center(tmp_path):
    make_glb(tmp_path / "a.glb")
    sm.scale_glb(tmp_path / "a.glb", tmp_path / "b.glb", 100)
    b = trimesh.load(tmp_path / "b.glb", force="scene").bounds
    assert abs(b[0][1]) < 1e-6
    assert abs(b[0][0] + b[1][0]) < 1e-6 and abs(b[0][2] + b[1][2]) < 1e-6


def test_uniform_proportions(tmp_path):
    make_glb(tmp_path / "a.glb")
    sm.scale_glb(tmp_path / "a.glb", tmp_path / "b.glb", 50)
    e0 = trimesh.load(tmp_path / "a.glb", force="scene").extents
    e1 = trimesh.load(tmp_path / "b.glb", force="scene").extents
    assert np.allclose(e1 / e1[1], e0 / e0[1], atol=1e-5)


def test_mismatch():
    assert sm.dimension_mismatch((64, 120, 68), 80, 68)
    assert not sm.dimension_mismatch((64, 120, 68), 66, 70)
    assert not sm.dimension_mismatch((64, 120, 68))


def test_mismatch_does_not_stop(tmp_path):
    make_glb(tmp_path / "a.glb")
    r = sm.scale_glb(tmp_path / "a.glb", tmp_path / "b.glb", 120, real_width_cm=100)
    assert r["dimension_mismatch"] is True and (tmp_path / "b.glb").exists()


def test_texture_preserved(tmp_path):
    make_glb(tmp_path / "a.glb")
    sm.scale_glb(tmp_path / "a.glb", tmp_path / "b.glb", 120)
    s = trimesh.load(tmp_path / "b.glb", force="scene")
    mat = list(s.geometry.values())[0].visual.material
    assert mat.baseColorTexture is not None
