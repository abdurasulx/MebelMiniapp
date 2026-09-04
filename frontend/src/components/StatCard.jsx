import { Link } from "react-router-dom";
import { TrendingUp, TrendingDown } from "lucide-react";

const PALETTE = ["var(--primary)", "var(--secondary)", "var(--success)", "var(--warning)"];

export default function StatCard({ icon: Icon, label, value, hint, trend, tone = 0, to, compact = false }) {
  const accent = PALETTE[tone % PALETTE.length];
  const Wrapper = to ? Link : "div";
  return (
    <Wrapper
      {...(to ? { to } : {})}
      className={`card ${compact ? "p-3" : "p-5"} ${to ? "block transition-all duration-150 hover:-translate-y-0.5 hover:shadow-lg" : ""}`}
    >
      <div className={`flex items-start justify-between ${compact ? "mb-1.5" : "mb-3"}`}>
        <span className="text-xs font-medium" style={{ color: "var(--muted)" }}>
          {label}
        </span>
        <div
          className="stat-badge"
          style={compact ? { background: `color-mix(in srgb, ${accent} 22%, transparent)`, color: accent, width: 26, height: 26 } : { background: `color-mix(in srgb, ${accent} 22%, transparent)`, color: accent }}
        >
          {Icon && <Icon size={compact ? 14 : 18} />}
        </div>
      </div>
      <div className={compact ? "text-lg font-bold leading-tight" : "text-2xl font-bold leading-tight"}>{value}</div>
      <div className={`flex flex-wrap items-center gap-2 ${compact ? "mt-1" : "mt-2"}`}>
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
