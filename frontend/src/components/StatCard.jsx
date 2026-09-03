import { TrendingUp, TrendingDown } from "lucide-react";

const PALETTE = ["var(--primary)", "var(--secondary)", "var(--success)", "var(--warning)"];

export default function StatCard({ icon: Icon, label, value, hint, trend, tone = 0 }) {
  const accent = PALETTE[tone % PALETTE.length];
  return (
    <div className="card p-5">
      <div className="mb-3 flex items-start justify-between">
        <span className="text-xs font-medium" style={{ color: "var(--muted)" }}>
          {label}
        </span>
        <div
          className="stat-badge"
          style={{ background: `color-mix(in srgb, ${accent} 22%, transparent)`, color: accent }}
        >
          {Icon && <Icon size={18} />}
        </div>
      </div>
      <div className="text-2xl font-bold leading-tight">{value}</div>
      <div className="mt-2 flex items-center gap-2">
        {trend !== undefined && trend !== null && (
          <span className={`trend-pill inline-flex items-center gap-0.5 ${trend >= 0 ? "up" : "down"}`}>
            {trend >= 0 ? <TrendingUp size={11} /> : <TrendingDown size={11} />} {Math.abs(trend)}%
          </span>
        )}
        {hint && (
          <span className="text-[11px]" style={{ color: "var(--muted)" }}>
            {hint}
          </span>
        )}
      </div>
    </div>
  );
}
