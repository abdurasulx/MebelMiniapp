import { useEffect, useState } from "react";
import { Truck, Plus, Trash2, AlertTriangle, CheckCircle2, Package } from "lucide-react";
import { api } from "../../api";

export default function FirmaSuppliers() {
  const [tab, setTab] = useState("orders");

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold">Ta'minot</h1>
      <div className="flex gap-2">
        <button
          className="rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            tab === "orders"
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setTab("orders")}
        >
          Xarid buyurtmalari
        </button>
        <button
          className="rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            tab === "suppliers"
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setTab("suppliers")}
        >
          Yetkazib beruvchilar
        </button>
      </div>
      {tab === "orders" ? <PurchaseOrders /> : <Suppliers />}
    </div>
  );
}

/* ================= Yetkazib beruvchilar ================= */

function Suppliers() {
  const [list, setList] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: "", phone: "", address: "", note: "" });
  const [busy, setBusy] = useState(false);

  const load = () =>
    api("/suppliers/")
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
      await api("/suppliers/", { method: "POST", body: form });
      setForm({ name: "", phone: "", address: "", note: "" });
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const remove = async (s) => {
    if (!confirm(`"${s.name}" o'chirilsinmi?`)) return;
    try {
      await api(`/suppliers/${s.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex justify-end">
        <button className="btn inline-flex items-center gap-1" onClick={() => setShowForm((v) => !v)}>
          <Plus size={14} /> Yangi yetkazib beruvchi
        </button>
      </div>

      {showForm && (
        <form className="card flex flex-col gap-4 p-5" onSubmit={submit}>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="label">Nomi *</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Telefon</label>
              <input className="input" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="+998…" />
            </div>
            <div className="sm:col-span-2">
              <label className="label">Manzil</label>
              <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            </div>
            <div className="sm:col-span-2">
              <label className="label">Izoh</label>
              <textarea className="input" rows={2} value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <div className="flex gap-2">
            <button className="btn" type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</button>
            <button className="btn-ghost" type="button" onClick={() => setShowForm(false)}>Bekor</button>
          </div>
        </form>
      )}

      {error && !showForm && <div className="error">{error}</div>}

      {list.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali yetkazib beruvchi qo'shilmagan.</p>
      ) : (
        <div className="card flex flex-col divide-y" style={{ borderColor: "var(--border)" }}>
          {list.map((s) => (
            <div key={s.id} className="flex items-center gap-3 p-4">
              <div
                className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
                style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
              >
                <Truck size={18} />
              </div>
              <div className="min-w-0 flex-1">
                <div className="font-semibold">{s.name}</div>
                <div className="text-xs" style={{ color: "var(--muted)" }}>
                  {s.phone || "Telefon kiritilmagan"}{s.address ? ` · ${s.address}` : ""}
                </div>
              </div>
              <button className="btn-ghost !px-2 !py-2" style={{ color: "#e74c3c" }} onClick={() => remove(s)}>
                <Trash2 size={15} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ================= Xarid buyurtmalari ================= */

function PurchaseOrders() {
  const [orders, setOrders] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [warehouses, setWarehouses] = useState([]);
  const [lowStock, setLowStock] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [busyId, setBusyId] = useState(null);

  const load = () =>
    Promise.all([
      api("/purchase-orders/"),
      api("/suppliers/"),
      api("/materials/"),
      api("/warehouses/"),
      api("/materials/low-stock/"),
    ])
      .then(([o, s, m, w, low]) => {
        setOrders(o.results || []);
        setSuppliers((s.results || []).filter((x) => x.is_active));
        setMaterials((m.results || []).filter((x) => x.is_active));
        setWarehouses((w.results || []).filter((x) => x.kind === "raw_material"));
        setLowStock(low || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const receive = async (order) => {
    setBusyId(order.id);
    setError("");
    try {
      await api(`/purchase-orders/${order.id}/receive/`, { method: "POST", body: {} });
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      {lowStock.length > 0 && (
        <div className="card flex flex-col gap-2 p-4" style={{ borderColor: "#e67e22" }}>
          <div className="inline-flex items-center gap-2 text-sm font-semibold" style={{ color: "#e67e22" }}>
            <AlertTriangle size={16} /> Kam qolgan xom ashyo ({lowStock.length})
          </div>
          <div className="flex flex-wrap gap-2">
            {lowStock.map((m) => (
              <span key={m.id} className="badge" style={{ background: "#e67e2222", color: "#e67e22" }}>
                {m.name}: {m.current_stock}/{m.min_stock} {m.unit_display}
              </span>
            ))}
          </div>
        </div>
      )}

      <div className="flex justify-end">
        <button className="btn inline-flex items-center gap-1" onClick={() => setShowForm((v) => !v)}>
          <Plus size={14} /> Yangi xarid buyurtmasi
        </button>
      </div>

      {showForm && (
        <PurchaseOrderForm
          suppliers={suppliers}
          materials={materials}
          warehouses={warehouses}
          onClose={() => setShowForm(false)}
          onDone={() => { setShowForm(false); load(); }}
        />
      )}

      {error && <div className="error">{error}</div>}

      {orders.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali xarid buyurtmasi yo'q.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {orders.map((o) => (
            <div key={o.id} className="card flex flex-col gap-2 p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="inline-flex items-center gap-2 font-semibold">
                  <Truck size={16} /> {o.supplier_name}
                  <span
                    className="rounded-full px-2 py-0.5 text-[10px] font-medium"
                    style={
                      o.status === "received"
                        ? { background: "#27ae6022", color: "#27ae60" }
                        : o.status === "cancelled"
                        ? { background: "#e74c3c22", color: "#e74c3c" }
                        : { background: "#3498db22", color: "#3498db" }
                    }
                  >
                    {o.status_display}
                  </span>
                </div>
                <span className="text-sm font-bold" style={{ color: "var(--secondary)" }}>
                  {Number(o.total_cost).toLocaleString()} so'm
                </span>
              </div>
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                {o.warehouse_name} · {o.items.map((i) => `${i.material_name} ${i.quantity}${i.material_unit}`).join(", ")}
              </div>
              {o.status === "pending" && (
                <button
                  className="btn self-start inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                  disabled={busyId === o.id}
                  onClick={() => receive(o)}
                >
                  <CheckCircle2 size={12} /> Qabul qilindi deb belgilash
                </button>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function PurchaseOrderForm({ suppliers, materials, warehouses, onClose, onDone }) {
  const [supplier, setSupplier] = useState("");
  const [warehouse, setWarehouse] = useState("");
  const [note, setNote] = useState("");
  const [items, setItems] = useState([{ material: "", quantity: "", unit_cost: "" }]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const setItem = (i, k, v) => {
    const next = [...items];
    next[i] = { ...next[i], [k]: v };
    setItems(next);
  };
  const addItem = () => setItems([...items, { material: "", quantity: "", unit_cost: "" }]);
  const removeItem = (i) => setItems(items.filter((_, idx) => idx !== i));

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (!supplier || !warehouse) {
      setError("Yetkazib beruvchi va omborni tanlang");
      return;
    }
    setBusy(true);
    try {
      await api("/purchase-orders/", {
        method: "POST",
        body: {
          supplier,
          warehouse,
          note,
          items: items.filter((i) => i.material && i.quantity),
        },
      });
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-lg flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 className="inline-flex items-center gap-2 text-base font-semibold">
          <Package size={17} /> Yangi xarid buyurtmasi
        </h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Yetkazib beruvchi *</label>
            <select className="input" value={supplier} onChange={(e) => setSupplier(e.target.value)} required>
              <option value="">Tanlang…</option>
              {suppliers.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
          <div>
            <label className="label">Ombor *</label>
            <select className="input" value={warehouse} onChange={(e) => setWarehouse(e.target.value)} required>
              <option value="">Tanlang…</option>
              {warehouses.map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}
            </select>
          </div>
        </div>

        <div className="flex flex-col gap-2">
          <label className="label">Bandlar *</label>
          {items.map((item, i) => (
            <div key={i} className="flex flex-wrap items-end gap-2">
              <div style={{ minWidth: 160, flex: 2 }}>
                <select className="input" value={item.material} onChange={(e) => setItem(i, "material", e.target.value)}>
                  <option value="">Material…</option>
                  {materials.map((m) => <option key={m.id} value={m.id}>{m.name} ({m.unit_display})</option>)}
                </select>
              </div>
              <input
                className="input" type="number" min="0.001" step="0.001" placeholder="Miqdor"
                style={{ width: 100 }} value={item.quantity} onChange={(e) => setItem(i, "quantity", e.target.value)}
              />
              <input
                className="input" type="number" min="0" step="1" placeholder="Narx (1 birlik)"
                style={{ width: 130 }} value={item.unit_cost} onChange={(e) => setItem(i, "unit_cost", e.target.value)}
              />
              {items.length > 1 && (
                <button type="button" className="btn-ghost !px-2 !py-2" style={{ color: "#e74c3c" }} onClick={() => removeItem(i)}>
                  <Trash2 size={14} />
                </button>
              )}
            </div>
          ))}
          <button type="button" className="btn-ghost self-start inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={addItem}>
            <Plus size={12} /> Yana band qo'shish
          </button>
        </div>

        <div>
          <label className="label">Izoh</label>
          <textarea className="input" rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
        </div>

        {error && <div className="error">{error}</div>}
        <div className="flex gap-2">
          <button className="btn" type="submit" disabled={busy}>{busy ? "Yaratilmoqda…" : "Yaratish"}</button>
          <button className="btn-ghost" type="button" onClick={onClose}>Bekor</button>
        </div>
      </form>
    </div>
  );
}
