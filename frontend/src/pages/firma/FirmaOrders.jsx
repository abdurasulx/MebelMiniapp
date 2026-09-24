import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Phone, MapPin, MessageSquare, X, Workflow, Upload } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { NEXT_STATUS, ORDER_STATUS, StatusBadge } from "../../orderStatus";
import LoadMoreButton from "../../components/LoadMoreButton";

export default function FirmaOrders() {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [products, setProducts] = useState([]);
  const [filter, setFilter] = useState("");
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [showNew, setShowNew] = useState(false);

  const load = () => {
    const companySlug = user?.company?.slug;
    return Promise.all([
      api("/orders/"),
      api("/employees/"),
      companySlug ? api(`/products/?company=${companySlug}`) : Promise.resolve({ results: [] }),
    ])
      .then(([d, emp, prod]) => {
        setOrders(d.results || []);
        setNextPage(d.next || null);
        setEmployees((emp.results || []).filter((e) => e.pay_type === "commission"));
        setProducts(prod.results || []);
      })
      .catch((e) => setError(e.message));
  };

  const setSoldBy = async (o, employeeId) => {
    try {
      await api(`/orders/${o.id}/set_sold_by/`, { method: "POST", body: { employee: employeeId || null } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setOrders((prev) => [...prev, ...(d.results || [])]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const setStatus = async (o, status) => {
    const label = ORDER_STATUS[status]?.label || status;
    if (status === "cancelled" && !confirm(`Buyurtma bekor qilinsinmi?`)) return;
    try {
      await api(`/orders/${o.id}/set_status/`, { method: "POST", body: { status } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const shown = filter ? orders.filter((o) => o.status === filter) : orders;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <button
          className="rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            filter === ""
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setFilter("")}
        >
          Barchasi ({orders.length})
        </button>
        {Object.entries(ORDER_STATUS).map(([k, s]) => {
          const n = orders.filter((o) => o.status === k).length;
          if (n === 0) return null;
          const Icon = s.icon;
          return (
            <button
              key={k}
              className="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={
                filter === k
                  ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                  : { border: "1px solid var(--border)", color: "var(--muted)" }
              }
              onClick={() => setFilter(k)}
            >
              <Icon size={13} /> {s.label} ({n})
            </button>
          );
        })}
        <button className="btn !px-3 !py-1.5 text-xs ml-auto" onClick={() => setShowNew(true)}>
          + Yangi buyurtma
        </button>
      </div>
      {error && <div className="error">{error}</div>}
      {showNew && (
        <NewCustomOrderModal
          products={products}
          onClose={() => setShowNew(false)}
          onDone={() => { setShowNew(false); load(); }}
        />
      )}
      {shown.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Buyurtmalar yo'q.</p>
      )}

      {shown.map((o) => (
        <div key={o.id} className="card flex flex-col gap-3 p-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="font-semibold">{o.customer_name || o.customer_email}</span>
              <span className="ml-2 inline-flex flex-wrap items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
                <Phone size={12} /> {o.phone} · <MapPin size={12} /> {o.address} · {new Date(o.created_at).toLocaleString("uz-UZ")}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {o.order_type === "custom_project" && <span className="badge badge-brand">{o.order_type_display}</span>}
              <StatusBadge status={o.status} />
            </div>
          </div>
          <div className="text-sm">
            {o.items.map((it) => (
              <div key={it.id} className="flex justify-between py-0.5">
                <span>
                  {it.product_name} {it.variant_name && `(${it.variant_name})`} · {it.width}×{it.height}×{it.depth} m ×{it.quantity}
                </span>
                <span className="font-medium">{Number(it.subtotal).toLocaleString()} so'm</span>
              </div>
            ))}
          </div>
          {user?.role === "company_owner" && employees.length > 0 && (
            <div className="flex items-center gap-2 text-xs" style={{ color: "var(--muted)" }}>
              <span>Sotuvchi (komissiya uchun):</span>
              <select
                className="input !w-auto !py-1 text-xs"
                value={o.sold_by || ""}
                onChange={(e) => setSoldBy(o, e.target.value)}
              >
                <option value="">— tanlanmagan —</option>
                {employees.map((emp) => (
                  <option key={emp.id} value={emp.id}>{emp.user_name || emp.user_email}</option>
                ))}
              </select>
            </div>
          )}
          {o.note && (
            <div className="flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs" style={{ background: "color-mix(in srgb, var(--primary) 18%, transparent)" }}>
              <MessageSquare size={13} /> {o.note}
            </div>
          )}
          <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
            <span className="text-lg font-bold">{Number(o.total_price).toLocaleString()} so'm</span>
            <div className="flex flex-wrap gap-2">
              {o.workflow_steps?.length > 0 && (
                <Link
                  to={`/orders/${o.id}`}
                  className="btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                >
                  <Workflow size={13} /> Ishlab chiqarish ({o.progress_percent ?? 0}%)
                </Link>
              )}
              {/* Buyurtma holatini o'zgartirish (qabul/bekor) — menejerlik
                  qarori, faqat firma egasi uchun (backend ham shunday
                  cheklaydi, qarang OrderViewSet.set_status). */}
              {user?.role === "company_owner" && (NEXT_STATUS[o.status] || []).map((s) => {
                const Icon = ORDER_STATUS[s].icon;
                return s === "cancelled" ? (
                  <button key={s} className="btn-danger inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(o, s)}>
                    <X size={13} /> Bekor qilish
                  </button>
                ) : (
                  <button key={s} className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(o, s)}>
                    <Icon size={13} /> {ORDER_STATUS[s].label}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      ))}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

function emptyItem() {
  return { product: "", variant: "", width: "1", height: "1", depth: "1", quantity: "1", is_custom_size: true };
}

function NewCustomOrderModal({ products, onClose, onDone }) {
  const [customerWorkerId, setCustomerWorkerId] = useState("");
  const [address, setAddress] = useState("");
  const [items, setItems] = useState([emptyItem()]);
  const [bazisFile, setBazisFile] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const setItem = (i, patch) => setItems((prev) => prev.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  const addItem = () => setItems((prev) => [...prev, emptyItem()]);
  const removeItem = (i) => setItems((prev) => prev.filter((_, idx) => idx !== i));

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const body = {
        customer_worker_id: customerWorkerId,
        address,
        items: items
          .filter((it) => it.product)
          .map((it) => ({
            product: it.product,
            variant: it.variant || null,
            width: it.width,
            height: it.height,
            depth: it.depth,
            quantity: Number(it.quantity) || 1,
            is_custom_size: it.is_custom_size,
          })),
      };
      const order = await api("/custom-orders/create/", { method: "POST", body });

      if (bazisFile) {
        const fd = new FormData();
        fd.append("file", bazisFile);
        try {
          await api(`/custom-orders/${order.id}/import-bazis/`, { method: "POST", body: fd, isForm: true });
        } catch (err) {
          setError(`Buyurtma yaratildi, lekin Bazis fayli yuklanmadi: ${err.message}`);
          onDone();
          return;
        }
      }
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
        style={{ maxHeight: "90vh", overflowY: "auto" }}
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h3 className="text-lg font-semibold">Yangi buyurtma (individual loyiha)</h3>

        <label className="flex flex-col gap-1 text-sm">
          Mijoz qidiruvchi ID
          <input
            className="input" required value={customerWorkerId}
            onChange={(e) => setCustomerWorkerId(e.target.value)}
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Manzil (ixtiyoriy)
          <input className="input" value={address} onChange={(e) => setAddress(e.target.value)} />
        </label>

        <div className="flex flex-col gap-3">
          {items.map((it, i) => {
            const product = products.find((p) => p.id === it.product);
            return (
              <div key={i} className="flex flex-col gap-2 rounded-lg border p-3" style={{ borderColor: "var(--border)" }}>
                <div className="flex items-center gap-2">
                  <select
                    className="input flex-1" required value={it.product}
                    onChange={(e) => setItem(i, { product: e.target.value, variant: "" })}
                  >
                    <option value="">Mahsulot tanlang…</option>
                    {products.map((p) => (
                      <option key={p.id} value={p.id}>{p.name_uz}</option>
                    ))}
                  </select>
                  {items.length > 1 && (
                    <button type="button" className="icon-btn" onClick={() => removeItem(i)}>
                      <X size={14} />
                    </button>
                  )}
                </div>
                {product?.variants?.length > 0 && (
                  <select
                    className="input" value={it.variant}
                    onChange={(e) => setItem(i, { variant: e.target.value })}
                  >
                    <option value="">Variant — standart</option>
                    {product.variants.map((v) => (
                      <option key={v.id} value={v.id}>{v.name}</option>
                    ))}
                  </select>
                )}
                <div className="grid grid-cols-4 gap-2">
                  <input className="input" type="number" step="0.01" min="0.1" placeholder="Eni (m)" value={it.width} onChange={(e) => setItem(i, { width: e.target.value })} />
                  <input className="input" type="number" step="0.01" min="0.1" placeholder="Bo'yi (m)" value={it.height} onChange={(e) => setItem(i, { height: e.target.value })} />
                  <input className="input" type="number" step="0.01" min="0.1" placeholder="Chuquri (m)" value={it.depth} onChange={(e) => setItem(i, { depth: e.target.value })} />
                  <input className="input" type="number" min="1" placeholder="Soni" value={it.quantity} onChange={(e) => setItem(i, { quantity: e.target.value })} />
                </div>
              </div>
            );
          })}
          <button type="button" className="btn-ghost self-start !px-3 !py-1.5 text-xs" onClick={addItem}>
            + Band qo'shish
          </button>
        </div>

        <label className="flex flex-col gap-1 text-sm">
          Bazis fayl (ixtiyoriy)
          <div className="flex items-center gap-2">
            <label className="btn-ghost inline-flex cursor-pointer items-center gap-1.5 !px-3 !py-1.5 text-xs">
              <Upload size={13} /> {bazisFile ? bazisFile.name : "Fayl tanlash (.project)"}
              <input
                type="file" accept=".project" style={{ display: "none" }}
                onChange={(e) => setBazisFile(e.target.files?.[0] || null)}
              />
            </label>
            {bazisFile && (
              <button type="button" className="icon-btn" onClick={() => setBazisFile(null)}>
                <X size={14} />
              </button>
            )}
          </div>
          <span style={{ fontSize: 11, color: "var(--muted)" }}>
            CAD dasturidan eksport qilingan .project fayli — detal/teshik ma'lumotidan ishlab chiqarish
            topshiriqlari avtomatik tuziladi (dizayn tasdiqlanib "Ishlab chiqarishga" o'tganda).
          </span>
        </label>

        {error && <div className="error">{error}</div>}

        <div className="flex justify-end gap-2">
          <button type="button" className="btn-ghost" onClick={onClose}>Bekor qilish</button>
          <button type="submit" className="btn" disabled={busy}>{busy ? "Yaratilmoqda…" : "Yaratish"}</button>
        </div>
      </form>
    </div>
  );
}
