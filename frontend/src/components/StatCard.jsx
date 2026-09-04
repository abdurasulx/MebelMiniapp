import { Link } from "react-router-dom";
import { TrendingUp, TrendingDown } from "lucide-react";

const PALETTE = ["var(--primary)", "var(--secondary)", "var(--success)", "var(--warning)"];

export default function StatCard({ icon: Icon, label, value, hint, trend, tone = 0, to }) {
  const accent = PALETTE[tone % PALETTE.length];
  const Wrapper = to ? Link : "div";
  return (
    <Wrapper
      {...(to ? { to } : {})}
      className={`card p-5 ${to ? "block transition-all duration-150 hover:-translate-y-0.5 hover:shadow-lg" : ""}`}
    >
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
      <div className="mt-2 flex flex-wrap items-center gap-2">
        {trend !== undefined && trend !== null && (
          <span className={`trend-pill inline-flex items-center gap-0.5 ${trend >= 0 ? "up" : "down"}`}>
            {trend >= 0 ? <TrendingUp size={11} /> : <TrendingDown size={11} />} {Math.abs(trend)}%
          </span>
        )}
        {hint && typeof hint === "string" ? (
          <span className="text-[11px]" style={{ color: "var(--muted)" }}>
            {hint}
          </span>
        ) : (
          hint
        )}
      </div>
    </Wrapper>
  );
}
