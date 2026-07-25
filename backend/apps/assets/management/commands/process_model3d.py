import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from django.core.files import File
from django.core.management.base import BaseCommand, CommandError

from apps.assets.models import Model3D

SOURCE_FORMATS = (".fbx", ".obj")
SCRIPTS_DIR = Path(__file__).resolve().parents[4] / "scripts"


class Command(BaseCommand):
    """Model3D uchun to'liq avtomatik konvertatsiya: FBX/OBJ -> GLB -> USDZ.

    Firma xodimi Blender yoki Reality Converter'ni qo'lda ishlatmasin uchun —
    `Model3DSerializer.save()` fayl yuklanganda shu buyruqni alohida OS
    jarayonida (HTTP javobini bloklamasdan) ishga tushiradi. Manba fayl
    formatiga qarab bosqichlar avtomatik tanlanadi:
      - FBX/OBJ bo'lsa -> avval GLB'ga aylantiriladi (natija `glb_file`ga
        yoziladi), keyin o'sha GLB'dan USDZ yasaladi.
      - GLB/GLTF bo'lsa -> to'g'ridan-to'g'ri USDZ yasaladi.
    `--skip-usdz` — foydalanuvchi USDZ'ni qo'lda yuklagan bo'lsa, faqat
    GLB konvertatsiyasi bajariladi (agar manba FBX/OBJ bo'lsa).
    """

    help = "Model3D uchun FBX/OBJ->GLB va/yoki GLB->USDZ konvertatsiyasini bajaradi."

    def add_arguments(self, parser):
        parser.add_argument("model3d_id", type=str)
        parser.add_argument("--skip-usdz", action="store_true")
        parser.add_argument("--texture-archive", type=str, default=None)

    def handle(self, *args, **options):
        model3d_id = options["model3d_id"]
        try:
            model = Model3D.objects.get(id=model3d_id, is_deleted=False)
        except Model3D.DoesNotExist:
            raise CommandError(f"Model3D topilmadi: {model3d_id}")

        if not model.glb_file:
            self._fail(model, "Fayl yo'q")
            return

        blender_bin = shutil.which("blender")
        if not blender_bin:
            self._fail(model, "Blender topilmadi (PATH'da yo'q)")
            return

        source_path = Path(model.glb_file.path)

        with tempfile.TemporaryDirectory() as tmp_dir:
            glb_path = source_path
            if source_path.suffix.lower() in SOURCE_FORMATS:
                converted = Path(tmp_dir) / f"{model.id}.glb"
                script_args = [str(source_path), str(converted)]

                texture_archive = options["texture_archive"]
                if texture_archive:
                    texture_dir = Path(tmp_dir) / "textures"
                    texture_dir.mkdir()
                    if self._extract_archive(texture_archive, texture_dir):
                        script_args.append(str(texture_dir))

                if not self._run_blender(blender_bin, SCRIPTS_DIR / "to_glb.py", script_args):
                    self._fail(model, "FBX/OBJ -> GLB konvertatsiyasi muvaffaqiyatsiz")
                    return
                with open(converted, "rb") as f:
                    model.glb_file.save(f"{model.id}.glb", File(f), save=False)
                model.save(update_fields=["glb_file"])
                glb_path = Path(model.glb_file.path)

            if options["skip_usdz"]:
                model.status = Model3D.Status.READY
                model.save(update_fields=["status"])
                self.stdout.write(self.style.SUCCESS(f"GLB tayyor: {model.id}"))
                return

            usdz_tmp_path = Path(tmp_dir) / f"{model.id}.usdz"
            if not self._run_blender(
                blender_bin, SCRIPTS_DIR / "glb_to_usdz.py", [str(glb_path), str(usdz_tmp_path)]
            ) or not usdz_tmp_path.exists():
                self._fail(model, "GLB -> USDZ konvertatsiyasi muvaffaqiyatsiz")
                return

            with open(usdz_tmp_path, "rb") as f:
                model.usdz_file.save(f"{model.id}.usdz", File(f), save=False)
            model.status = Model3D.Status.READY
            model.save(update_fields=["usdz_file", "status"])

        self.stdout.write(self.style.SUCCESS(f"Tayyor: {model.id}"))

    def _extract_archive(self, archive_path, dest_dir):
        """Tekstura arxivini (.zip yoki .rar) `dest_dir`ga ochadi.

        RAR — Zip'dan farqli o'laroq — proprietar siqish formati, Python
        standart kutubxonasida qo'llab-quvvatlanmaydi. Shuning uchun
        `unar` (The Unarchiver CLI, `brew install unar`) tashqi vositasi
        chaqiriladi; o'rnatilmagan bo'lsa, tekstura moslashtirilmasdan
        konvertatsiya davom etadi (fayl saqlanib qoladi — keyin serverga
        vosita o'rnatilgach qayta ishga tushirish mumkin).
        """
        suffix = Path(archive_path).suffix.lower()
        if suffix == ".zip":
            try:
                with zipfile.ZipFile(archive_path) as zf:
                    zf.extractall(dest_dir)
                return True
            except zipfile.BadZipFile:
                self.stderr.write("Tekstura arxivi yaroqsiz (zip emas) — o'tkazib yuborildi")
                return False

        if suffix == ".rar":
            unar_bin = shutil.which("unar")
            if not unar_bin:
                self.stderr.write(
                    "RAR arxivini ochish uchun 'unar' topilmadi (brew install unar) — "
                    "tekstura moslashtirilmasdan davom etiladi"
                )
                return False
            result = subprocess.run(
                [unar_bin, "-quiet", "-force-overwrite", "-output-directory", str(dest_dir), str(archive_path)],
                capture_output=True, text=True, timeout=120,
            )
            if result.returncode != 0:
                self.stderr.write(f"RAR ochishda xato:\n{result.stdout}\n{result.stderr}")
                return False
            return True

        self.stderr.write(f"Qo'llab-quvvatlanmaydigan arxiv formati: {suffix}")
        return False

    def _run_blender(self, blender_bin, script_path, extra_args):
        result = subprocess.run(
            [blender_bin, "--background", "--python", str(script_path), "--", *extra_args],
            capture_output=True, text=True, timeout=300,
        )
        if result.returncode != 0:
            self.stderr.write(f"Blender xatosi:\n{result.stdout}\n{result.stderr}")
            return False
        return True

    def _fail(self, model, message):
        self.stderr.write(message)
        model.status = Model3D.Status.FAILED
        model.save(update_fields=["status"])
