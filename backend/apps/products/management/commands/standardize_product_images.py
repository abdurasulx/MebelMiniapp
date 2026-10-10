"""Mavjud mahsulotlarning rasmlarini o'chirib, 3D modeldan standart rasmlarni
qayta yaratadi.

    # 1) Nimalar o'zgarishini ko'rish (hech narsa o'zgarmaydi):
    python manage.py standardize_product_images

    # 2) Faqat bitta mahsulot yoki firma bilan sinash:
    python manage.py standardize_product_images --slug render-test --apply
    python manage.py standardize_product_images --company test --apply --sync

    # 3) Hammasi (rasmlar zaxira papkaga ko'chiriladi, tasdiq so'raladi):
    python manage.py standardize_product_images --apply

Xavfsizlik:
  * Faqat renderlanadigan GLB modeli bor mahsulotlar o'zgaradi — modelsiz
    mahsulotlarning rasmlari tegilmaydi.
  * `--apply`siz hech narsa o'zgarmaydi (dry-run).
  * O'chiriladigan rasm fayllari `media/_replaced_images/<sana>/` ga KO'CHIRILADI
    (haqiqatan yo'q qilinmaydi) — kerak bo'lsa qaytarish mumkin.
  * Galereya (`ProductImage`) soft-delete qilinadi; `--keep-gallery` bilan saqlanadi.
"""
import shutil
from datetime import datetime
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.products.models import Product, RenderJob
from apps.products.rendering.runner import _glb_sources, enqueue, run_one


class Command(BaseCommand):
    help = "Mahsulot rasmlarini o'chirib, 3D modeldan standart rasmlarni qayta yaratadi."

    def add_arguments(self, parser):
        parser.add_argument("--apply", action="store_true", help="Haqiqatan bajarish (aks holda dry-run)")
        parser.add_argument("--yes", action="store_true", help="Tasdiq so'ramaslik")
        parser.add_argument("--slug", help="Faqat shu slug'li mahsulot")
        parser.add_argument("--company", help="Faqat shu firma (slug)")
        parser.add_argument("--keep-gallery", action="store_true", help="Galereya rasmlarini saqlab qolish")
        parser.add_argument("--sync", action="store_true", help="Renderni shu jarayonda darhol bajarish (worker'siz)")
        parser.add_argument("--limit", type=int, default=0, help="Eng ko'pi bilan N ta mahsulot")

    def handle(self, *args, **o):
        qs = Product.objects.filter(is_deleted=False).select_related("company").order_by("created_at")
        if o["slug"]:
            qs = qs.filter(slug=o["slug"])
        if o["company"]:
            qs = qs.filter(company__slug=o["company"])

        targets, skipped = [], []
        for p in qs:
            (targets if _glb_sources(p) else skipped).append(p)
        if o["limit"]:
            targets = targets[: o["limit"]]

        self.stdout.write(f"Jami: {qs.count()} | render qilinadigan (GLB bor): {len(targets)} | o'tkazib yuboriladi (GLB yo'q): {len(skipped)}")
        for p in targets:
            gallery = p.images.filter(is_deleted=False).count()
            self.stdout.write(
                f"  - {p.company.slug}/{p.slug}: asosiy rasm={'bor' if p.image else 'yo`q'}, galereya={gallery}, "
                f"render={p.render_status}"
            )
        if not o["apply"]:
            self.stdout.write(self.style.WARNING("Dry-run: hech narsa o'zgarmadi. Bajarish uchun --apply qo'shing."))
            return
        if not targets:
            return
        if not o["yes"]:
            answer = input(f"{len(targets)} ta mahsulotning rasmlari zaxiraga ko'chiriladi va qayta render qilinadi. Davom etilsinmi? [y/N] ")
            if answer.strip().lower() not in ("y", "yes", "ha"):
                raise CommandError("Bekor qilindi.")

        backup = Path(settings.MEDIA_ROOT) / "_replaced_images" / datetime.now().strftime("%Y%m%d-%H%M%S")
        backup.mkdir(parents=True, exist_ok=True)
        moved = 0

        def stash(field_file, product_id):
            """Faylni zaxira papkaga ko'chiradi (lokal storage); boshqa storage'da fayl joyida qoladi."""
            nonlocal moved
            try:
                src = Path(field_file.path)
            except (NotImplementedError, ValueError):
                return
            if src.exists():
                dest_dir = backup / str(product_id)
                dest_dir.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src), str(dest_dir / src.name))
                moved += 1

        for p in targets:
            if p.image:
                stash(p.image, p.id)
            p.image = None
            p.image_from_render = False
            p.save()
            if not o["keep_gallery"]:
                for g in p.images.filter(is_deleted=False):
                    if g.image:
                        stash(g.image, p.id)
                    g.is_deleted = True
                    g.save(update_fields=["is_deleted", "updated_at"])
            enqueue(p, force=True)

        self.stdout.write(self.style.SUCCESS(
            f"{len(targets)} ta mahsulot navbatga qo'yildi; {moved} ta fayl {backup} ga ko'chirildi."
        ))

        if o["sync"]:
            jobs = RenderJob.objects.filter(
                status=RenderJob.Status.PENDING, product__in=targets
            ).select_related("product").order_by("created_at")
            for i, job in enumerate(jobs, 1):
                stats = run_one(job)
                job.refresh_from_db()
                self.stdout.write(f"[{i}/{jobs.count()}] {job.product.slug}: {job.status} ({job.duration_s}s) {stats or ''} {job.error[:100]}")
        else:
            self.stdout.write("Render `vida-render-worker` xizmati tomonidan bajariladi (holat: `journalctl -u vida-render-worker -f`).")
