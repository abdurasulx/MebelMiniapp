import { useEffect } from "react";

/**
 * Butun ekranni bloklaydigan yuklanish oynasi (orqa tarafga bosib bo'lmaydi).
 * `percent` — 0..100 (bo'lmasa aylanuvchi indikator), `label` — joriy bosqich.
 * Yopish/brauzer tabini yangilash ogohlantiriladi — jarayon uziladi.
 */
export default function BlockingLoader({ label, percent = null, hint = null }) {
  useEffect(() => {
    const warn = (e) => {
      e.preventDefault();
      e.returnValue = "";
    };
    window.addEventListener("beforeunload", warn);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("beforeunload", warn);
      document.body.style.overflow = prev;
    };
  }, []);

  return (
    <div
      role="alertdialog"
      aria-modal="true"
      aria-live="assertive"
      aria-label={label}
      style={{
        position: "fixed", inset: 0, zIndex: 9999, display: "flex", alignItems: "center",
        justifyContent: "center", padding: 24, background: "rgba(14, 25, 20, 0.62)",
        backdropFilter: "blur(6px)", cursor: "progress",
      }}
    >
      <div
        style={{
          width: "min(420px, 100%)", background: "var(--card)", color: "var(--text)",
          border: "1px solid var(--border)", borderRadius: 16, padding: "28px 24px", textAlign: "center",
        }}
      >
        <div
          style={{
            width: 44, height: 44, margin: "0 auto 16px", borderRadius: "50%",
            border: "4px solid var(--border)", borderTopColor: "var(--brand-cta-bg)",
            animation: "vida-spin 0.9s linear infinite",
          }}
        />
        <div style={{ fontSize: 15, fontWeight: 700 }}>{label}</div>
        {percent !== null && (
          <>
            <div style={{ height: 8, borderRadius: 999, background: "var(--surface-muted)", margin: "16px 0 6px", overflow: "hidden" }}>
              <div
                style={{
                  width: `${Math.min(100, Math.max(0, percent))}%`, height: "100%",
                  background: "var(--brand-cta-bg)", borderRadius: 999, transition: "width .3s ease",
                }}
              />
            </div>
            <div style={{ fontSize: 12.5, color: "var(--muted)" }}>{Math.round(percent)}%</div>
          </>
        )}
        {hint && <div style={{ fontSize: 12.5, color: "var(--muted)", marginTop: 12 }}>{hint}</div>}
        <div style={{ fontSize: 12, color: "var(--muted)", marginTop: 14 }}>
          Iltimos kuting, oynani yopmang.
        </div>
      </div>
      <style>{"@keyframes vida-spin { to { transform: rotate(360deg); } }"}</style>
    </div>
  );
}
