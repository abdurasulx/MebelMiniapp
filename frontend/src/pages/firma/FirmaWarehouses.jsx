import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Warehouse as WarehouseIcon, Boxes, Package, ChevronRight, Pencil, Trash2, AlertTriangle, PackageX, Plus } from "lucide-react";
import { api } from "../../api";

const KIND_ICON = { raw_material: Boxes, finished_goods: Package };

export default function FirmaWarehouses() {
  const [list, setList] = useState([]);
  const [lowStock, setLowStock] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: "", kind: "raw_material", address: "" });
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState(null);

  const load = () =>
    Promise.all([api("/warehouses/"), api("/materials/low-stock/").catch(() => [])])
      .then(([w, low]) => {
        setList(w.results || []);
        setLowStock(low || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const rawWarehouses = list.filter((w) => w.kind === "raw_material");

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

  const removeWarehouse = async (wh) => {
    if (!confirm(`"${wh.name}" ombori o'chirilsinmi?`)) return;
    try {
      await api(`/warehouses/${wh.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
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

      {lowStock.length > 0 && (
        <div className="card p-5" style={{ borderColor: "var(--warning)" }}>
          <h2 className="mb-4 inline-flex items-center gap-2 text-base font-semibold" style={{ color: "var(--warning)" }}>
            <AlertTriangle size={17} /> Kam qolgan xom ashyo ({lowStock.length})
          </h2>
          <div className="flex flex-col gap-2">
            {lowStock.map((m) => (
              <LowStockRow key={m.id} material={m} warehouses={rawWarehouses} onRestocked={load} />
            ))}
          </div>
        </div>
      )}

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
              <label className="label">Manzil (lokatsiya) *</label>
              <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} required />
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
              <div key={wh.id}>
                <div className="flex items-center gap-3 p-4">
                  <Link to={`/warehouses/${wh.id}`} className="flex min-w-0 flex-1 items-center gap-3">
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
                      </div>
                    </div>
                  </Link>
                  <button
                    className="btn-ghost !px-2 !py-2"
                    title="Tahrirlash"
                    onClick={() => setEditing(editing === wh.id ? null : wh.id)}
                  >
                    <Pencil size={15} />
                  </button>
                  <button
                    className="btn-ghost !px-2 !py-2"
                    title="O'chirish"
                    style={{ color: "var(--danger)" }}
                    onClick={() => removeWarehouse(wh)}
                  >
                    <Trash2 size={15} />
                  </button>
                  <Link to={`/warehouses/${wh.id}`}>
                    <ChevronRight size={18} style={{ color: "var(--muted)" }} />
                  </Link>
                </div>
                {editing === wh.id && (
                  <div className="px-4 pb-4">
                    <WarehouseEditForm
                      warehouse={wh}
                      onClose={() => setEditing(null)}
                      onSaved={() => {
                        setEditing(null);
                        load();
                      }}
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

/** Kam qolgan material qatori — "+ Kirim" bosilsa shu yerning o'zida
 * qaysi (xom ashyo) omborga va qancha miqdorda kirim qilinishini so'raydi,
 * navigatsiyasiz to'g'ridan-to'g'ri /warehouses/<id>/material-movements/
 * ga yuboradi (backend MaterialMovementViewSet allaqachon mavjud). */
function LowStockRow({ material, warehouses, onRestocked }) {
  const [open, setOpen] = useState(false);
  const [warehouseId, setWarehouseId] = useState(warehouses[0]?.id || "");
  const [quantity, setQuantity] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const submit = async (e) => {
    e.preventDefault();
    if (!warehouseId || !quantity) return;
    setError("");
    setBusy(true);
    try {
      await api(`/warehouses/${warehouseId}/material-movements/`, {
        method: "POST",
        body: { material: material.id, movement_type: "in", quantity, note: "Kam qolgan ta'minotni to'ldirish" },
      });
      setQuantity("");
      setOpen(false);
      onRestocked();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="rounded-xl p-3" style={{ border: "1px solid var(--border)" }}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="inline-flex items-center gap-2 text-sm font-medium">
          <PackageX size={15} style={{ color: "var(--warning)" }} /> {material.name}
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs" style={{ color: "var(--muted)" }}>
            {material.current_stock} / {material.min_stock} {material.unit_display}
            {material.default_supplier_name && ` · ${material.default_supplier_name}`}
          </span>
          <button
            className="btn-ghost inline-flex items-center gap-1 !px-2 !py-1 text-xs"
            onClick={() => setOpen((v) => !v)}
          >
            <Plus size={12} /> Kirim
          </button>
        </div>
      </div>
      {open && (
        <form className="mt-3 flex flex-wrap items-end gap-2" onSubmit={submit}>
          {warehouses.length > 1 && (
            <div>
              <label className="label">Ombor</label>
              <select className="input !py-1.5 text-xs" value={warehouseId} onChange={(e) => setWarehouseId(e.target.value)}>
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>{w.name}</option>
                ))}
              </select>
            </div>
          )}
          <div>
            <label className="label">Miqdor ({material.unit_display})</label>
            <input
              className="input !w-28 !py-1.5 text-xs"
              type="number" step="0.001" min="0.001"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
              required
              autoFocus
            />
          </div>
          <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy || warehouses.length === 0}>
            {busy ? "Saqlanmoqda…" : "Qo'shish"}
          </button>
          <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setOpen(false)}>Bekor</button>
          {warehouses.length === 0 && (
            <span className="text-xs" style={{ color: "var(--danger)" }}>Avval xom ashyo ombori yarating</span>
          )}
          {error && <div className="error w-full">{error}</div>}
        </form>
      )}
    </div>
  );
}

function WarehouseEditForm({ warehouse, onClose, onSaved }) {
  const [form, setForm] = useState({ name: warehouse.name, kind: warehouse.kind, address: warehouse.address || "" });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(`/warehouses/${warehouse.id}/`, { method: "PATCH", body: form });
      onSaved();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      className="flex flex-wrap items-end gap-3 rounded-xl p-4"
      style={{ border: "1px dashed var(--border)" }}
      onSubmit={submit}
    >
      <div style={{ minWidth: 160 }}>
        <label className="label">Ombor nomi</label>
        <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
      </div>
      <div>
        <label className="label">Turi</label>
        <select className="input" value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
          <option value="raw_material">Xom ashyo ombori</option>
          <option value="finished_goods">Tayyor mahsulot ombori</option>
        </select>
      </div>
      <div style={{ minWidth: 200, flex: 1 }}>
        <label className="label">Manzil *</label>
        <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} required />
      </div>
      {error && <div className="error">{error}</div>}
      <div className="flex gap-2">
        <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</button>
        <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={onClose}>Bekor</button>
      </div>
    </form>
  );
}
