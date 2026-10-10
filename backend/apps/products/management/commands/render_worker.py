"""Render navbati ishchisi (concurrency = 1). systemd xizmati sifatida ishlatiladi:

    nice -n 19 python manage.py render_worker

`--once` — navbatdagi hammasini bajarib chiqadi (cron/test uchun)."""
import os
import time

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.products.models import RenderJob
from apps.products.rendering.runner import run_one


class Command(BaseCommand):
    help = "3D modeldan mahsulot rasmlarini render qiladigan navbat ishchisi."

    def add_arguments(self, parser):
        parser.add_argument("--once", action="store_true", help="Navbat bo'shaguncha ishlaydi va chiqadi")
        parser.add_argument("--poll", type=float, default=5.0, help="Bo'sh navbatda kutish (soniya)")

    def handle(self, *args, once, poll, **opts):
        try:
            os.nice(19)  # sayt va API'ni bo'g'maslik uchun eng past ustuvorlik
        except (AttributeError, OSError):
            pass
        self.stdout.write("render_worker ishga tushdi")
        while True:
            job = self._claim()
            if job is None:
                if once:
                    return
                time.sleep(poll)
                continue
            self.stdout.write(f"job {job.id} -> {job.product.name_uz}")
            stats = run_one(job)
            job.refresh_from_db()
            self.stdout.write(f"  {job.status} ({job.duration_s}s) {stats or ''} {job.error[:120]}")

    @staticmethod
    def _claim():
        with transaction.atomic():
            job = (
                RenderJob.objects.select_for_update(skip_locked=True)
                .select_related("product")
                .filter(status=RenderJob.Status.PENDING)
                .order_by("created_at")
                .first()
            )
            return job
