import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { Check, Search, X } from "lucide-react";
import { api } from "../../api";

// Xom ashyo tanlash oynasi: nom bo'yicha real-time qidiruv (backend `?search=`
// — katta-kichik harfga bog'liq bo'lmagan ILIKE), natija ro'yxat ko'rinishida.
export default function MaterialPicker({ selectedId, onSelect, onClose }) {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [active, setActive] = useState(0);
  const [closing, setClosing] = useState(false);
  const requestId = useRef(0);
  const inputRef = useRef(null);

  const close = () => {
    setClosing(true);
    setTimeout(onClose, 160);
  };

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    const id = ++requestId.current;
    setLoading(true);
    const timer = setTimeout(async () => {
      try {
        const d = await api(`/materials/?page_size=50&search=${encodeURIComponent(query.trim())}`);
        if (id !== requestId.current) return;
        setItems(d.results || []);
        setActive(0);
        setError("");
      } catch (e) {
        if (id === requestId.current) setError(e.message);
      } finally {
        if (id === requestId.current) setLoading(false);
      }
    }, query ? 250 : 0);
    return () => clearTimeout(timer);
  }, [query]);

  const choose = (material) => {
    onSelect(material);
    close();
  };

  const onKeyDown = (e) => {
    if (e.key === "Escape") {
      e.stopPropagation();
      close();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((i) => Math.min(i + 1, items.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (items[active]) choose(items[active]);
    }
  };

  return createPortal(
    <div
      className={`picker-backdrop fixed inset-0 z-[60] flex items-center justify-center bg-black/40 p-4 ${closing ? "picker-closing" : ""}`}
      onClick={(e) => { e.stopPropagation(); close(); }}
      onKeyDown={onKeyDown}
    >
      <div
        className="picker-panel card flex w-full max-w-md flex-col gap-3 p-4"
        style={{ maxHeight: "80vh" }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h4 className="text-base font-semibold">Xom ashyoni tanlang</h4>
          <button type="button" className="icon-btn" onClick={close}><X size={16} /></button>
        </div>
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
          <input
            ref={inputRef}
            className="input !pl-9"
            placeholder="Nomi bo'yicha qidirish…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>

        <div className="flex min-h-[120px] flex-col gap-1 overflow-y-auto" style={{ opacity: loading ? 0.6 : 1, transition: "opacity .15s" }}>
          <button
            type="button"
            className="picker-item flex items-center justify-between rounded-lg px-3 py-2 text-left text-sm"
            style={{ color: "var(--muted)", border: "1px dashed var(--border)" }}
            onClick={() => choose(null)}
          >
            — Tanlanmagan —
            {!selectedId && <Check size={15} />}
          </button>
          {error && <div className="error">{error}</div>}
          {!loading && !error && items.length === 0 && (
            <p className="py-6 text-center text-sm" style={{ color: "var(--muted)" }}>Hech narsa topilmadi.</p>
          )}
          {items.map((m, i) => (
            <button
              key={m.id}
              type="button"
              className="picker-item flex items-center justify-between gap-3 rounded-lg px-3 py-2 text-left text-sm transition-colors"
              style={{
                animationDelay: `${Math.min(i, 12) * 22}ms`,
                background: i === active ? "color-mix(in srgb, var(--primary) 22%, transparent)" : "transparent",
              }}
              onMouseEnter={() => setActive(i)}
              onClick={() => choose(m)}
            >
              <span className="min-w-0">
                <span className="block truncate font-medium">{m.name}</span>
                <span className="block text-xs" style={{ color: "var(--muted)" }}>
                  {Number(m.unit_cost).toLocaleString()} so'm / {m.unit_display || m.unit}
                </span>
              </span>
              {m.id === selectedId && <Check size={16} />}
            </button>
          ))}
        </div>
      </div>
    </div>,
    document.body
  );
}
