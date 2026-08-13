from django.core.management.base import BaseCommand

from apps.products.embedding import upsert_product_embedding
from apps.products.models import Product


class Command(BaseCommand):
    help = "Mavjud mahsulot rasmlari uchun CLIP embedding hisoblab Qdrant'ga yozadi."

    def handle(self, *args, **options):
        qs = Product.objects.filter(is_deleted=False, image__isnull=False).exclude(image="")
        total = qs.count()
        updated = 0
        for i, product in enumerate(qs, start=1):
            upsert_product_embedding(product)
            updated += 1
            self.stdout.write(f"[{i}/{total}] {product.name_uz}")
        self.stdout.write(self.style.SUCCESS(f"{updated}/{total} mahsulot uchun CLIP embedding hisoblandi"))
