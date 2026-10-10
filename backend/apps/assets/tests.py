import io
import json
import struct

from django.test import TestCase

from .geometry import classify_shape, extract_bbox


def make_glb(accessors, meshes=None):
    """Minimal GLB fayl (faqat JSON chunk, BIN kerak emas — biz faqat
    accessor.min/max metama'lumotini o'qiymiz)."""
    gltf = {
        "asset": {"version": "2.0"},
        "accessors": accessors,
        "meshes": meshes
        if meshes is not None
        else [{"primitives": [{"attributes": {"POSITION": 0}}]}],
    }
    json_bytes = json.dumps(gltf).encode("utf-8")
    padding = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * padding

    header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(json_bytes))
    chunk_header = struct.pack("<I4s", len(json_bytes), b"JSON")
    return io.BytesIO(header + chunk_header + json_bytes)


class GeometryTests(TestCase):
    def test_extract_bbox_from_valid_glb(self):
        glb = make_glb([{"min": [0.0, 0.0, 0.0], "max": [0.5, 1.0, 0.3]}])
        bbox = extract_bbox(glb)
        self.assertEqual(bbox, {"width": 0.5, "height": 1.0, "depth": 0.3})

    def test_extract_bbox_aggregates_multiple_primitives(self):
        glb = make_glb(
            [
                {"min": [-0.2, 0.0, 0.0], "max": [0.2, 0.5, 0.1]},
                {"min": [0.0, 0.4, -0.1], "max": [0.3, 1.2, 0.1]},
            ],
            meshes=[
                {
                    "primitives": [
                        {"attributes": {"POSITION": 0}},
                        {"attributes": {"POSITION": 1}},
                    ]
                }
            ],
        )
        bbox = extract_bbox(glb)
        # X: -0.2..0.3 -> 0.5, Y: 0..1.2 -> 1.2, Z: -0.1..0.1 -> 0.2
        self.assertEqual(bbox, {"width": 0.5, "height": 1.2, "depth": 0.2})

    def test_non_glb_file_returns_none(self):
        self.assertIsNone(extract_bbox(io.BytesIO(b"not a glb file")))

    def test_glb_without_position_accessors_returns_none(self):
        glb = make_glb([], meshes=[])
        self.assertIsNone(extract_bbox(glb))

    def test_classify_shape_tall(self):
        self.assertEqual(classify_shape({"width": 0.5, "height": 1.8, "depth": 0.5}), "baland")

    def test_classify_shape_wide(self):
        self.assertEqual(classify_shape({"width": 2.0, "height": 0.5, "depth": 0.6}), "keng")

    def test_classify_shape_deep(self):
        self.assertEqual(classify_shape({"width": 0.5, "height": 0.5, "depth": 1.5}), "chuqur")

    def test_classify_shape_cube_like(self):
        self.assertEqual(classify_shape({"width": 0.5, "height": 0.55, "depth": 0.5}), "kub_simon")

    def test_classify_shape_handles_missing_bbox(self):
        self.assertEqual(classify_shape(None), "")


class ZipWithoutBlenderTests(TestCase):
    """ZIP ichidagi tayyor GLB Blender'siz serverda ham `ready` bo'lishi kerak."""

    def _model_from_zip(self, files):
        import zipfile
        from io import BytesIO

        from django.core.files.base import ContentFile
        from django.core.management import call_command

        from apps.assets.models import Model3D

        buf = BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            for name, data in files.items():
                zf.writestr(name, data)
        m = Model3D()
        m.glb_file.save("model.zip", ContentFile(buf.getvalue()), save=False)
        m.status = Model3D.Status.PROCESSING
        m.save()
        from unittest import mock

        with mock.patch("shutil.which", return_value=None):
            call_command("process_model3d", str(m.id))
        m.refresh_from_db()
        return m

    def test_zip_with_glb_becomes_ready_without_blender(self):
        glb = make_glb([{"min": [0.0, 0.0, 0.0], "max": [0.5, 1.0, 0.3]}]).getvalue()
        m = self._model_from_zip({"folder/chair.glb": glb, "folder/readme.txt": b"x"})
        self.assertEqual(m.status, "ready")
        self.assertTrue(m.glb_file.name.endswith(".glb"))
        self.assertAlmostEqual(float(m.bbox_height), 1.0, places=2)

    def test_zip_with_only_fbx_fails_with_clear_state_without_blender(self):
        m = self._model_from_zip({"chair.fbx": b"FBX"})
        self.assertEqual(m.status, "failed")
