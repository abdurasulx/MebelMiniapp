import { useEffect, useMemo, useRef, useState } from "react";
import { Check, MapPin, Search, X } from "lucide-react";
import { VILOYATLAR } from "../lib/viloyat";

const nameOf = (key) => VILOYATLAR.find(([k]) => k === key)?.[1] || key;

/**
 * Viloyat tanlash modali (bitta yoki bir nechta).
 * `value`: multiple bo'lsa massiv, aks holda satr. `onChange(yangiQiymat)` "Tayyor"da chaqiriladi.
 */
export function RegionPickerModal({ open, onClose, value, onChange, multiple = false, title, doneLabel = "Tayyor", clearLabel = "Tozalash", allLabel = "Hammasi", searchLabel = "Qidirish…" }) {
  const [draft, setDraft] = useState([]);
  const [q, setQ] = useState("");
  const inputRef = useRef(null);

  useEffect(() => {
    if (!open) return;
    setDraft(multiple ? [...(value || [])] : value ? [value] : []);
    setQ("");
    const onKey = (e) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const list = useMemo(() => {
    const s = q.trim().toLowerCase();
    return s ? VILOYATLAR.filter(([, n]) => n.toLowerCase().includes(s)) : VILOYATLAR;
  }, [q]);

  if (!open) return null;

  const toggle = (key) => {
    if (!multiple) {
      onChange(key);
      onClose();
      return;
    }
    setDraft((d) => (d.includes(key) ? d.filter((x) => x !== key) : [...d, key]));
  };
  const allSelected = draft.length === VILOYATLAR.length;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
      style={{ background: "rgba(8, 14, 11, 0.55)", backdropFilter: "blur(4px)" }}
      onMouseDown={(e) => e.target === e.currentTarget && onClose()}
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        className="flex max-h-[85vh] w-full flex-col overflow-hidden rounded-t-3xl shadow-2xl sm:max-w-lg sm:rounded-3xl"
        style={{ background: "var(--card)", color: "var(--text)", border: "1px solid var(--border)" }}
      >
        <div className="flex items-center justify-between gap-3 px-5 pb-3 pt-5">
          <div className="flex items-center gap-2 text-base font-bold">
            <MapPin size={18} /> {title}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full"
            style={{ background: "color-mix(in srgb, var(--muted) 15%, transparent)" }}
            aria-label="Yopish"
          >
            <X size={16} />
          </button>
        </div>

        <div className="px-5 pb-3">
          <div className="relative">
            <Search size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
            <input
              ref={inputRef}
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder={searchLabel}
              className="w-full rounded-xl py-2.5 pl-9 pr-3 text-sm"
              style={{ border: "1px solid var(--border)", background: "var(--bg)", color: "var(--text)" }}
            />
          </div>
          {multiple && (
            <div className="mt-2 flex items-center justify-between text-xs" style={{ color: "var(--muted)" }}>
              <span>{draft.length} / {VILOYATLAR.length}</span>
              <span className="flex gap-3">
                <button type="button" className="underline" onClick={() => setDraft(allSelected ? [] : VILOYATLAR.map(([k]) => k))}>
                  {allSelected ? clearLabel : allLabel}
                </button>
              </span>
            </div>
          )}
        </div>

        <div className="grid flex-1 grid-cols-1 gap-2 overflow-y-auto px-5 pb-4 sm:grid-cols-2">
          {list.map(([key, label]) => {
            const selected = multiple ? draft.includes(key) : value === key;
            return (
              <button
                key={key}
                type="button"
                onClick={() => toggle(key)}
                className="flex items-center justify-between gap-2 rounded-xl px-3.5 py-3 text-left text-sm font-semibold transition"
                style={{
                  background: selected ? "var(--brand-cta-bg)" : "var(--bg)",
                  color: selected ? "var(--brand-cta-text)" : "var(--text)",
                  border: `1px solid ${selected ? "var(--brand-cta-bg)" : "var(--border)"}`,
                }}
                aria-pressed={selected}
              >
                <span>{label}</span>
                {selected && <Check size={16} />}
              </button>
            );
          })}
          {list.length === 0 && (
            <p className="col-span-full py-6 text-center text-sm" style={{ color: "var(--muted)" }}>—</p>
          )}
        </div>

        {multiple && (
          <div className="flex gap-2 px-5 pb-5 pt-1">
            <button
              type="button"
              className="btn btn-brand flex-1"
              onClick={() => {
                onChange(draft);
                onClose();
              }}
            >
              {doneLabel}{draft.length ? ` (${draft.length})` : ""}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

/** Tanlangan qiymat(lar)ni ko'rsatuvchi tugma (modalni ochadi). */
export function RegionField({ value, multiple = false, placeholder, onOpen, disabled = false }) {
  const keys = multiple ? value || [] : value ? [value] : [];
  return (
    <button
      type="button"
      onClick={onOpen}
      disabled={disabled}
      className="input flex min-h-[2.75rem] w-full flex-wrap items-center gap-1.5 text-left"
    >
      {keys.length === 0 && <span style={{ color: "var(--muted)" }}>{placeholder}</span>}
      {keys.map((k) => (
        <span
          key={k}
          className="rounded-full px-2.5 py-0.5 text-xs font-semibold"
          style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)" }}
        >
          {nameOf(k)}
        </span>
      ))}
    </button>
  );
}
