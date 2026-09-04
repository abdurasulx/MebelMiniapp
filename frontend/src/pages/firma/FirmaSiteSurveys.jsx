import { useEffect, useState } from "react";
import { MapPinned, Plus, Camera, Video, Package } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { Link } from "react-router-dom";

const STATUS_BADGE = {
  assigned: "badge-off",
  visited: "badge",
  order_created: "badge",
  cancelled: "badge-off",
};

/// Firma egasi ustani mijoz uyiga joy o'rganishga tayinlaydi; usta o'z
/// tayinlangan joylarini shu yerda ko'rib, tashrif ma'lumotlarini (rasm/
/// video/izoh) kiritadi va CUSTOM_PROJECT buyurtmasini yaratadi (docs
/// "Buyurtma va ishlab chiqarish tizimi" §3-4).
export default function FirmaSiteSurveys() {
  const { user } = useAuth();
  const [surveys, setSurveys] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [error, setError] = useState("");
  const [selected, setSelected] = useState(null);
  const [form, setForm] = useState({ customer_worker_id: "", assigned_master: "", address: "", notes: "" });

  const load = () =>
    Promise.all([api("/site-surveys/"), api("/employees/")])
      .then(([s, emp]) => {
        setSurveys(s.results || []);
        setEmployees((emp.results || []).filter((e) => (e.positions || []).includes("usta")));
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const assign = async (e) => {
    e.preventDefault();
    setError("");
    try {
      await api("/site-surveys/", { method: "POST", body: form });
      setForm({ customer_worker_id: "", assigned_master: "", address: "", notes: "" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <MapPinned size={18} />
        <h1 className="text-lg font-bold">Joy o'rganish</h1>
      </div>

      {error && <div className="error">{error}</div>}

      {user?.role === "company_owner" && (
        <form onSubmit={assign} className="card flex flex-wrap items-end gap-3 p-5">
          <div>
            <label className="label">Mijoz qidiruvchi ID (ixtiyoriy)</label>
            <input className="input !w-40" placeholder="Hali noma'lum bo'lsa bo'sh qoldiring"
              value={form.customer_worker_id}
              onChange={(e) => setForm({ ...form, customer_worker_id: e.target.value })} />
          </div>
          <div>
            <label className="label">Usta</label>
            <select className="input" value={form.assigned_master}
              onChange={(e) => setForm({ ...form, assigned_master: e.target.value })} required>
              <option value="">— tanlang —</option>
              {employees.map((emp) => (
                <option key={emp.id} value={emp.id}>{emp.user_name || emp.user_email}</option>
              ))}
            </select>
          </div>
          <div className="min-w-[220px] flex-1">
            <label className="label">Manzil</label>
            <input className="input" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
          </div>
          <div className="min-w-[220px] flex-1">
            <label className="label">Izoh (ixtiyoriy)</label>
            <input className="input" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} />
          </div>
          <button className="btn inline-flex items-center gap-1.5" type="submit">
            <Plus size={15} /> Tayinlash
          </button>
        </form>
      )}

      {surveys.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali joy o'rganish tayinlanmagan.</p>
      ) : (
        <div className="card flex flex-col divide-y" style={{ borderColor: "var(--border)" }}>
          {surveys.map((s) => (
            <div key={s.id} className="flex flex-col gap-2 p-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <span className="font-semibold">{s.customer_name || s.customer_worker_id_display || "Mijoz hali belgilanmagan"}</span>
                  <span className="ml-2 text-xs" style={{ color: "var(--muted)" }}>{s.address}</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className={STATUS_BADGE[s.status] || "badge-off"}>{s.status_display}</span>
                  {s.order && (
                    <Link to={`/orders/${s.order}`} className="btn-ghost inline-flex items-center gap-1 !px-2 !py-1 text-xs">
                      <Package size={12} /> Buyurtma
                    </Link>
                  )}
                </div>
              </div>
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                Usta: {s.assigned_master_name || "—"}
                {s.media?.length > 0 && ` · ${s.media.length} ta media`}
              </div>
              {s.notes && <p className="text-sm">{s.notes}</p>}
              {s.media?.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {s.media.map((m) => (
                    <a key={m.id} href={m.file_url} target="_blank" rel="noreferrer" className="btn-ghost inline-flex items-center gap-1 !px-2 !py-1 text-xs">
                      {m.media_type === "video" ? <Video size={12} /> : <Camera size={12} />} {m.caption || m.media_type}
                    </a>
                  ))}
                </div>
              )}
              <button className="w-fit text-xs underline" style={{ color: "var(--muted)" }} onClick={() => setSelected(selected === s.id ? null : s.id)}>
                {selected === s.id ? "Yopish" : "Batafsil"}
              </button>
              {selected === s.id && !s.order && (
                <CreateOrderForm survey={s} onCreated={load} />
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/// Usta (yoki ega) site-survey asosida CUSTOM_PROJECT buyurtmasini yaratadi.
function CreateOrderForm({ survey, onCreated }) {
  const [products, setProducts] = useState([]);
  const [items, setItems] = useState([{ product: "", is_custom_size: true, width: 1, height: 1, depth: 1, quantity: 1 }]);
  const [customerWorkerId, setCustomerWorkerId] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    api(`/products/?company=${survey.company_slug}`).then((d) => setProducts(d.results || [])).catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const updateItem = (i, patch) => setItems((prev) => prev.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  const addItem = () => setItems((prev) => [...prev, { product: "", is_custom_size: true, width: 1, height: 1, depth: 1, quantity: 1 }]);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(`/site-surveys/${survey.id}/create-order/`, {
        method: "POST",
        body: { items, customer_worker_id: customerWorkerId },
      });
      onCreated();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} className="flex flex-col gap-2 rounded-lg border p-3" style={{ borderColor: "var(--border)" }}>
      <div>
        <label className="label">
          Mijoz qidiruvchi ID {survey.customer_name || survey.customer_worker_id_display ? "(o'zgartirish uchun)" : ""}
        </label>
        <input
          className="input !w-40" placeholder={survey.customer_worker_id_display || "Masalan: 1234567890"}
          value={customerWorkerId} onChange={(e) => setCustomerWorkerId(e.target.value)}
          required={!survey.customer_name && !survey.customer_worker_id_display}
        />
        <p className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
          Mijoz shu ID orqali o'z ilovasida buyurtmani kuzatib borishi mumkin bo'ladi.
        </p>
      </div>
      {items.map((it, i) => (
        <div key={i} className="flex flex-wrap items-end gap-2">
          <select className="input !w-48" value={it.product} onChange={(e) => updateItem(i, { product: e.target.value })} required>
            <option value="">— mahsulot —</option>
            {products.map((p) => <option key={p.id} value={p.id}>{p.name_uz}</option>)}
          </select>
          {[["width", "Eni"], ["height", "Bo'yi"], ["depth", "Chuquri"]].map(([k, label]) => (
            <input key={k} className="input !w-20" type="number" step="0.1" min="0.1" placeholder={label}
              value={it[k]} onChange={(e) => updateItem(i, { [k]: e.target.value })} />
          ))}
          <input className="input !w-16" type="number" min="1" value={it.quantity} onChange={(e) => updateItem(i, { quantity: e.target.value })} />
          <label className="flex items-center gap-1 text-xs">
            <input type="checkbox" checked={it.is_custom_size} onChange={(e) => updateItem(i, { is_custom_size: e.target.checked })} />
            Narx keyinroq
          </label>
        </div>
      ))}
      <div className="flex items-center gap-2">
        <button type="button" className="btn-ghost !px-2 !py-1 text-xs" onClick={addItem}>+ Band qo'shish</button>
        <button type="submit" className="btn !px-3 !py-1.5 text-xs" disabled={busy}>{busy ? "Yaratilmoqda…" : "Buyurtma yaratish"}</button>
      </div>
      {error && <div className="error">{error}</div>}
    </form>
  );
}
