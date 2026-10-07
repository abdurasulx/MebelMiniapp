from decimal import ROUND_HALF_UP, Decimal, InvalidOperation

from rest_framework import serializers


class CoordinateField(serializers.DecimalField):
    """Kenglik/uzunlik uchun DecimalField(9, 6): telefon GPS'i odatda 6 xonadan
    ko'p raqam beradi (41.31108123456) — DRF buni rad etardi ("no more than 6
    decimal places"). Bu maydon kirishni 6 xonagacha yaxlitlaydi, so'ng odatdagidek
    tekshiradi."""

    def __init__(self, **kwargs):
        kwargs.setdefault("max_digits", 9)
        kwargs.setdefault("decimal_places", 6)
        super().__init__(**kwargs)

    def to_internal_value(self, data):
        if isinstance(data, (int, float, str)) and not isinstance(data, bool):
            try:
                data = str(Decimal(str(data).strip()).quantize(Decimal("0.000001"), rounding=ROUND_HALF_UP))
            except (InvalidOperation, ValueError):
                pass  # DRF o'zi "valid number" xatosini beradi
        return super().to_internal_value(data)
