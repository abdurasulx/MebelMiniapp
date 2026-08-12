from django.core.management.base import BaseCommand

from apps.products.imaging import compute_signature
from apps.products.models import Product


class Command(BaseCommand):
    help = "Rasm bo'yicha qidiruv uchun mavjud mahsulotlarga image_signature hisoblab qo'yadi."

    def handle(self, *args, **options):
        qs = Product.objects.filter(is_deleted=False, image__isnull=False).exclude(image="")
        updated = 0
        for product in qs:
            signature = compute_signature(product.image)
            if signature is not None:
                Product.objects.filter(pk=product.pk).update(image_signature=signature)
                updated += 1
        self.stdout.write(self.style.SUCCESS(f"{updated}/{qs.count()} mahsulot uchun signature hisoblandi"))
