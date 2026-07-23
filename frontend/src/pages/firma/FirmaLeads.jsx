import { useEffect, useState } from "react";
import { X, Phone, Sofa, MessageSquare, Wallet } from "lucide-react";
import { api } from "../../api";
import { LEAD_SOURCE, LEAD_STATUS, NOTE_KIND, PIPELINE } from "../../leadStatus";

export default function FirmaLeads() {
  const [leads, setLeads] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [active, setActive] = useState(null);

  const load = () =>
    api("/leads/")
      .then((d) => setLeads(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  useEffect(() => {
    if (active) {
      const fresh = leads.find((l) => l.id === active.id);
      if (fresh) setActive(fresh);
    }
  }, [leads]);

  const byStatus = (s) => leads.filter((l) => l.status === s);
  const lostCount = leads.filter((l) => l.status === "lost").length;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div className="flex flex-wrap gap-2">
          {PIPELINE.map((s) => {
            const Icon = LEAD_STATUS[s].icon;
            return (
              <span key={s} className="badge badge-brand inline-flex items-center gap-1">
                <Icon size={12} /> {LEAD_STATUS[s].label} ({byStatus(s).length})
              </span>
            );
          })}
          {lostCount > 0 && (
            <span className="badge badge-off inline-flex items-center gap-1">
              <X size={12} /> Yo'qotildi ({lostCount})
            </span>
          )}
        </div>
        <button className="btn" onClick={() => setShowForm(true)}>+ Yangi lead</button>
      </div>

      {error && <div className="error">{error}</div>}

      {/* Kanban pipeline */}
      <div className="grid grid-cols-1 gap-4 overflow-x-auto md:grid-cols-3 xl:grid-cols-5">
        {PIPELINE.map((s) => {
          const StageIcon = LEAD_STATUS[s].icon;
          return (
          <div key={s} className="flex min-w-[220px] flex-col gap-3">
            <div className="flex items-center gap-2 text-sm font-semibold">
              <StageIcon size={15} />
              <span>{LEAD_STATUS[s].label}</span>
              <span style={{ color: "var(--muted)" }}>({byStatus(s).length})</span>
            </div>
            <div className="flex flex-col gap-2">
              {byStatus(s).map((l) => (
                <button
                  key={l.id}
                  onClick={() => setActive(l)}
                  className="card flex flex-col gap-1 p-3 text-left transition hover:-translate-y-0.5"
                >
                  <span className="font-medium">{l.name}</span>
                  <span className="inline-flex items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
                    <Phone size={11} /> {l.phone}
                  </span>
                  {l.interested_product && (
                    <span className="inline-flex items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
                      <Sofa size={11} /> {l.interested_product}
                    </span>
                  )}
                  <div className="mt-1 flex items-center justify-between">
                    <span className="text-[10px]" style={{ color: "var(--muted)" }}>
                      {LEAD_SOURCE[l.source]}
                    </span>
                    {l.notes_count > 0 && (
                      <span className="inline-flex items-center gap-1 text-[10px]" style={{ color: "var(--muted)" }}>
                        <MessageSquare size={10} /> {l.notes_count}
                      </span>
                    )}
                  </div>
                </button>
              ))}
              {byStatus(s).length === 0 && (
                <div className="rounded-xl p-3 text-center text-xs" style={{ border: "1px dashed var(--border)", color: "var(--muted)" }}>
                  Bo'sh
                </div>
              )}
            </div>
          </div>
          );
        })}
      </div>

      {showForm && <LeadForm onClose={() => setShowForm(false)} onDone={() => { setShowForm(false); load(); }} />}
      {active && <LeadDetail lead={active} onClose={() => setActive(null)} onChanged={load} />}
    </div>
  );
}

function LeadForm({ onClose, onDone }) {
  const [form, setForm] = useState({
    name: "", phone: "", interested_product: "", budget: "", source: "other",
  });
  const [error, setError] = useState("");
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      await api("/leads/", { method: "POST", body: { ...form, budget: form.budget || null } });
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-md flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 className="text-base font-semibold">Yangi lead</h2>
        <div>
          <label className="label">Ism *</label>
          <input className="input" value={form.name} onChange={set("name")} required />
        </div>
        <div>
          <label className="label">Telefon *</label>
          <input className="input" value={form.phone} onChange={set("phone")} placeholder="+998…" required />
        </div>
        <div>
          <label className="label">Qiziqqan mahsulot</label>
          <input className="input" value={form.interested_product} onChange={set("interested_product")} />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Budjet (so'm)</label>
            <input className="input" type="number" min="0" value={form.budget} onChange={set("budget")} />
          </div>
          <div>
            <label className="label">Manba</label>
            <select className="input" value={form.source} onChange={set("source")}>
              {Object.entries(LEAD_SOURCE).map(([k, v]) => (
                <option key={k} value={k}>{v}</option>
              ))}
            </select>
          </div>
        </div>
        {error && <div className="error">{error}</div>}
        <div className="flex gap-2">
          <button className="btn" type="submit">Saqlash</button>
          <button className="btn-ghost" type="button" onClick={onClose}>Bekor</button>
        </div>
      </form>
    </div>
  );
}

function LeadDetail({ lead, onClose, onChanged }) {
  const [note, setNote] = useState("");
  const [kind, setKind] = useState("call");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const setStatus = async (status) => {
    try {
      await api(`/leads/${lead.id}/`, { method: "PATCH", body: { status } });
      onChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const addNote = async (e) => {
    e.preventDefault();
    if (!note.trim()) return;
    setBusy(true);
    setError("");
    try {
      await api(`/leads/${lead.id}/add_note/`, { method: "POST", body: { kind, text: note } });
      setNote("");
      onChanged();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="card flex max-h-[85vh] w-full max-w-lg flex-col gap-4 overflow-y-auto p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between">
          <div>
            <h2 className="text-lg font-bold">{lead.name}</h2>
            <p className="inline-flex items-center gap-1 text-sm" style={{ color: "var(--muted)" }}>
              <Phone size={13} /> {lead.phone} · {LEAD_SOURCE[lead.source]}
            </p>
          </div>
          <button className="btn-ghost !px-2 !py-1" onClick={onClose}><X size={15} /></button>
        </div>

        {lead.interested_product && (
          <p className="flex items-center gap-1 text-sm"><Sofa size={14} /> <strong>{lead.interested_product}</strong></p>
        )}
        {lead.budget && (
          <p className="flex items-center gap-1 text-sm"><Wallet size={14} /> Budjet: {Number(lead.budget).toLocaleString()} so'm</p>
        )}

        <div>
          <label className="label">Status</label>
          <div className="flex flex-wrap gap-2">
            {Object.entries(LEAD_STATUS).map(([k, s]) => {
              const Icon = s.icon;
              return (
                <button
                  key={k}
                  onClick={() => setStatus(k)}
                  className="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium transition"
                  style={
                    lead.status === k
                      ? { background: s.color, color: "#fff" }
                      : { border: "1px solid var(--border)", color: "var(--muted)" }
                  }
                >
                  <Icon size={12} /> {s.label}
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <label className="label">Aloqa tarixi ({lead.notes_count})</label>
          <div className="flex flex-col gap-2">
            {lead.notes.map((n) => {
              const NoteIcon = NOTE_KIND[n.kind]?.icon;
              return (
                <div key={n.id} className="rounded-lg p-3 text-sm" style={{ background: "color-mix(in srgb, var(--primary) 12%, transparent)" }}>
                  <div className="mb-1 flex items-center justify-between text-xs" style={{ color: "var(--muted)" }}>
                    <span className="inline-flex items-center gap-1">
                      {NoteIcon && <NoteIcon size={11} />} {NOTE_KIND[n.kind]?.label} · {n.author_name}
                    </span>
                    <span>{new Date(n.created_at).toLocaleString("uz-UZ")}</span>
                  </div>
                  {n.text}
                </div>
              );
            })}
            {lead.notes.length === 0 && (
              <p className="text-xs" style={{ color: "var(--muted)" }}>Hali aloqa yo'q.</p>
            )}
          </div>
        </div>

        <form className="flex flex-col gap-2" onSubmit={addNote}>
          <div className="flex gap-2">
            <select className="input !w-40" value={kind} onChange={(e) => setKind(e.target.value)}>
              {Object.entries(NOTE_KIND).map(([k, v]) => (
                <option key={k} value={k}>{v.label}</option>
              ))}
            </select>
            <input
              className="input flex-1"
              placeholder="Yozing…"
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </div>
          {error && <div className="error">{error}</div>}
          <button className="btn self-start" type="submit" disabled={busy}>
            {busy ? "Saqlanmoqda…" : "+ Qo'shish"}
          </button>
        </form>
      </div>
    </div>
  );
}
