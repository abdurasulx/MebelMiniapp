import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

from django.core.files import File
from django.core.management.base import BaseCommand, CommandError

from apps.assets.geometry import extract_bbox
from apps.assets.models import Model3D

SOURCE_FORMATS = (".fbx", ".obj", ".dae")
ARCHIVE_FORMATS = (".zip", ".rar")
MODEL_SEARCH_PRIORITY = (".glb", ".gltf", ".fbx", ".obj", ".dae")
SCRIPTS_DIR = Path(__file__).resolve().parents[4] / "scripts"

# Hech qanday mebel buyumi (hatto eng katta shkaf/divan ham) 15 metrdan
# katta bo'lmaydi — shundan katta bbox chiqsa, bu deyarli har doim manba
# fayl millimetrda modellashtirilgan-u, lekin metr deb eksport qilingani
# (yoki Blender shunday deb import qilgani) sababli 1000x katta chiqqan
# degani (docs — real hodisa: 1.8m stul 1800 "metr" bo'lib chiqqan edi).
# Bunday holatda modelni avtomatik 0.001x (mm->m) kichraytiramiz — bu
# "ixtiyoriy kichraytirish" emas, aksincha modelni HAQIQIY o'lchamiga
# QAYTARISH (real mahsulotni ko'rsatish uchun zarur tuzatish).
IMPLAUSIBLE_SIZE_METERS = 15
MM_TO_M_FACTOR = 0.001


class Command(BaseCommand):
    """Model3D uchun to'liq avtomatik konvertatsiya: (ZIP/RAR ->) FBX/OBJ -> GLB -> USDZ.

    Firma xodimi Blender yoki Reality Converter'ni qo'lda ishlatmasin uchun —
    `Model3DSerializer.save()` fayl yuklanganda shu buyruqni alohida OS
    jarayonida (HTTP javobini bloklamasdan) ishga tushiradi. Manba fayl
    formatiga qarab bosqichlar avtomatik tanlanadi:
      - ZIP/RAR bo'lsa -> ochiladi, ichidan birinchi GLB/GLTF/FBX/OBJ fayl
        topiladi va shu davom etadigan manba sifatida ishlatiladi (marketplace
        arxivlarida ko'pincha model va teksturalar bitta arxivda birga keladi
        — foydalanuvchi qo'lda ochib, to'g'ri faylni tanlashi shart emas).
      - FBX/OBJ bo'lsa -> GLB'ga aylantiriladi (natija `glb_file`ga yoziladi),
        keyin o'sha GLB'dan USDZ yasaladi.
      - GLB/GLTF bo'lsa -> to'g'ridan-to'g'ri USDZ yasaladi.
    `--skip-usdz` — foydalanuvchi USDZ'ni qo'lda yuklagan bo'lsa, faqat
    GLB konvertatsiyasi bajariladi (agar manba FBX/OBJ bo'lsa).
    """

    help = "Model3D uchun (ZIP/RAR->)FBX/OBJ->GLB va/yoki GLB->USDZ konvertatsiyasini bajaradi."

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
            # Manba arxiv bo'lsa (foydalanuvchi marketplace'dan yuklab olgan
            # .zip/.rar'ni to'g'ridan-to'g'ri shu yerga tashlagan bo'lishi
            # mumkin) — ochib, ichidan haqiqiy model faylini topamiz.
            # Arxiv ichidagi boshqa fayllar (rasm-teksturalar) ham keyingi
            # bosqichda avtomatik tekstura manbai sifatida ishlatiladi.
            archive_texture_dir = None
            if source_path.suffix.lower() in ARCHIVE_FORMATS:
                extract_dir = Path(tmp_dir) / "source_archive"
                extract_dir.mkdir()
                if not self._extract_archive(source_path, extract_dir):
                    self._fail(model, "Manba arxivni ochib bo'lmadi")
                    return
                found = self._find_model_file(extract_dir)
                if not found:
                    self._fail(model, "Arxiv ichida GLB/FBX/OBJ fayl topilmadi")
                    return
                with open(found, "rb") as f:
                    model.glb_file.save(found.name, File(f), save=False)
                model.save(update_fields=["glb_file"])
                source_path = Path(model.glb_file.path)
                archive_texture_dir = extract_dir

            glb_path = source_path
            if source_path.suffix.lower() in SOURCE_FORMATS:
                converted = Path(tmp_dir) / f"{model.id}.glb"

                texture_dir = None
                texture_archive = options["texture_archive"]
                if texture_archive:
                    texture_dir = Path(tmp_dir) / "textures"
                    texture_dir.mkdir()
                    if not self._extract_archive(texture_archive, texture_dir):
                        texture_dir = None
                elif archive_texture_dir:
                    texture_dir = archive_texture_dir

                obj_source = source_path
                if source_path.suffix.lower() == ".obj":
                    obj_work_dir = Path(tmp_dir) / "obj_source"
                    obj_work_dir.mkdir()
                    obj_source = self._prepare_obj_source(source_path, texture_dir, obj_work_dir)

                script_args = [str(obj_source), str(converted)]
                if texture_dir:
                    script_args.append(str(texture_dir))

                if not self._run_blender(blender_bin, SCRIPTS_DIR / "to_glb.py", script_args):
                    self._fail(model, "FBX/OBJ -> GLB konvertatsiyasi muvaffaqiyatsiz")
                    return
                with open(converted, "rb") as f:
                    model.glb_file.save(f"{model.id}.glb", File(f), save=False)
                model.save(update_fields=["glb_file"])
                glb_path = Path(model.glb_file.path)

            with open(glb_path, "rb") as f:
                bbox = extract_bbox(f)

            if bbox and max(bbox["width"], bbox["height"], bbox["depth"]) > IMPLAUSIBLE_SIZE_METERS:
                rescaled = Path(tmp_dir) / f"{model.id}_rescaled.glb"
                if self._run_blender(
                    blender_bin, SCRIPTS_DIR / "rescale_glb.py",
                    [str(glb_path), str(rescaled), str(MM_TO_M_FACTOR)],
                ) and rescaled.exists():
                    with open(rescaled, "rb") as f:
                        model.glb_file.save(f"{model.id}.glb", File(f), save=False)
                    model.save(update_fields=["glb_file"])
                    glb_path = Path(model.glb_file.path)
                    with open(glb_path, "rb") as f:
                        bbox = extract_bbox(f)
                    if bbox and max(bbox["width"], bbox["height"], bbox["depth"]) > IMPLAUSIBLE_SIZE_METERS:
                        # mm->m tuzatishdan keyin ham amalga oshmaydigan darajada katta —
                        # bu oddiy birlik xatosi emas, manba fayl haqiqatda buzilgan
                        # bo'lishi mumkin. Avtomatik taxmin qilishni davom ettirish
                        # xavfli (noto'g'ri kichraytirib qo'yishi mumkin) — shuning
                        # uchun to'xtatib, firma xodimiga xabar beramiz.
                        self._fail(
                            model,
                            f"Model o'lchami g'ayritabiiy katta (mm->m tuzatishdan keyin ham "
                            f"{max(bbox['width'], bbox['height'], bbox['depth'])}m) — manba fayl "
                            f"birligini tekshiring",
                        )
                        return
                else:
                    self.stderr.write(
                        "O'lcham tuzatish (mm->m) muvaffaqiyatsiz — asl bbox bilan davom etiladi"
                    )

            model.apply_bbox(bbox)
            bbox_fields = ["bbox_width", "bbox_height", "bbox_depth", "shape_tag"]

            if options["skip_usdz"]:
                model.status = Model3D.Status.READY
                model.save(update_fields=["status", *bbox_fields])
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
            model.save(update_fields=["usdz_file", "status", *bbox_fields])

        self.stdout.write(self.style.SUCCESS(f"Tayyor: {model.id}"))

    def _find_model_file(self, directory):
        """Arxiv ichidan haqiqiy 3D model faylini topadi.

        GLB/GLTF ustunlik beriladi (qo'shimcha konvertatsiya kerak emas),
        keyin FBX, keyin OBJ.
        """
        files = list(directory.rglob("*"))
        for ext in MODEL_SEARCH_PRIORITY:
            for f in files:
                if f.is_file() and f.suffix.lower() == ext:
                    return f
        return None

    def _prepare_obj_source(self, source_path, texture_dir, work_dir):
        """OBJ faylning `mtllib` satri ko'pincha eksport qilingan dasturning
        original kodировkasida (masalan kirillcha nom uchun Windows-1251)
        yozilgan bo'ladi — Blender uni UTF-8 sifatida o'qiganda belgilar
        buziladi va MTL fayl hech qachon topilmaydi, hatto u tekstura
        arxivida haqiqatda mavjud bo'lsa ham (foydalanuvchi OBJ va tekstura
        arxivini alohida-alohida yuklagan holatlarda ko'p uchraydi).

        Shu yerda: agar `texture_dir`da biror MTL fayl topilsa, OBJ va MTL'ni
        faqat lotin harflardagi xavfsiz nomlar bilan ishchi papkaga
        nusxalab, `mtllib` satrini shu yangi nomga qayta yozamiz — bu
        kodировka muammosidan butunlay qochadi (matnni dekodlashga
        urinmasdan, faqat baytlar darajasida ishlaydi)."""

        if not texture_dir:
            return source_path
        mtl_candidates = list(Path(texture_dir).rglob("*.mtl"))
        if not mtl_candidates:
            return source_path

        safe_obj = work_dir / "model.obj"
        safe_mtl = work_dir / "model.mtl"
        shutil.copyfile(mtl_candidates[0], safe_mtl)

        raw = source_path.read_bytes()
        rewritten_lines = []
        for line in raw.split(b"\n"):
            if line.rstrip(b"\r").lower().startswith(b"mtllib"):
                rewritten_lines.append(b"mtllib model.mtl")
            else:
                rewritten_lines.append(line)
        safe_obj.write_bytes(b"\n".join(rewritten_lines))
        return safe_obj

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
                capture_output=True, text=True, timeout=120, errors="replace",
            )
            if result.returncode != 0:
                self.stderr.write(f"RAR ochishda xato:\n{result.stdout}\n{result.stderr}")
                return False
            return True

        self.stderr.write(f"Qo'llab-quvvatlanmaydigan arxiv formati: {suffix}")
        return False

    def _run_blender(self, blender_bin, script_path, extra_args):
        # Blender ba'zan o'z log-satrlarida (masalan yo'q MTL faylni xato
        # xabarida) manba faylning kirill/boshqa non-ASCII nomini noto'g'ri
        # kodlab chiqarib yuboradi — bu UTF-8 sifatida dekodlanmaydigan
        # baytlar hosil qiladi. `text=True` + errors="replace" bo'lmasa,
        # subprocess.run xato Blender MUVAFFAQIYATLI ishlab tugagandan keyin
        # ham UnicodeDecodeError bilan qulab tushadi — natija (GLB) allaqachon
        # tayyor bo'lsa ham yo'qoladi va model "processing" holatida abadiy
        # osilib qoladi (chaqiruvchi buyruq hech qachon davom etolmaydi).
        result = subprocess.run(
            [blender_bin, "--background", "--python", str(script_path), "--", *extra_args],
            capture_output=True, text=True, timeout=300, errors="replace",
        )
        if result.returncode != 0:
            self.stderr.write(f"Blender xatosi:\n{result.stdout}\n{result.stderr}")
            return False
        return True

    def _fail(self, model, message):
        self.stderr.write(message)
        model.status = Model3D.Status.FAILED
        model.save(update_fields=["status"])
