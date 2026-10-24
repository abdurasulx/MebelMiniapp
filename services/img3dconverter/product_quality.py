"""Reproducible product reconstruction without destructive plane removal."""
import json
import os
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
HISTORY = Path.home() / ".local/share/imageto3d/completed-jobs.json"


def settings():
    cfg = json.loads((ROOT / "hunyuan_product.json").read_text(encoding="utf8"))
    for key, lo, hi in [("seed", 0, 2147483647), ("shape_steps", 20, 100),
                        ("shape_resolution", 256, 512), ("shape_chunks", 1000, 16000),
                        ("texture_views", 4, 8), ("texture_resolution", 448, 768),
                        ("texture_size", 1024, 4096), ("texture_face_limit", 40000, 1000000)]:
        value = cfg.get(key)
        if isinstance(value, bool) or not isinstance(value, int) or not lo <= value <= hi:
            raise ValueError("Invalid product setting: " + key)
    if not 1 <= cfg["shape_guidance"] <= 10:
        raise ValueError("Invalid shape guidance")
    return cfg


def mesh_info(mesh):
    bounds = np.asarray(mesh.bounds)
    if (len(mesh.faces) == 0 or not np.isfinite(mesh.vertices).all()
            or bounds.shape != (2, 3) or not (np.diff(bounds, axis=0) > 0).all()):
        raise ValueError("Generated mesh is empty or has invalid geometry")
    return {"vertices": len(mesh.vertices), "faces": len(mesh.faces),
            "bounds": bounds.tolist(), "extents": mesh.extents.tolist()}


def texture_mesh(mesh, face_limit):
    """Bound UV/render memory explicitly; never select only the largest component."""
    before = mesh_info(mesh)
    result = mesh.copy()
    if len(result.faces) > face_limit:
        result = result.simplify_quadric_decimation(face_count=face_limit)
    after = mesh_info(result)
    # Reject excessive geometry loss instead of silently returning a chopped model.
    tolerance = np.asarray(before["extents"]) * 0.01
    if np.any(np.abs(np.asarray(after["bounds"]) - before["bounds"]) > tolerance):
        raise ValueError("Texture simplification changed object bounds by more than 1%")
    return result, {"before": before, "after": after, "face_limit": face_limit}


def remove_generated_floor(mesh):
    """Remove a clipped, oversized horizontal floor; retain disconnected supports.

    Only a low horizontal sheet spanning the Hunyuan extraction box and much
    wider than the object qualifies. Seats, backs, cabinet bases and unconfirmed
    planes are left alone. This operates on normalized, unscaled model output.
    """
    before = mesh_info(mesh)
    bounds = mesh.bounds
    height = mesh.extents[1]
    vertices = mesh.vertices[mesh.faces]
    centers = mesh.triangles_center
    horizontal = np.abs(mesh.face_normals[:, 1]) > .95
    low = centers[:, 1] < bounds[0, 1] + height * .25
    candidates = horizontal & low
    diagnostics = {"removed_faces": 0, "before": before}
    if not candidates.any():
        return mesh, diagnostics
    weights, edges = np.histogram(centers[candidates, 1], bins=100,
                                 weights=mesh.area_faces[candidates])
    peak = int(weights.argmax())
    y = float((edges[peak] + edges[peak + 1]) / 2)
    tolerance = height * .025
    band = np.max(np.abs(vertices[:, :, 1] - y), axis=1) < tolerance
    sheet = band & horizontal
    if not sheet.any():
        return mesh, diagnostics
    sheet_vertices = vertices[sheet].reshape(-1, 3)
    sheet_bounds = np.array([sheet_vertices.min(axis=0), sheet_vertices.max(axis=0)])
    upper = mesh.vertices[mesh.vertices[:, 1] > y + height * .08]
    if not len(upper):
        return mesh, diagnostics
    upper_bounds = np.array([upper.min(axis=0), upper.max(axis=0)])
    sheet_span = np.diff(sheet_bounds, axis=0)[0, [0, 2]]
    upper_span = np.diff(upper_bounds, axis=0)[0, [0, 2]]
    clipped = (sheet_bounds[0, [0, 2]] < -.97).all() and (sheet_bounds[1, [0, 2]] > .97).all()
    if (not clipped or not (sheet_span > upper_span * 1.5).all()
            or mesh.area_faces[sheet].sum() < .25 * np.prod(sheet_span)):
        return mesh, diagnostics
    center = upper_bounds.mean(axis=0)[[0, 2]]
    radius = upper_span * .75  # generous support/caster margin
    outside = np.any(np.abs(centers[:, [0, 2]] - center) > radius, axis=1)
    drop = sheet | (band & outside)
    result = mesh.copy()
    result.update_faces(~drop)
    result.remove_unreferenced_vertices()
    # Never split and keep only the largest piece: wheels may be disconnected.
    diagnostics.update(removed_faces=int(drop.sum()), plane_y=y,
                       after=mesh_info(result))
    return result, diagnostics


def load_completed():
    if not HISTORY.exists():
        return {}
    rows = json.loads(HISTORY.read_text(encoding="utf8"))
    return {row["id"]: dict(row, images=None) for row in rows
            if row.get("status") in ("done", "error")}


def save_completed(jobs):
    HISTORY.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    rows = [{k: v for k, v in row.items() if k != "images"}
            for row in list(jobs.values()) if row.get("status") in ("done", "error")]
    temporary = HISTORY.with_suffix(".tmp")
    temporary.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf8")
    os.chmod(temporary, 0o600)
    temporary.replace(HISTORY)
