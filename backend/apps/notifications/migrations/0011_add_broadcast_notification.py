# Generated manually on 2026-10-01

import uuid
from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("notifications", "0010_alter_notification_notif_type"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AlterField(
            model_name="notification",
            name="notif_type",
            field=models.CharField(
                choices=[
                    ("order_status", "Buyurtma holati"),
                    ("task_assigned", "Vazifa tayinlandi"),
                    ("task_available", "Vazifa boshlashga tayyor"),
                    ("material_suggestion", "Material tavsiyasi"),
                    ("task_pool_open", "Yangi erkin topshiriq"),
                    ("task_application_rejected", "Zayavka rad etildi"),
                    ("attendance_rejected", "Davomat rad etildi"),
                    ("custom_order_location_flag", "Buyurtma joylashuvi shubhali"),
                    ("employee_invited", "Ishga taklif qilindi"),
                    ("employee_invitation_accepted", "Taklif qabul qilindi"),
                    ("employee_invitation_declined", "Taklif rad etildi"),
                    ("account_deletion_requested", "Hisobni o'chirish so'rovi"),
                    ("account_deletion_approved", "Hisobni o'chirish tasdiqlandi"),
                    ("account_deletion_rejected", "Hisobni o'chirish rad etildi"),
                    ("broadcast", "Umumiy xabarnoma"),
                ],
                max_length=30,
            ),
        ),
        migrations.CreateModel(
            name="BroadcastNotification",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("is_deleted", models.BooleanField(default=False)),
                ("title", models.CharField(max_length=200, verbose_name="Xabarnoma sarlavhasi")),
                ("body", models.TextField(verbose_name="Xabar matni")),
                (
                    "delivery_type",
                    models.CharField(
                        choices=[
                            ("push_only", "Faqat Push bildirishnoma (Ilova ichida ko'rinmaydi)"),
                            ("both", "Push + Ilova ichida (Ikkalasida ham ko'rinadi)"),
                            ("inapp_only", "Faqat ilova ichida (Push yuborilmaydi)"),
                        ],
                        default="push_only",
                        max_length=20,
                        verbose_name="Yetkazish usuli",
                    ),
                ),
                (
                    "target_audience",
                    models.CharField(
                        choices=[
                            ("all", "Barcha foydalanuvchilar"),
                            ("customer", "Faqat xaridorlar (mijozlar)"),
                            ("employee", "Faqat ustalar va ishchilar"),
                            ("company_owner", "Faqat firma egalari"),
                        ],
                        default="all",
                        max_length=20,
                        verbose_name="Kimlarga yuborilsin",
                    ),
                ),
                ("is_sent", models.BooleanField(default=False, editable=False, verbose_name="Yuborilgan")),
                ("sent_at", models.DateTimeField(blank=True, editable=False, null=True, verbose_name="Yuborilgan vaqti")),
                ("recipients_count", models.PositiveIntegerField(default=0, editable=False, verbose_name="Qabul qiluvchilar soni")),
                (
                    "target_user",
                    models.ForeignKey(
                        blank=True,
                        help_text="Faqat bitta foydalanuvchiga yubormoqchi bo'lsangiz tanlang. Bo'sh qolsa, yuqoridagi auditoriyaga yuboriladi.",
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        to=settings.AUTH_USER_MODEL,
                        verbose_name="Aynan bitta foydalanuvchi (ixtiyoriy)",
                    ),
                ),
            ],
            options={
                "verbose_name": "Xabarnoma yuborish (Broadcast)",
                "verbose_name_plural": "Xabarnoma yuborish (Broadcast)",
                "ordering": ("-created_at",),
            },
        ),
    ]
