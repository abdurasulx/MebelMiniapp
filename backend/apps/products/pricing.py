"""Yagona narx/chegirma hisoblash xizmati.

Narx va chegirma mantiqi FAQAT shu yerda: `Variant.effective_base_price`,
`discount_active` va API'dagi `pricing` bloki shu funksiyadan olinadi, shuning
uchun bosh sahifa, katalog, qidiruv, sevimlilar, mahsulot sahifasi, savat va
buyurtma BIR XIL narx ko'rsatadi. Frontend hech qachon chegirmani o'zi hisoblamaydi.

Bir variantda bir vaqtning o'zida faqat BITTA chegirma bo'lishi mumkin (chegirma
variantning o'zida saqlanadi: tur + qiymat + oraliq) — shuning uchun bir nechta
faol chegirma to'qnashuvi tuzilmaviy jihatdan mumkin emas.
"""

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

from django.utils import timezone

PERCENT = "percent"
FIXED = "fixed"
DISCOUNT_TYPES = (PERCENT, FIXED)

_CENT = Decimal("0.01")
_HUNDRED = Decimal("100")


def _q(value: Decimal) -> Decimal:
    return value.quantize(_CENT, rounding=ROUND_HALF_UP)


@dataclass(frozen=True)
class PriceBreakdown:
    original_price: Decimal
    discount_percent: Decimal
    discount_amount: Decimal
    final_price: Decimal
    active: bool

    def as_dict(self) -> dict:
        """JSON uchun: pul summalari son sifatida (Decimal emas)."""
        return {
            "original_price": float(self.original_price),
            "discount_percent": float(self.discount_percent),
            "discount_amount": float(self.discount_amount),
            "final_price": float(self.final_price),
        }


def is_discount_active(*, enabled, discount_type, percent, fixed_amount, starts_at, ends_at, now=None) -> bool:
    """Chegirma faol: yoqilgan VA qiymati bor VA boshlangan VA tugamagan."""
    now = now or timezone.now()
    if not enabled:
        return False
    value = fixed_amount if discount_type == FIXED else percent
    if not value or value <= 0:
        return False
    if starts_at is not None and starts_at > now:
        return False
    if ends_at is not None and ends_at < now:
        return False
    return True


def compute_pricing(
    base_price,
    *,
    enabled=True,
    discount_type=PERCENT,
    percent=0,
    fixed_amount=0,
    starts_at=None,
    ends_at=None,
    now=None,
) -> PriceBreakdown:
    original = _q(Decimal(base_price))
    percent = Decimal(percent or 0)
    fixed_amount = Decimal(fixed_amount or 0)
    active = is_discount_active(
        enabled=enabled, discount_type=discount_type, percent=percent,
        fixed_amount=fixed_amount, starts_at=starts_at, ends_at=ends_at, now=now,
    )
    if not active or original <= 0:
        return PriceBreakdown(original, Decimal("0"), Decimal("0"), original, False)

    if discount_type == FIXED:
        amount = min(_q(fixed_amount), original)  # chegirma narxdan katta bo'lsa ham final >= 0
    else:
        amount = _q(original * min(percent, _HUNDRED) / _HUNDRED)
    final = max(original - amount, Decimal("0"))
    effective_percent = _q(amount / original * _HUNDRED) if original else Decimal("0")
    return PriceBreakdown(original, effective_percent, amount, _q(final), True)


def validate_discount(
    *, base_price, discount_type, percent, fixed_amount, starts_at, ends_at, cost_price=None
) -> list[str]:
    """Chegirma maydonlari xatolari ro'yxati (bo'sh = to'g'ri). Model.clean() va
    serializer validate() bir xil qoidadan foydalansin."""
    errors: list[str] = []
    percent = Decimal(percent or 0)
    fixed_amount = Decimal(fixed_amount or 0)
    if discount_type not in DISCOUNT_TYPES:
        errors.append("Chegirma turi noto'g'ri")
        return errors
    if starts_at is not None and ends_at is not None and starts_at >= ends_at:
        errors.append("Chegirma boshlanish vaqti tugash vaqtidan oldin bo'lishi kerak")
    if discount_type == PERCENT:
        if percent and not (0 < percent <= 100):
            errors.append("Chegirma foizi 0 dan katta va 100 dan oshmasligi kerak")
        if fixed_amount:
            errors.append("Foizli chegirmada qat'iy summa ko'rsatilmaydi")
    else:
        if fixed_amount <= 0 and (percent or starts_at is not None or ends_at is not None):
            errors.append("Qat'iy chegirma summasi 0 dan katta bo'lishi kerak")
        if percent:
            errors.append("Qat'iy chegirmada foiz ko'rsatilmaydi")
        if base_price is not None and fixed_amount > Decimal(base_price):
            errors.append("Chegirma summasi mahsulot narxidan katta bo'lmasligi kerak")
    if not errors and cost_price is not None and base_price is not None:
        breakdown = compute_pricing(
            base_price, discount_type=discount_type, percent=percent, fixed_amount=fixed_amount,
        )
        if breakdown.final_price < Decimal(cost_price):
            errors.append("Chegirma narxi tannarxdan pastga tushirilmasin")
    return errors


def line_snapshot(variant, width, height, depth, quantity) -> dict:
    """Buyurtma bandi uchun narx snapshot'i — backend O'ZI hisoblaydi (mijoz yuborgan
    narx/chegirmaga ishonilmaydi): joriy faol chegirma bo'yicha yakuniy narx, asl narx
    va shu bandga berilgan jami chegirma summasi. Hajm = en*bo'y*chuqurlik (m³)."""
    p = variant.pricing
    volume = Decimal(width) * Decimal(height) * Decimal(depth)
    qty = Decimal(quantity)
    subtotal = _q(p.final_price * volume * qty)
    discount_amount = _q((p.original_price - p.final_price) * volume * qty)
    return {
        "unit_m3_price": p.final_price,
        "original_unit_m3_price": p.original_price,
        "discount_amount": discount_amount,
        "subtotal": subtotal,
    }
