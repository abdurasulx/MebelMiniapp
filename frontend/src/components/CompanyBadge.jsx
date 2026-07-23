import { Star } from "lucide-react";

/**
 * Firma ishonch darajasi belgisi (bajarilgan buyurtmalar soniga va
 * o'rtacha yulduzcha reytingiga qarab rang/label hisoblanadi — backendda
 * Company.tier property'sida, bu yerda faqat ko'rsatiladi).
 */
export default function CompanyBadge({ tier, size = "md" }) {
  if (!tier) return null;
  const pad = size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-xs";
  return (
    <span className="inline-flex items-center gap-2">
      <span
        className={`inline-flex items-center gap-1.5 rounded-full font-bold ${pad}`}
        style={{ background: `color-mix(in srgb, ${tier.color} 20%, transparent)`, color: tier.color }}
      >
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: tier.color }} />
        {tier.label}
      </span>
      {tier.rating !== null && tier.rating !== undefined && (
        <span className="inline-flex items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
          <Star size={12} fill="currentColor" /> {tier.rating} ({tier.review_count})
        </span>
      )}
    </span>
  );
}
