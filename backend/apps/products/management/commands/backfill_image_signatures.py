from django.core.management.base import BaseCommand

from apps.products.imaging import compute_signature, dominant_color_tag
from apps.products.models import Product


class Command(BaseCommand):
    help = "Mavjud mahsulotlarga rasm bo'yicha qidiruv signature'i va avtomatik rang tegini hisoblab qo'yadi."

    def handle(self, *args, **options):
        qs = Product.objects.filter(is_deleted=False, image__isnull=False).exclude(image="")
        updated = 0
        for product in qs:
            signature = compute_signature(product.image)
            if signature is not None:
                color_tag = dominant_color_tag(product.image)
                Product.objects.filter(pk=product.pk).update(
                    image_signature=signature, color_tag=color_tag
                )
                updated += 1
        self.stdout.write(self.style.SUCCESS(f"{updated}/{qs.count()} mahsulot uchun signature/rang hisoblandi"))
