import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Phone, MapPin, MessageSquare, X, Workflow } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { NEXT_STATUS, ORDER_STATUS, StatusBadge } from "../../orderStatus";
import LoadMoreButton from "../../components/LoadMoreButton";

export default function FirmaOrders() {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [filter, setFilter] = useState("");
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    Promise.all([api("/orders/"), api("/employees/")])
      .then(([d, emp]) => {
        setOrders(d.results || []);
        setNextPage(d.next || null);
        setEmployees((emp.results || []).filter((e) => e.pay_type === "commission"));
      })
      .catch((e) => setError(e.message));

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
      <div className="flex flex-wrap gap-2">
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
      </div>
      {error && <div className="error">{error}</div>}
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
            <StatusBadge status={o.status} />
          </div>
          <div className="text-sm">
            {o.items.map((it) => (
              <div key={it.id} className="flex justify-between py-0.5">
                <span>
                  {it.product_name} ({it.variant_name}) · {it.width}×{it.height}×{it.depth} m ×{it.quantity}
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
