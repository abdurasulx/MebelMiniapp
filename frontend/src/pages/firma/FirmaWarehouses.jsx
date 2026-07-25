import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Warehouse as WarehouseIcon, Boxes, Package, ChevronRight } from "lucide-react";
import { api } from "../../api";

const KIND_ICON = { raw_material: Boxes, finished_goods: Package };

export default function FirmaWarehouses() {
  const [list, setList] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: "", kind: "raw_material", address: "" });
  const [busy, setBusy] = useState(false);

  const load = () =>
    api("/warehouses/")
      .then((d) => setList(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api("/warehouses/", { method: "POST", body: form });
      setForm({ name: "", kind: "raw_material", address: "" });
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Omborlar</h1>
        <button className="btn" onClick={() => setShowForm((v) => !v)}>+ Yangi ombor</button>
      </div>
      <p className="text-sm" style={{ color: "var(--muted)" }}>
        Xom ashyo va tayyor mahsulot uchun alohida-alohida ombor yarating — bitta firmada bir nechta
        ombor bo'lishi mumkin (masalan har filial uchun alohida).
      </p>

      {showForm && (
        <form className="card flex flex-col gap-4 p-5" onSubmit={submit}>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="label">Ombor nomi *</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Turi *</label>
              <select className="input" value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
                <option value="raw_material">Xom ashyo ombori</option>
                <option value="finished_goods">Tayyor mahsulot ombori</option>
              </select>
            </div>
            <div className="sm:col-span-2">
              <label className="label">Manzil (ixtiyoriy)</label>
              <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <div className="flex gap-2">
            <button className="btn" type="submit" disabled={busy}>{busy ? "Yaratilmoqda…" : "Yaratish"}</button>
            <button className="btn-ghost" type="button" onClick={() => setShowForm(false)}>Bekor</button>
          </div>
        </form>
      )}

      {error && !showForm && <div className="error">{error}</div>}

      {list.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali ombor yaratilmagan.</p>
      ) : (
        <div className="card flex flex-col divide-y" style={{ borderColor: "var(--border)" }}>
          {list.map((wh) => {
            const Icon = KIND_ICON[wh.kind] || WarehouseIcon;
            return (
              <Link
                key={wh.id}
                to={`/warehouses/${wh.id}`}
                className="flex items-center gap-3 p-4 transition hover:bg-black/5"
              >
                <div
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  <Icon size={18} />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold">{wh.name}</span>
                    <span className="badge badge-brand">{wh.kind_display}</span>
                  </div>
                  <div className="text-xs" style={{ color: "var(--muted)" }}>
                    {wh.address || "Manzil kiritilmagan"}
                    {wh.branch_viloyat && ` · ${wh.branch_viloyat}`}
                  </div>
                </div>
                <ChevronRight size={18} style={{ color: "var(--muted)" }} />
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
