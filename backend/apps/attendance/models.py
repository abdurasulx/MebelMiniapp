from django.conf import settings
from django.db import models

from common.models import BaseModel


class Workplace(BaseModel):
    """Firma filiali/ishlab chiqarish joyi — soatbay xodim shu nuqtaga
    yaqinlikda (ruxsat etilgan radius ichida) "Ishga keldim/Ishni
    tugatdim" tugmasini bosishi mumkin (qarang apps.attendance.services).
    """

    company = models.ForeignKey(
        "companies.Company", on_delete=models.CASCADE, related_name="workplaces"
    )
    name = models.CharField(max_length=200)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    radius_meters = models.PositiveIntegerField(default=100)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ("name",)

    def __str__(self):
        return f"{self.name} ({self.company})"


class AttendanceAction(models.TextChoices):
    CHECK_IN = "check_in", "Ishga keldi"
    CHECK_OUT = "check_out", "Ishni tugatdi"


class AttendanceIntegrityResult(models.TextChoices):
    NOT_CHECKED = "not_checked", "Tekshirilmadi"
    VALID = "valid", "Tasdiqlangan"
    FAILED = "failed", "Muvaffaqiyatsiz"
    NOT_CONFIGURED = "not_configured", "Sozlanmagan"


class AttendanceStatus(models.TextChoices):
    APPROVED = "approved", "Tasdiqlangan"
    REJECTED = "rejected", "Rad etilgan"
    SUSPICIOUS = "suspicious", "Shubhali"


class AttendanceRecord(BaseModel):
    """Xodimning bitta "Ishga keldim"/"Ishni tugatdim" bosishi — server
    tomonidan tasdiqlangan (yoki rad etilgan) davomat yozuvi (docs: Xodimlar
    ish haqi va davomat tizimi §7-10). `server_timestamp` YAGONA ishonchli
    vaqt manbai — `device_timestamp` faqat diagnostika uchun saqlanadi,
    ish haqi hisobida ishlatilmaydi."""

    employee = models.ForeignKey(
        "companies.Employee", on_delete=models.CASCADE, related_name="attendance_records"
    )
    workplace = models.ForeignKey(
        Workplace, on_delete=models.SET_NULL, null=True, blank=True, related_name="attendance_records"
    )
    action = models.CharField(max_length=10, choices=AttendanceAction.choices)
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    accuracy = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    server_timestamp = models.DateTimeField(auto_now_add=True)
    device_timestamp = models.DateTimeField(null=True, blank=True)
    is_mock = models.BooleanField(default=False)
    integrity_result = models.CharField(
        max_length=20, choices=AttendanceIntegrityResult.choices, default=AttendanceIntegrityResult.NOT_CHECKED
    )
    distance_meters = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=10, choices=AttendanceStatus.choices)
    reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ("-server_timestamp",)

    def __str__(self):
        return f"{self.employee} — {self.get_action_display()} ({self.status})"


class AttendanceEditLog(BaseModel):
    """Admin/firma egasi davomat yozuvini qo'lda o'zgartirganda audit izi
    (docs §11 — oddiy xodim o'z davomatini o'zgartira olmaydi, faqat egasi/
    platforma admini, va har bir o'zgarish shu yerda saqlanadi)."""

    record = models.ForeignKey(AttendanceRecord, on_delete=models.CASCADE, related_name="edit_logs")
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name="+"
    )
    old_value = models.JSONField()
    new_value = models.JSONField()
    reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return f"{self.record_id} edited by {self.changed_by}"
