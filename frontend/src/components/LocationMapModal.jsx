import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Search, X } from "lucide-react";
import { fixCoord, reverseGeocode, searchPlaces } from "../geo";

const DEFAULT_CENTER = [41.311081, 69.240562]; // Toshkent
const PIN = L.divIcon({
  className: "",
  iconSize: [30, 40],
  iconAnchor: [15, 40],
  html:
    '<svg width="30" height="40" viewBox="0 0 30 40" xmlns="http://www.w3.org/2000/svg">' +
    '<path d="M15 0C6.7 0 0 6.7 0 15c0 11 15 25 15 25s15-14 15-25C30 6.7 23.3 0 15 0z" fill="#d94f3d"/>' +
    '<circle cx="15" cy="15" r="6" fill="#fff"/></svg>',
});

// Xaritadan nuqta tanlash: bosish yoki markerni sudrash; manzil bo'yicha qidirish mumkin.
export default function LocationMapModal({ initial, onConfirm, onClose }) {
  const mapEl = useRef(null);
  const map = useRef(null);
  const marker = useRef(null);
  const [point, setPoint] = useState(initial || null);
  const [query, setQuery] = useState("");
  const [results, setResults] = useState([]);
  const [busy, setBusy] = useState(false);
  const [closing, setClosing] = useState(false);

  const close = () => {
    setClosing(true);
    setTimeout(onClose, 160);
  };

  useEffect(() => {
    const start = initial ? [initial.latitude, initial.longitude] : DEFAULT_CENTER;
    const m = L.map(mapEl.current).setView(start, initial ? 16 : 12);
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap",
    }).addTo(m);
    map.current = m;

    const place = (lat, lng) => {
      if (marker.current) {
        marker.current.setLatLng([lat, lng]);
      } else {
        marker.current = L.marker([lat, lng], { icon: PIN, draggable: true }).addTo(m);
        marker.current.on("dragend", () => {
          const p = marker.current.getLatLng();
          setPoint({ latitude: p.lat, longitude: p.lng });
        });
      }
      setPoint({ latitude: lat, longitude: lng });
    };
    if (initial) place(initial.latitude, initial.longitude);
    m.on("click", (e) => place(e.latlng.lat, e.latlng.lng));
    map.current.placeMarker = place;

    // Modal animatsiyasi tugagach xarita o'lchamini qayta hisoblash (aks holda kulrang bo'laklar qoladi).
    const t = setTimeout(() => m.invalidateSize(), 320);
    return () => {
      clearTimeout(t);
      m.remove();
      map.current = null;
      marker.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const search = async () => {
    if (!query.trim()) return;
    setResults(await searchPlaces(query.trim()));
  };

  const goTo = (p) => {
    map.current.setView([p.latitude, p.longitude], 16);
    map.current.placeMarker(p.latitude, p.longitude);
    setResults([]);
  };

  const confirm = async () => {
    setBusy(true);
    const address = await reverseGeocode(point.latitude, point.longitude);
    onConfirm({ latitude: point.latitude, longitude: point.longitude, address });
    close();
  };

  return createPortal(
    <div
      className={`picker-backdrop fixed inset-0 z-[70] flex items-center justify-center bg-black/40 p-4 ${closing ? "picker-closing" : ""}`}
      onClick={(e) => { e.stopPropagation(); close(); }}
      onKeyDown={(e) => { if (e.key === "Escape") close(); }}
    >
      <div
        className="picker-panel card flex w-full max-w-2xl flex-col gap-3 p-4"
        style={{ maxHeight: "92vh" }}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h4 className="text-base font-semibold">Xaritadan joyni tanlang</h4>
          <button type="button" className="icon-btn" onClick={close}><X size={16} /></button>
        </div>

        <div className="relative">
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
              <input
                className="input !pl-9" placeholder="Manzil bo'yicha qidirish (masalan Chilonzor, Toshkent)…"
                value={query} onChange={(e) => setQuery(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); search(); } }}
              />
            </div>
            <button type="button" className="btn-ghost !px-3 text-xs" onClick={search}>Qidirish</button>
          </div>
          {results.length > 0 && (
            <div className="card absolute left-0 right-0 top-full z-[1000] mt-1 flex max-h-48 flex-col overflow-y-auto p-1">
              {results.map((p) => (
                <button
                  key={`${p.latitude},${p.longitude}`} type="button"
                  className="rounded-md px-3 py-2 text-left text-xs hover:bg-black/5"
                  onClick={() => goTo(p)}
                >
                  {p.name}
                </button>
              ))}
            </div>
          )}
        </div>

        <div ref={mapEl} className="w-full overflow-hidden rounded-xl" style={{ height: 360, border: "1px solid var(--border)" }} />

        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            {point
              ? `Tanlangan: ${fixCoord(point.latitude)}, ${fixCoord(point.longitude)}`
              : "Xaritani bosib nuqta belgilang (markerni sudrash ham mumkin)."}
          </span>
          <div className="flex gap-2">
            <button type="button" className="btn-ghost !px-3 !py-1.5 text-xs" onClick={close}>Bekor</button>
            <button type="button" className="btn !px-3 !py-1.5 text-xs" disabled={!point || busy} onClick={confirm}>
              {busy ? "Manzil aniqlanmoqda…" : "Tasdiqlash"}
            </button>
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
}
