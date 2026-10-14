"""Vitrina (demo) mahsulotlari tarjimalarini chiqarish va to'ldirish.

1) Mavjud kontentni olish (tarjima qilish uchun):
       python manage.py showcase_translations export > showcase.json

2) Tarjima qilingan faylni qo'llash (mavjud tillarni O'ZGARTIRMAYDI, faqat
   bo'sh tillarni to'ldiradi; --overwrite bilan ustiga yozadi):
       python manage.py showcase_translations apply showcase_translated.json [--overwrite] [--dry-run]

Fayl formati (export chiqargan bilan bir xil):
    [{"id": "<uuid>", "name": {"uz": "...", "en": "..."}, "description": {...}}, ...]
"""
import json
import sys

from django.core.management.base import BaseCommand, CommandError

from apps.products.models import SHOWCASE_LANGUAGES, ShowcaseProduct


class Command(BaseCommand):
    help = "Vitrina mahsulotlari tarjimalarini export/apply qilish"

    def add_arguments(self, parser):
        parser.add_argument("action", choices=["export", "apply"])
        parser.add_argument("file", nargs="?", help="apply uchun JSON fayl")
        parser.add_argument("--overwrite", action="store_true", help="mavjud tarjimalar ustiga yozish")
        parser.add_argument("--dry-run", action="store_true", help="saqlamasdan natijani ko'rsatish")

    def handle(self, *args, **opts):
        if opts["action"] == "export":
            return self._export()
        if not opts["file"]:
            raise CommandError("apply uchun JSON fayl yo'lini bering")
        return self._apply(opts["file"], opts["overwrite"], opts["dry_run"])

    def _export(self):
        rows = []
        for p in ShowcaseProduct.objects.filter(is_deleted=False).order_by("sort_order", "-created_at"):
            rows.append(
                {
                    "id": str(p.pk),
                    "category": p.category.name_uz if p.category else None,
                    "name": p.name or {},
                    "description": p.description or {},
                    "missing_languages": [
                        lang for lang in sorted(SHOWCASE_LANGUAGES) if not (p.name or {}).get(lang)
                    ],
                }
            )
        json.dump(rows, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")

    def _apply(self, path, overwrite, dry_run):
        with open(path, encoding="utf-8") as fh:
            rows = json.load(fh)
        updated = skipped = 0
        for row in rows:
            try:
                product = ShowcaseProduct.objects.get(pk=row["id"], is_deleted=False)
            except (ShowcaseProduct.DoesNotExist, KeyError, ValueError):
                self.stderr.write(f"O'tkazib yuborildi (topilmadi): {row.get('id')}")
                skipped += 1
                continue
            changed = False
            for field in ("name", "description"):
                incoming = row.get(field) or {}
                current = dict(getattr(product, field) or {})
                for lang, text in incoming.items():
                    if lang not in SHOWCASE_LANGUAGES or not isinstance(text, str) or not text.strip():
                        continue
                    if overwrite or not current.get(lang):
                        if current.get(lang) != text:
                            current[lang] = text
                            changed = True
                setattr(product, field, current)
            if changed:
                product.full_clean(exclude=["image"])
                if not dry_run:
                    product.save(update_fields=["name", "description", "updated_at"])
                updated += 1
        self.stdout.write(
            self.style.SUCCESS(
                f"{'[dry-run] ' if dry_run else ''}Yangilandi: {updated}, o'tkazib yuborildi: {skipped}"
            )
        )
