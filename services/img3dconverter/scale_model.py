"""GLB modelni haqiqiy o'lchamga keltirish (uniform masshtab, Y o'qi = balandlik)."""
import logging

import numpy as np
import trimesh

log = logging.getLogger("scale_model")
MISMATCH_TOL = 0.15


def compute_scale(real_height_m, mesh_height):
    if mesh_height <= 1e-9:
        raise ValueError("Model balandligi nolga teng")
    if real_height_m <= 0:
        raise ValueError("Haqiqiy balandlik musbat bo'lishi kerak")
    return real_height_m / mesh_height


def place_on_floor(scene):
    """min Y = 0, X/Z bo'yicha markazlash."""
    b = scene.bounds
    shift = np.array([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
    scene.apply_translation(shift)


def dimension_mismatch(dims_cm, real_width_cm=None, real_depth_cm=None, tol=MISMATCH_TOL):
    """dims_cm = (en, bo'y, chuqurlik). Kiritilgan qiymatlardan tol dan ko'p farq qilsa True."""
    bad = False
    for got, want, label in ((dims_cm[0], real_width_cm, "en"), (dims_cm[2], real_depth_cm, "chuqurlik")):
        if want and abs(got - want) / want > tol:
            log.warning("dimension_mismatch: %s model=%.1f sm, kiritilgan=%.1f sm", label, got, want)
            bad = True
    return bad


def scale_glb(src, dst, real_height_cm, real_width_cm=None, real_depth_cm=None, exact_dimensions=False):
    scene = trimesh.load(src, force="scene")
    b = scene.bounds
    k = compute_scale(real_height_cm / 100.0, float(b[1][1] - b[0][1]))
    scene.apply_scale(k)  # standart holatda proporsiya saqlanadi
    factors = np.array([k, k, k])
    if exact_dimensions:
        if not real_width_cm or not real_depth_cm:
            raise ValueError("Aniq moslash uchun uchala o‘lcham kerak")
        ext = scene.bounds[1] - scene.bounds[0]
        target = np.array([real_width_cm, real_height_cm, real_depth_cm], dtype=float) / 100
        if not np.isfinite(target).all() or (target <= 0).any() or (ext <= 1e-9).any():
            raise ValueError("O‘lchamlar noto‘g‘ri")
        correction = target / ext
        scene.apply_scale(correction)
        factors *= correction
    place_on_floor(scene)
    scene.export(dst, file_type="glb")
    ext = scene.bounds[1] - scene.bounds[0]
    w, h, d = (float(x) * 100 for x in ext)
    return dict(
        scale=k,
        scale_mode="exact" if exact_dimensions else "uniform",
        scale_factors=factors.tolist(),
        width_cm=round(w, 1),
        height_cm=round(h, 1),
        depth_cm=round(d, 1),
        volume_m3=round(float(np.prod(ext)), 3),
        dimension_mismatch=dimension_mismatch((w, h, d), real_width_cm, real_depth_cm),
    )
