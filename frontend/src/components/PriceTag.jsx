/// Katalog/Sevimlilar kartalarida "N so'm/m³ dan" narxini ko'rsatadi —
/// birinchi variant chegirmasi faol bo'lsa, eski narx chizib qo'yilgan
/// holda va chegirma foizi bilan birga ko'rsatiladi.
export default function PriceTag({ variant, suffix = "/m³ dan" }) {
  if (!variant) return null;
  if (variant.discount_active) {
    return (
      <span className="mt-1 flex flex-wrap items-baseline gap-1.5">
        <span className="text-xs line-through" style={{ color: "var(--muted)" }}>
          {Number(variant.base_price).toLocaleString()} so'm
        </span>
        <span className="text-sm font-bold" style={{ color: "var(--secondary)" }}>
          {Number(variant.effective_base_price).toLocaleString()} so'm{suffix}
        </span>
        <span className="badge" style={{ background: "var(--danger)", color: "#fff" }}>
          -{Number(variant.discount_percent)}%
        </span>
      </span>
    );
  }
  return (
    <span className="mt-1 text-sm font-bold" style={{ color: "var(--secondary)" }}>
      {Number(variant.base_price).toLocaleString()} so'm{suffix}
    </span>
  );
}
