import { useState } from "react";
import { ChevronDown, ChevronRight, Plus, Trash2 } from "lucide-react";
import MaterialPicker from "./MaterialPicker";
import { api } from "../../api";
import { POSITIONS } from "../../positions";
import { STAGES, emptyPerson, newId } from "./bazisState";

const MATERIAL_UNITS = ["dona", "kg", "m", "m2", "m3", "litr"];

function PersonPicker({ value, onChange, employees }) {
  return (
    <div className="flex flex-wrap items-center gap-1.5 text-xs">
      <span style={{ color: "var(--muted)" }}>Mas'ul:</span>
      <select
        className="input !w-auto !py-1 text-xs"
        value={value.mode}
        onChange={(e) => onChange({ ...value, mode: e.target.value })}
      >
        <option value="role">Ochiq (rol bo'yicha)</option>
        <option value="employee">Aniq usta</option>
      </select>
      {value.mode === "role" ? (
        <select
          className="input !w-auto !py-1 text-xs"
          value={value.role}
          onChange={(e) => onChange({ ...value, role: e.target.value })}
        >
          <option value="">Rol tanlang…</option>
          {Object.entries(POSITIONS).map(([key, p]) => (
            <option key={key} value={key}>{p.label}</option>
          ))}
        </select>
      ) : (
        <select
          className="input !w-auto !py-1 text-xs"
          value={value.employeeId}
          onChange={(e) => onChange({ ...value, employeeId: e.target.value })}
        >
          <option value="">Usta tanlang…</option>
          {employees.map((emp) => (
            <option key={emp.id} value={emp.id}>{emp.user_name || emp.user_email}</option>
          ))}
        </select>
      )}
    </div>
  );
}

function StageCard({ title, summary, person, onPersonChange, employees, open, onToggle, onRemove, children }) {
  return (
    <div className="flex flex-col gap-2 rounded-lg border p-2.5" style={{ borderColor: "var(--border)" }}>
      <div className="flex items-center gap-1.5">
        <button type="button" className="icon-btn" onClick={onToggle} aria-expanded={open}>
          {open ? <ChevronDown size={15} /> : <ChevronRight size={15} />}
        </button>
        <div className="min-w-0 flex-1 text-sm font-medium">{title}</div>
        {summary && <span className="text-xs" style={{ color: "var(--muted)" }}>{summary}</span>}
        {onRemove && (
          <button type="button" className="icon-btn" title="Etapni o'chirish" onClick={onRemove}>
            <Trash2 size={14} />
          </button>
        )}
      </div>
      <PersonPicker value={person} onChange={onPersonChange} employees={employees} />
      {open && <div className="flex flex-col gap-1.5 border-t pt-2" style={{ borderColor: "var(--border)" }}>{children}</div>}
    </div>
  );
}

function ProductionTab({ preview, state, setState, employees }) {
  const [open, setOpen] = useState({});
  const toggle = (key) => setOpen((prev) => ({ ...prev, [key]: !prev[key] }));
  const patch = (p) => setState((prev) => ({ ...prev, ...p }));

  const patchExtra = (id, p) =>
    patch({ extraStages: state.extraStages.map((s) => (s.id === id ? { ...s, ...p } : s)) });
  const patchJob = (stage, jobId, p) =>
    patchExtra(stage.id, { jobs: stage.jobs.map((j) => (j.id === jobId ? { ...j, ...p } : j)) });

  const addStage = () => {
    const id = newId();
    patch({ extraStages: [...state.extraStages, { id, name: "", ...emptyPerson(), jobs: [] }] });
    setOpen((prev) => ({ ...prev, [id]: true }));
  };

  return (
    <div className="flex flex-col gap-2">
      {STAGES.map(({ key, label }) => {
        const groups = (preview.groups || []).filter((g) => g.stage === key);
        if (groups.length === 0) return null;
        const total = groups.reduce((sum, g) => sum + Number(g.quantity || 0), 0);
        return (
          <StageCard
            key={key}
            title={label}
            summary={`${groups.length} ta ish · ${total} dona`}
            person={state.stagePerson[key]}
            onPersonChange={(p) => patch({ stagePerson: { ...state.stagePerson, [key]: p } })}
            employees={employees}
            open={!!open[key]}
            onToggle={() => toggle(key)}
          >
            <span style={{ fontSize: 11.5, color: "var(--muted)" }}>Har bir ish uchun ixtiyoriy narx (dona uchun):</span>
            {groups.map((g) => {
              const gp = state.groupPay[g.name] || { paid: false, price: "" };
              const setPay = (p) => patch({ groupPay: { ...state.groupPay, [g.name]: { ...gp, ...p } } });
              return (
                <div key={g.name} className="flex items-center gap-2 text-xs">
                  <label className="flex flex-1 items-center gap-1.5">
                    <input type="checkbox" checked={gp.paid} onChange={(e) => setPay({ paid: e.target.checked })} />
                    {g.name} <span style={{ color: "var(--muted)" }}>({g.quantity} {g.unit})</span>
                  </label>
                  {gp.paid && (
                    <input
                      className="input !w-24 !py-1 text-xs" type="number" min="0" placeholder="narx"
                      value={gp.price} onChange={(e) => setPay({ price: e.target.value })}
                    />
                  )}
                </div>
              );
            })}
          </StageCard>
        );
      })}

      {state.extraStages.map((stage) => (
        <StageCard
          key={stage.id}
          title={
            <input
              className="input !py-1 text-sm" placeholder="Etap nomi (masalan Yig'ish)"
              value={stage.name} onChange={(e) => patchExtra(stage.id, { name: e.target.value })}
            />
          }
          summary={`${stage.jobs.length} ta ish`}
          person={{ mode: stage.mode, employeeId: stage.employeeId, role: stage.role }}
          onPersonChange={(p) => patchExtra(stage.id, p)}
          employees={employees}
          open={!!open[stage.id]}
          onToggle={() => toggle(stage.id)}
          onRemove={() => patch({ extraStages: state.extraStages.filter((s) => s.id !== stage.id) })}
        >
          {stage.jobs.map((job) => (
            <div key={job.id} className="flex items-center gap-1.5 text-xs">
              <input
                className="input !py-1 text-xs flex-1" placeholder="Ish nomi"
                value={job.name} onChange={(e) => patchJob(stage, job.id, { name: e.target.value })}
              />
              <input
                className="input !w-16 !py-1 text-xs" type="number" min="0" step="any" placeholder="soni" title="Soni"
                value={job.quantity} onChange={(e) => patchJob(stage, job.id, { quantity: e.target.value })}
              />
              <input
                className="input !w-24 !py-1 text-xs" type="number" min="0" placeholder="narx" title="Narxi (dona uchun)"
                value={job.price} onChange={(e) => patchJob(stage, job.id, { price: e.target.value })}
              />
              <button
                type="button" className="icon-btn" title="Ishni o'chirish"
                onClick={() => patchExtra(stage.id, { jobs: stage.jobs.filter((j) => j.id !== job.id) })}
              >
                <Trash2 size={13} />
              </button>
            </div>
          ))}
          <button
            type="button" className="btn-ghost inline-flex items-center gap-1 self-start !px-2.5 !py-1 text-xs"
            onClick={() => patchExtra(stage.id, { jobs: [...stage.jobs, { id: newId(), name: "", quantity: "1", price: "" }] })}
          >
            <Plus size={12} /> Ish qo'shish
          </button>
        </StageCard>
      ))}

      <button
        type="button" className="btn-ghost inline-flex items-center gap-1 self-start !px-3 !py-1.5 text-xs"
        onClick={addStage}
      >
        <Plus size={13} /> Etap qo'shish
      </button>
    </div>
  );
}

function NewMaterialForm({ defaultName, onCreated, onCancel }) {
  const [name, setName] = useState(defaultName);
  const [unit, setUnit] = useState("dona");
  const [unitCost, setUnitCost] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const save = async () => {
    if (!name.trim()) return;
    setBusy(true);
    setError("");
    try {
      const created = await api("/materials/", {
        method: "POST",
        body: { name: name.trim(), unit, unit_cost: unitCost || "0" },
      });
      onCreated(created);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-1.5 rounded-lg p-2" style={{ background: "color-mix(in srgb, var(--primary) 10%, transparent)" }}>
      <div className="flex flex-wrap items-center gap-1.5 text-xs">
        <input className="input !py-1 text-xs flex-1" placeholder="Xom ashyo nomi" value={name} onChange={(e) => setName(e.target.value)} />
        <select className="input !w-auto !py-1 text-xs" value={unit} onChange={(e) => setUnit(e.target.value)}>
          {MATERIAL_UNITS.map((u) => <option key={u} value={u}>{u}</option>)}
        </select>
        <input
          className="input !w-28 !py-1 text-xs" type="number" min="0" placeholder="narxi (1 birlik)"
          value={unitCost} onChange={(e) => setUnitCost(e.target.value)}
        />
      </div>
      {error && <div className="error">{error}</div>}
      <div className="flex gap-1.5">
        <button type="button" className="btn !px-3 !py-1 text-xs" disabled={busy || !name.trim()} onClick={save}>
          {busy ? "Saqlanmoqda…" : "Saqlash"}
        </button>
        <button type="button" className="btn-ghost !px-3 !py-1 text-xs" onClick={onCancel}>Bekor qilish</button>
      </div>
    </div>
  );
}

function MaterialsTab({ preview, state, setState, companyMaterials, onMaterialCreated }) {
  const [creating, setCreating] = useState(null);
  const [picking, setPicking] = useState(null);
  const materials = preview.materials || [];
  if (materials.length === 0) {
    return <p className="text-xs" style={{ color: "var(--muted)" }}>Faylda xom ashyo topilmadi.</p>;
  }
  const select = (name, id) => setState((prev) => ({ ...prev, materialMap: { ...prev.materialMap, [name]: id } }));

  return (
    <div className="flex flex-col gap-2">
      <span style={{ fontSize: 11.5, color: "var(--muted)" }}>
        Bazis'dagi har bir material uchun ombordagi xom ashyoni tanlang — har buyurtmada boshqacha (arzonroq
        yoki qimmatroq) tanlash mumkin. Omborda yo'q bo'lsa, yangisini narxi bilan qo'shing.
      </span>
      {materials.map((m) => (
        <div key={m.name} className="flex flex-col gap-1.5 rounded-lg border p-2.5" style={{ borderColor: "var(--border)" }}>
          <div className="flex flex-wrap items-center gap-1.5 text-sm">
            <span className="font-medium">{m.name}</span>
            <span className="badge">{m.kind === "sheet" ? "Varaq" : "Kromka"}</span>
            <span className="text-xs" style={{ color: "var(--muted)" }}>{m.quantity} dona</span>
          </div>
          <div className="flex flex-wrap items-center gap-1.5">
            {(() => {
              const chosen = companyMaterials.find((cm) => cm.id === state.materialMap[m.name]);
              return (
                <button
                  type="button"
                  className="input !py-1.5 flex flex-1 items-center justify-between gap-2 text-left text-xs transition hover:brightness-95"
                  onClick={() => setPicking(m.name)}
                >
                  <span className="truncate">
                    {chosen
                      ? `${chosen.name} — ${Number(chosen.unit_cost).toLocaleString()} so'm/${chosen.unit}`
                      : "Ombordan tanlash…"}
                  </span>
                  <ChevronDown size={14} />
                </button>
              );
            })()}
            <button type="button" className="btn-ghost inline-flex items-center gap-1 !px-2.5 !py-1 text-xs" onClick={() => setCreating(m.name)}>
              <Plus size={12} /> Yangi xom ashyo
            </button>
          </div>
          {picking === m.name && (
            <MaterialPicker
              selectedId={state.materialMap[m.name] || null}
              onClose={() => setPicking(null)}
              onSelect={(material) => {
                if (material) onMaterialCreated(material);
                select(m.name, material ? material.id : "");
              }}
            />
          )}
          {creating === m.name && (
            <NewMaterialForm
              defaultName={m.name}
              onCancel={() => setCreating(null)}
              onCreated={(created) => {
                onMaterialCreated(created);
                select(m.name, created.id);
                setCreating(null);
              }}
            />
          )}
        </div>
      ))}
    </div>
  );
}

export default function BazisSetup({ preview, state, setState, employees, companyMaterials, onMaterialCreated }) {
  const [tab, setTab] = useState("production");
  const tabs = [
    { key: "production", label: "Ishlab chiqarish" },
    { key: "materials", label: "Xom ashyo" },
  ];
  return (
    // Enter tugmasi ichki maydonlarda butun buyurtma formasini yuborib yubormasligi uchun.
    <div
      className="flex flex-col gap-2.5"
      onKeyDown={(e) => { if (e.key === "Enter" && e.target.tagName === "INPUT") e.preventDefault(); }}
    >
      <div className="flex gap-2">
        {tabs.map((t) => (
          <button
            key={t.key} type="button"
            className="rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={
              tab === t.key
                ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                : { border: "1px solid var(--border)", color: "var(--muted)" }
            }
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>
      {tab === "production" ? (
        <ProductionTab preview={preview} state={state} setState={setState} employees={employees} />
      ) : (
        <MaterialsTab
          preview={preview} state={state} setState={setState}
          companyMaterials={companyMaterials} onMaterialCreated={onMaterialCreated}
        />
      )}
    </div>
  );
}
