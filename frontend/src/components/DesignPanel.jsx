import { useEffect, useState } from "react";
import { CheckCircle2, PenTool, Upload } from "lucide-react";
import { api } from "../api";
import { useAuth } from "../auth";
import { TASK_STAGE } from "../taskStage";

const STAGE_ORDER = ["cutting", "edge_processing", "assembly", "painting", "quality_control", "installation", "delivery", "other"];

/// CUSTOM_PROJECT buyurtmaning dizayn holati: versiyalar (V1, V2, ...),
/// yangi versiya yuklash, tasdiqlash, ishlab chiqarish ketma-ketligini
/// belgilash — backend `apps.custom_orders` bilan mos (docs "Buyurtma va
/// ishlab chiqarish tizimi" §5).
export default function DesignPanel({ orderId }) {
  const { user } = useAuth();
  const [design, setDesign] = useState(null);
  const [error, setError] = useState("");
  const [notes, setNotes] = useState("");
  const [glbFile, setGlbFile] = useState(null);
  const [usdzFile, setUsdzFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [sequenceDraft, setSequenceDraft] = useState([]);

  const load = () =>
    api(`/designs/?order=${orderId}`)
      .then((d) => {
        const found = (d.results || [])[0] || null;
        setDesign(found);
        setSequenceDraft(found?.production_sequence || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [orderId]);

  if (!design) return null;

  const toggleStage = (stage) =>
    setSequenceDraft((prev) => (prev.includes(stage) ? prev.filter((s) => s !== stage) : [...prev, stage]));

  const saveSequence = async () => {
    setBusy(true);
    setError("");
    try {
      await api(`/designs/${design.id}/production-sequence/`, {
        method: "PATCH",
        body: { production_sequence: sequenceDraft },
      });
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const uploadVersion = async (e) => {
    e.preventDefault();
    if (!glbFile && !usdzFile) {
      setError("Kamida bitta 3D fayl (GLB yoki USDZ) tanlang");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const fd = new FormData();
      fd.append("notes", notes);
      if (glbFile) fd.append("glb_file", glbFile);
      if (usdzFile) fd.append("usdz_file", usdzFile);
      await api(`/designs/${design.id}/versions/`, { method: "POST", body: fd, isForm: true });
      setNotes("");
      setGlbFile(null);
      setUsdzFile(null);
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const approve = async (versionId) => {
    if (!confirm("Shu versiya tasdiqlansinmi? Tasdiqlangach ishlab chiqarish boshlanishi mumkin bo'ladi.")) return;
    setBusy(true);
    setError("");
    try {
      await api(`/design-versions/${versionId}/approve/`, { method: "POST" });
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="card flex flex-col gap-4 p-5">
      <div className="flex items-center gap-2">
        <PenTool size={16} />
        <h2 className="text-base font-semibold">Dizayn</h2>
      </div>

      {error && <div className="error">{error}</div>}

      <div className="flex flex-col gap-2">
        {design.versions.length === 0 && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali versiya yuklanmagan.</p>
        )}
        {design.versions.map((v) => (
          <div key={v.id} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border p-3 text-sm" style={{ borderColor: "var(--border)" }}>
            <div>
              <span className="font-semibold">V{v.version_number}</span>
              {v.is_approved && <span className="badge ml-1.5">Tasdiqlangan</span>}
              {v.notes && <div className="text-xs" style={{ color: "var(--muted)" }}>{v.notes}</div>}
              <div className="mt-1 flex gap-2 text-xs">
                {v.glb_url && <a href={v.glb_url} target="_blank" rel="noreferrer" className="underline">GLB</a>}
                {v.usdz_url && <a href={v.usdz_url} target="_blank" rel="noreferrer" className="underline">USDZ</a>}
              </div>
            </div>
            {!v.is_approved && user?.role === "company_owner" && (
              <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => approve(v.id)} disabled={busy}>
                <CheckCircle2 size={13} /> Tasdiqlash
              </button>
            )}
          </div>
        ))}
      </div>

      <form onSubmit={uploadVersion} className="flex flex-wrap items-end gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
        <div className="min-w-[160px] flex-1">
          <label className="label">Izoh</label>
          <input className="input" value={notes} onChange={(e) => setNotes(e.target.value)} />
        </div>
        <div>
          <label className="label">GLB fayl</label>
          <input className="input" type="file" accept=".glb,.gltf" onChange={(e) => setGlbFile(e.target.files[0])} />
        </div>
        <div>
          <label className="label">USDZ fayl (iOS)</label>
          <input className="input" type="file" accept=".usdz" onChange={(e) => setUsdzFile(e.target.files[0])} />
        </div>
        <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
          <Upload size={13} /> Yangi versiya
        </button>
      </form>

      <div className="border-t pt-3" style={{ borderColor: "var(--border)" }}>
        <div className="mb-2 text-sm font-medium">Ishlab chiqarish ketma-ketligi</div>
        <div className="flex flex-wrap gap-1.5">
          {STAGE_ORDER.map((stage) => {
            const active = sequenceDraft.includes(stage);
            const idx = sequenceDraft.indexOf(stage);
            return (
              <button
                key={stage}
                type="button"
                className={active ? "badge badge-brand" : "badge badge-off"}
                onClick={() => toggleStage(stage)}
              >
                {active && `${idx + 1}. `}{TASK_STAGE[stage].label}
              </button>
            );
          })}
        </div>
        <button className="btn-ghost mt-2 !px-3 !py-1.5 text-xs" onClick={saveSequence} disabled={busy}>
          Ketma-ketlikni saqlash
        </button>
      </div>
    </div>
  );
}
