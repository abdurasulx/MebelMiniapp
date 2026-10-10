"""Vaqtincha: firma mahsulotlarini vitrinaga (demo) nusxalaydi.

    python manage.py seed_showcase_from_company --slug test [--clear]

Firma mahsulotining nomi (uz), tavsifi, rasmlari va eng arzon variant narxi
`ShowcaseProduct`ga ko'chiriladi (tarjimalarni admin keyin kiritadi). Mavjud
vitrina mahsuloti (o'zbekcha nomi bir xil) qayta yaratilmaydi.
"""
from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand, CommandError

from apps.companies.models import Company
from apps.products.models import Product, ShowcaseImage, ShowcaseProduct


def _copy_file(field):
    if not field:
        return None
    try:
        field.open("rb")
        data = field.read()
    except (FileNotFoundError, ValueError, OSError):
        return None
    finally:
        try:
            field.close()
        except Exception:  # noqa: BLE001
            pass
    name = field.name.rsplit("/", 1)[-1]
    return name, ContentFile(data)


class Command(BaseCommand):
    help = "Firma mahsulotlarini vitrina (demo) mahsulotlariga nusxalaydi."

    def add_arguments(self, parser):
        parser.add_argument("--slug", required=True, help="Firma slug'i")
        parser.add_argument("--clear", action="store_true", help="Avval barcha vitrina mahsulotlarini o'chiradi")

    def handle(self, *args, slug, clear, **opts):
        try:
            company = Company.objects.get(slug=slug)
        except Company.DoesNotExist:
            raise CommandError(f"Firma topilmadi: {slug}")
        if clear:
            ShowcaseProduct.objects.all().delete()

        created = 0
        products = (
            Product.objects.filter(company=company, is_deleted=False)
            .prefetch_related("variants", "images")
            .order_by("created_at")
        )
        for order, product in enumerate(products):
            if ShowcaseProduct.objects.filter(is_deleted=False, name__uz=product.name_uz).exists():
                continue
            prices = [v.effective_base_price for v in product.variants.all() if v.effective_base_price]
            item = ShowcaseProduct(
                category=product.category,
                name={"uz": product.name_uz},
                description={"uz": product.description} if product.description else {},
                price_from=min(prices) if prices else None,
                sort_order=order,
                is_published=True,
            )
            main = _copy_file(product.image)
            if main:
                item.image.save(main[0], main[1], save=False)
            item.save()
            for i, img in enumerate(product.images.all()):
                copied = _copy_file(img.image)
                if copied:
                    gallery = ShowcaseImage(product=item, sort_order=i)
                    gallery.image.save(copied[0], copied[1], save=True)
            created += 1
        self.stdout.write(self.style.SUCCESS(f"{created} ta mahsulot vitrinaga ko'chirildi ({company.name})."))
