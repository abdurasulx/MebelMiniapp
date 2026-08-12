from django.core.management.base import BaseCommand

from apps.assets.geometry import extract_bbox
from apps.assets.models import Model3D


class Command(BaseCommand):
    help = "Mavjud (GLB fayli tayyor) 3D modellarga geometrik bounding box/shakl tegini hisoblab qo'yadi."

    def handle(self, *args, **options):
        qs = Model3D.objects.filter(is_deleted=False, glb_file__isnull=False).exclude(glb_file="")
        updated = 0
        for model in qs:
            try:
                with model.glb_file.open("rb") as f:
                    bbox = extract_bbox(f)
            except (FileNotFoundError, OSError):
                continue
            if bbox:
                model.apply_bbox(bbox)
                model.save(update_fields=["bbox_width", "bbox_height", "bbox_depth", "shape_tag"])
                updated += 1
        self.stdout.write(self.style.SUCCESS(f"{updated}/{qs.count()} model uchun bounding box hisoblandi"))
