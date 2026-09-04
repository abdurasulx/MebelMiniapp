"""Davomat (check-in/check-out) qarorlarini backendda qabul qilish — frontend/
mobile faqat ma'lumot yuboradi, YAKUNIY qarorni shu yer beradi (docs §14
"Asosiy tamoyil"). Geolokatsiya masofasi, fake-GPS va "imkonsiz harakat"
tekshiruvlari shu modulda markazlashgan."""

from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.utils import timezone

from common.geo import haversine_km

from .models import (
    AttendanceAction,
    AttendanceIntegrityResult,
    AttendanceRecord,
    AttendanceStatus,
    Workplace,
)

# Impossible-travel tekshiruvi: ikki yozuv orasidagi hisoblangan tezlik shu
# qiymatdan oshsa (km/soat), xodim fizik jihatdan bunday tez ko'chib
# bo'lmasligi sababli shubhali deb belgilanadi.
MAX_PLAUSIBLE_SPEED_KMH = Decimal("150")


def _nearest_workplace(company, lat, lng):
    """Kompaniyaning barcha faol filiallaridan eng yaqinini va masofasini
    (metrda) qaytaradi. Filial umuman bo'lmasa (None, None) qaytadi."""
    nearest, nearest_km = None, None
    for wp in Workplace.objects.filter(company=company, is_deleted=False, is_active=True):
        km = haversine_km(float(lat), float(lng), float(wp.latitude), float(wp.longitude))
        if nearest_km is None or km < nearest_km:
            nearest, nearest_km = wp, km
    if nearest is None:
        return None, None
    return nearest, Decimal(str(nearest_km * 1000))


def verify_play_integrity(token):
    """Android Play Integrity tokenini Google'ning serverida tekshiradi.
    Loyihada hali Google Play Console tomonidan xizmat akkaunti
    sozlanmagan bo'lsa (odatiy holat, qo'lda faollashtiriladi) — bloklamasdan
    "not_configured" qaytaradi, chunki bu himoya qatlami frontenddan mustaqil
    ravishda ISHLAMAY qolgani check-in imkoniyatini butunlay o'chirib
    qo'ymasligi kerak (qarang docs §8)."""
    credentials_path = getattr(settings, "PLAY_INTEGRITY_CREDENTIALS_PATH", None)
    package_name = getattr(settings, "PLAY_INTEGRITY_PACKAGE_NAME", None)
    if not token or not credentials_path or not package_name:
        return AttendanceIntegrityResult.NOT_CONFIGURED

    import google.auth.transport.requests
    import requests
    from google.oauth2 import service_account

    try:
        credentials = service_account.Credentials.from_service_account_file(
            credentials_path, scopes=["https://www.googleapis.com/auth/playintegrity"]
        )
        credentials.refresh(google.auth.transport.requests.Request())
        resp = requests.post(
            f"https://playintegrity.googleapis.com/v1/{package_name}:decodeIntegrityToken",
            json={"integrity_token": token},
            headers={"Authorization": f"Bearer {credentials.token}"},
            timeout=10,
        )
        resp.raise_for_status()
        verdict = resp.json().get("tokenPayloadExternal", {})
        device_verdicts = verdict.get("deviceIntegrity", {}).get("deviceRecognitionVerdict", [])
        if "MEETS_DEVICE_INTEGRITY" in device_verdicts:
            return AttendanceIntegrityResult.VALID
        return AttendanceIntegrityResult.FAILED
    except Exception:
        return AttendanceIntegrityResult.FAILED


def verify_app_attest(assertion):
    """iOS App Attest tasdig'ini tekshiradi. Apple Developer portalida App
    Attest capability/kalitlar hali sozlanmagan bo'lsa "not_configured"
    qaytaradi (qarang verify_play_integrity'dagi izoh — bir xil tamoyil)."""
    key_id = getattr(settings, "APP_ATTEST_KEY_ID", None)
    if not assertion or not key_id:
        return AttendanceIntegrityResult.NOT_CONFIGURED
    # To'liq Apple App Attest server-tomon tasdiqlash (attestatsiya obyekti +
    # assertion imzosini Apple'ning ildiz sertifikati bilan tekshirish)
    # alohida kutubxona/keng implementatsiya talab qiladi — capability
    # yoqilgach shu joyga ulanadi.
    return AttendanceIntegrityResult.NOT_CONFIGURED


def resolve_check_in(
    *, employee, action, lat, lng, accuracy=None, is_mock=False, device_timestamp=None,
    integrity_token=None, platform="android",
):
    """Check-in/check-out so'rovini baholab `AttendanceRecord` yaratadi.
    Qaror tartibi docs §7-10ga mos: mock-location > integrity > radius >
    imkonsiz-harakat > tasdiqlash."""
    from apps.notifications.services import notify_attendance_rejected

    company = employee.company
    workplace, distance_m = _nearest_workplace(company, lat, lng)

    status = AttendanceStatus.APPROVED
    reason = ""
    integrity_result = AttendanceIntegrityResult.NOT_CHECKED

    if is_mock:
        status, reason = AttendanceStatus.REJECTED, "Mock location aniqlangan"
    else:
        if platform == "ios":
            integrity_result = verify_app_attest(integrity_token)
        else:
            integrity_result = verify_play_integrity(integrity_token)
        if integrity_result == AttendanceIntegrityResult.FAILED:
            status, reason = AttendanceStatus.REJECTED, "Qurilma xavfsizligi tekshiruvidan o'tmadi"
        elif workplace is None:
            status, reason = AttendanceStatus.REJECTED, "Ishxona joylashuvi sozlanmagan"
        elif distance_m > workplace.radius_meters:
            status, reason = AttendanceStatus.REJECTED, "Ruxsat etilgan radiusdan tashqarida"

    record = AttendanceRecord(
        employee=employee,
        workplace=workplace,
        action=action,
        latitude=lat,
        longitude=lng,
        accuracy=accuracy,
        device_timestamp=device_timestamp,
        is_mock=is_mock,
        integrity_result=integrity_result,
        distance_meters=distance_m,
        status=status,
        reason=reason,
    )

    if status == AttendanceStatus.APPROVED:
        last = (
            AttendanceRecord.objects.filter(employee=employee, is_deleted=False)
            .exclude(status=AttendanceStatus.REJECTED)
            .order_by("-server_timestamp")
            .first()
        )
        if last is not None:
            now = timezone.now()
            elapsed_hours = Decimal((now - last.server_timestamp).total_seconds()) / Decimal(3600)
            if elapsed_hours > 0:
                km = haversine_km(float(last.latitude), float(last.longitude), float(lat), float(lng))
                speed_kmh = Decimal(str(km)) / elapsed_hours
                if speed_kmh > MAX_PLAUSIBLE_SPEED_KMH:
                    status = AttendanceStatus.SUSPICIOUS
                    reason = "Fizik jihatdan mumkin bo'lmagan harakat aniqlandi"
                    record.status, record.reason = status, reason

    record.save()

    if status in (AttendanceStatus.REJECTED, AttendanceStatus.SUSPICIOUS):
        notify_attendance_rejected(employee, reason)

    return record


def worked_hours(employee, start, end):
    """Berilgan davr ichida tasdiqlangan check_in/check_out juftliklarini
    kun bo'yicha bog'lab jami ishlangan soatni (Decimal) va har bir kun
    uchun kechikish/erta ketish/ortiqcha ish daqiqalari breakdownini
    qaytaradi. Juftlanmagan (masalan check_out unutilgan) check_in'lar
    hisobga olinmaydi."""
    records = list(
        AttendanceRecord.objects.filter(
            employee=employee,
            is_deleted=False,
            status=AttendanceStatus.APPROVED,
            server_timestamp__gte=start,
            server_timestamp__lt=end,
        ).order_by("server_timestamp")
    )

    total_hours = Decimal("0")
    breakdown = []
    pending_check_in = None
    for rec in records:
        if rec.action == AttendanceAction.CHECK_IN:
            pending_check_in = rec
            continue
        if rec.action == AttendanceAction.CHECK_OUT and pending_check_in is not None:
            delta = rec.server_timestamp - pending_check_in.server_timestamp
            hours = Decimal(delta.total_seconds()) / Decimal(3600)
            lunch_minutes = 0
            # Tushlik oralig'i smena ichida bo'lsa, ishlangan soatdan
            # ayiriladi — tushlikka chiqilgan-chiqilmaganidan qat'iy nazar
            # (ish grafigida belgilangan tanaffus sifatida).
            if employee.lunch_start and employee.lunch_end:
                lunch_start = timezone.datetime.combine(
                    pending_check_in.server_timestamp.date(), employee.lunch_start,
                    tzinfo=pending_check_in.server_timestamp.tzinfo,
                )
                lunch_end = timezone.datetime.combine(
                    pending_check_in.server_timestamp.date(), employee.lunch_end,
                    tzinfo=pending_check_in.server_timestamp.tzinfo,
                )
                overlap_start = max(pending_check_in.server_timestamp, lunch_start)
                overlap_end = min(rec.server_timestamp, lunch_end)
                if overlap_end > overlap_start:
                    lunch_minutes = int((overlap_end - overlap_start).total_seconds() / 60)
                    hours -= Decimal(lunch_minutes) / Decimal(60)
            if hours > 0:
                total_hours += hours
                day_entry = {
                    "date": pending_check_in.server_timestamp.date(),
                    "check_in": pending_check_in.server_timestamp,
                    "check_out": rec.server_timestamp,
                    "hours": hours,
                    "lunch_minutes": lunch_minutes,
                    "late_minutes": 0,
                    "early_leave_minutes": 0,
                    "overtime_minutes": 0,
                }
                if employee.shift_start:
                    scheduled_start = timezone.datetime.combine(
                        pending_check_in.server_timestamp.date(), employee.shift_start,
                        tzinfo=pending_check_in.server_timestamp.tzinfo,
                    )
                    late = (pending_check_in.server_timestamp - scheduled_start).total_seconds() / 60
                    if late > 0:
                        day_entry["late_minutes"] = int(late)
                if employee.shift_end:
                    scheduled_end = timezone.datetime.combine(
                        rec.server_timestamp.date(), employee.shift_end,
                        tzinfo=rec.server_timestamp.tzinfo,
                    )
                    early = (scheduled_end - rec.server_timestamp).total_seconds() / 60
                    if early > 0:
                        day_entry["early_leave_minutes"] = int(early)
                    else:
                        day_entry["overtime_minutes"] = int(-early)
                breakdown.append(day_entry)
            pending_check_in = None

    return total_hours, breakdown
