import { useEffect, useState } from "react";
import { Trash2 } from "lucide-react";
import { api } from "../../api";

const EMPTY = { name: "", description: "", price_per_employee: "1.00", price_per_product: "1.00", currency: "USD", is_active: true };

export default function AdminTariffPlans() {
  const [plans, setPlans] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);

  const load = () =>
    api("/tariff-plans/")
      .then((d) => setPlans(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const create = async (e) => {
    e.preventDefault();
    setError("");
    setSaving(true);
    try {
      await api("/tariff-plans/", { method: "POST", body: form });
      setForm(EMPTY);
      setShowForm(false);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (plan) => {
    try {
      await api(`/tariff-plans/${plan.id}/`, { method: "PATCH", body: { is_active: !plan.is_active } });
      await load();
    } catch (err) {
      setError(err.message);
    }
  };

  const remove = async (plan) => {
    if (!confirm(`"${plan.name}" tarif rejasi o'chirilsinmi?`)) return;
    try {
      await api(`/tariff-plans/${plan.id}/`, { method: "DELETE" });
      await load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="card p-5">
        <div className="mb-1 flex items-center justify-between">
          <h2 className="text-base font-semibold">Tarif rejalari</h2>
          <button className="btn" onClick={() => setShowForm((v) => !v)}>
            {showForm ? "Bekor qilish" : "+ Yangi reja"}
          </button>
        </div>
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          Har bir firma egasi ushbu rejalardan birini o'zi tanlaydi (Sozlamalar → Tarif). Oylik summa:
          faol xodimlar soni × "xodim narxi" + 3D modeli bor mahsulotlar soni × "mahsulot narxi" (variantlar
          hisobga olinmaydi — bitta mahsulotning bir nechta varianti bo'lsa ham bitta bulutli saqlash o'rni).
        </p>
      </div>
      {error && <div className="error">{error}</div>}
      {showForm && (
        <form onSubmit={create} className="card flex flex-col gap-3 p-5">
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="col-span-2">
              <label className="label">Reja nomi</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Xodim narxi (oyiga)</label>
              <input className="input" type="number" step="0.01" min="0" value={form.price_per_employee}
                onChange={(e) => setForm({ ...form, price_per_employee: e.target.value })} required />
            </div>
            <div>
              <label className="label">3D mahsulot narxi (oyiga)</label>
              <input className="input" type="number" step="0.01" min="0" value={form.price_per_product}
                onChange={(e) => setForm({ ...form, price_per_product: e.target.value })} required />
            </div>
            <div>
              <label className="label">Valyuta</label>
              <input className="input" value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} />
            </div>
            <div className="col-span-2 sm:col-span-4">
              <label className="label">Tavsif (ixtiyoriy)</label>
              <input className="input" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
            </div>
          </div>
          <button className="btn" type="submit" disabled={saving}>{saving ? "Saqlanmoqda…" : "Yaratish"}</button>
        </form>
      )}
      <div className="flex flex-col gap-3">
        {plans.length === 0 && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali tarif rejasi yo'q.</p>
        )}
        {plans.map((p) => (
          <div key={p.id} className="card flex flex-wrap items-center justify-between gap-3 p-4">
            <div>
              <div className="font-semibold">
                {p.name}
                {!p.is_active && (
                  <span className="ml-2 rounded-full px-2 py-0.5 text-[10px]" style={{ background: "var(--border)", color: "var(--muted)" }}>
                    O'chirilgan
                  </span>
                )}
              </div>
              {p.description && <div className="text-xs" style={{ color: "var(--muted)" }}>{p.description}</div>}
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                {p.price_per_employee} {p.currency}/xodim · {p.price_per_product} {p.currency}/3D mahsulot
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                style={{ border: "1px solid var(--border)", borderRadius: 8, padding: "6px 12px", background: "transparent", color: "var(--text)", cursor: "pointer", fontSize: 13 }}
                onClick={() => toggleActive(p)}
              >
                {p.is_active ? "Yashirish" : "Faollashtirish"}
              </button>
              <button onClick={() => remove(p)} style={{ background: "transparent", border: "none", color: "#e74c3c", cursor: "pointer", display: "flex" }}>
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
