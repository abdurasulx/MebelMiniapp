import { Moon, Sun } from "lucide-react";

/** Yorug'/qorong'i rejim — switchbox (o'zbekiston UI'larida odatiy tugma emas, tumbler). */
export default function ThemeSwitch({ dark, onToggle, surface = false }) {
  const track = surface ? "var(--brand-cta-bg)" : "var(--border)";
  const knobBg = surface ? "var(--brand-surface)" : "var(--card)";
  return (
    <button
      role="switch"
      aria-checked={dark}
      onClick={onToggle}
      title="Tema"
      className="relative inline-flex h-7 w-13 shrink-0 items-center rounded-full transition"
      style={{ width: 52, background: dark ? track : "color-mix(in srgb, var(--text) 15%, transparent)" }}
    >
      <span
        className="absolute flex h-5.5 w-5.5 items-center justify-center rounded-full text-[11px] shadow transition-transform"
        style={{
          width: 22,
          height: 22,
          background: knobBg,
          transform: dark ? "translateX(28px)" : "translateX(3px)",
        }}
      >
        {dark ? <Moon size={12} /> : <Sun size={12} />}
      </span>
    </button>
  );
}
