import shutil
import subprocess
import tempfile
from pathlib import Path

from django.core.files import File
from django.core.management.base import BaseCommand, CommandError

from apps.assets.models import Model3D


class Command(BaseCommand):
    """GLB'dan Blender orqali USDZ generatsiya qiladi (iOS AR Quick Look uchun).

    Firma kompaniyalari Reality Converter yoki Blender'ni qo'lda ishlatmasin
    uchun — GLB yuklanganda `Model3DSerializer.save()` shu buyruqni alohida OS
    jarayonida (subprocess.Popen, HTTP javobini bloklamasdan) ishga tushiradi.
    """

    help = "Berilgan Model3D uchun GLB'dan USDZ generatsiya qiladi."

    def add_arguments(self, parser):
        parser.add_argument("model3d_id", type=str)

    def handle(self, *args, **options):
        model3d_id = options["model3d_id"]
        try:
            model = Model3D.objects.get(id=model3d_id, is_deleted=False)
        except Model3D.DoesNotExist:
            raise CommandError(f"Model3D topilmadi: {model3d_id}")

        if not model.glb_file:
            model.status = Model3D.Status.FAILED
            model.save(update_fields=["status"])
            raise CommandError("GLB fayl yo'q")

        blender_bin = shutil.which("blender")
        if not blender_bin:
            self.stderr.write("Blender topilmadi (PATH'da yo'q) — USDZ generatsiya qilinmadi")
            model.status = Model3D.Status.FAILED
            model.save(update_fields=["status"])
            return

        script_path = Path(__file__).resolve().parents[4] / "scripts" / "glb_to_usdz.py"
        glb_path = Path(model.glb_file.path)

        with tempfile.TemporaryDirectory() as tmp_dir:
            usdz_tmp_path = Path(tmp_dir) / f"{model.id}.usdz"
            result = subprocess.run(
                [blender_bin, "--background", "--python", str(script_path),
                 "--", str(glb_path), str(usdz_tmp_path)],
                capture_output=True, text=True, timeout=300,
            )

            if result.returncode != 0 or not usdz_tmp_path.exists():
                self.stderr.write(f"Blender xatosi:\n{result.stdout}\n{result.stderr}")
                model.status = Model3D.Status.FAILED
                model.save(update_fields=["status"])
                return

            with open(usdz_tmp_path, "rb") as f:
                model.usdz_file.save(f"{model.id}.usdz", File(f), save=False)
            model.status = Model3D.Status.READY
            model.save(update_fields=["usdz_file", "status"])

        self.stdout.write(self.style.SUCCESS(f"USDZ tayyor: {model.id}"))
