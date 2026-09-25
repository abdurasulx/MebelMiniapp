import { useState } from "react";
import { LocateFixed, Map as MapIcon } from "lucide-react";
import { currentPosition, fixCoord, reverseGeocode } from "../geo";
import LocationMapModal from "./LocationMapModal";

// Joylashuvni ikki usulda belgilash: xaritadan tanlash yoki hozirgi joylashuvni olish.
// `value` = { address, latitude, longitude } (latitude/longitude bo'sh satr yoki son).
export default function LocationPicker({ value, onChange, required = true }) {
  const [showMap, setShowMap] = useState(false);
  const [locating, setLocating] = useState(false);
  const [error, setError] = useState("");

  const hasPoint = value.latitude !== "" && value.latitude != null && value.longitude !== "" && value.longitude != null;

  const apply = (p, address) =>
    onChange({
      latitude: fixCoord(p.latitude),
      longitude: fixCoord(p.longitude),
      address: address || value.address || `${fixCoord(p.latitude)}, ${fixCoord(p.longitude)}`,
    });

  const useCurrent = async () => {
    setError("");
    setLocating(true);
    try {
      const p = await currentPosition();
      apply(p, await reverseGeocode(p.latitude, p.longitude));
    } catch (e) {
      setError(e.message);
    } finally {
      setLocating(false);
    }
  };

  return (
    <div className="flex flex-col gap-2">
      <input
        className="input" value={value.address} required={required}
        placeholder="Manzilni yozing yoki xaritadan / hozirgi joylashuvdan belgilang"
        onChange={(e) => onChange({ address: e.target.value })}
      />
      <div className="flex flex-wrap items-center gap-2">
        <button type="button" className="btn-ghost inline-flex items-center gap-1.5 !px-3 !py-1.5 text-xs" onClick={() => setShowMap(true)}>
          <MapIcon size={14} /> Xaritadan tanlash
        </button>
        <button
          type="button" className="btn-ghost inline-flex items-center gap-1.5 !px-3 !py-1.5 text-xs"
          onClick={useCurrent} disabled={locating}
        >
          <LocateFixed size={14} /> {locating ? "Aniqlanmoqda…" : "Hozirgi joylashuvim"}
        </button>
        {hasPoint && (
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            Koordinata: {fixCoord(value.latitude)}, {fixCoord(value.longitude)}
          </span>
        )}
      </div>
      {error && <div className="error">{error}</div>}
      {showMap && (
        <LocationMapModal
          initial={hasPoint ? { latitude: Number(value.latitude), longitude: Number(value.longitude) } : null}
          onClose={() => setShowMap(false)}
          onConfirm={(p) => apply(p, p.address)}
        />
      )}
    </div>
  );
}
