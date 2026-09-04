import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Phone, MapPin, MessageSquare, X } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { NEXT_STATUS, ORDER_STATUS, StatusBadge } from "../../orderStatus";
import WorkflowPanel from "../../components/WorkflowPanel";
import DesignPanel from "../../components/DesignPanel";

/// Buyurtma tafsilotlari — ishlab chiqarish bosqichlari (WorkflowPanel)
/// avval FirmaOrders ro'yxatida joyida ("Ishlab chiqarish" tugmasi bilan)
/// ochilardi, endi ro'yxat toza qolishi uchun shu alohida sahifada.
export default function FirmaOrderDetail() {
  const { user } = useAuth();
  const { id } = useParams();
  const [order, setOrder] = useState(null);
  const [employees, setEmployees] = useState([]);
  const [error, setError] = useState("");

  const load = () =>
    Promise.all([api(`/orders/${id}/`), api("/employees/")])
      .then(([o, emp]) => {
        setOrder(o);
        setEmployees((emp.results || []).filter((e) => e.pay_type === "commission"));
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const setSoldBy = async (employeeId) => {
    try {
      await api(`/orders/${id}/set_sold_by/`, { method: "POST", body: { employee: employeeId || null } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const setStatus = async (status) => {
    const label = ORDER_STATUS[status]?.label || status;
    if (status === "cancelled" && !confirm(`Buyurtma bekor qilinsinmi?`)) return;
    try {
      await api(`/orders/${id}/set_status/`, { method: "POST", body: { status } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const [costDraft, setCostDraft] = useState({});
  const saveCost = async (itemId) => {
    try {
      await api(`/order-item-cost/${itemId}/set-cost/`, {
        method: "POST",
        body: { cost_amount: costDraft[itemId] },
      });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  if (error) return <div className="error">{error}</div>;
  if (!order) return <p className="text-sm" style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="flex flex-col gap-4">
      <Link to="/orders" className="inline-flex w-fit items-center gap-1 text-sm" style={{ color: "var(--muted)" }}>
        <ArrowLeft size={15} /> Buyurtmalarga qaytish
      </Link>

      <div className="card flex flex-col gap-3 p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <span className="font-semibold">{order.customer_name || order.customer_email}</span>
            <span className="ml-2 inline-flex flex-wrap items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
              <Phone size={12} /> {order.phone} · <MapPin size={12} /> {order.address} ·{" "}
              {new Date(order.created_at).toLocaleString("uz-UZ")}
            </span>
          </div>
          <div className="flex items-center gap-2">
            {order.order_type === "custom_project" && (
              <span className="badge badge-brand">{order.order_type_display}</span>
            )}
            <StatusBadge status={order.status} />
          </div>
        </div>
        <div className="text-sm">
          {order.items.map((it) => (
            <div key={it.id} className="flex items-center justify-between gap-2 py-0.5">
              <span>
                {it.product_name} {it.variant_name && `(${it.variant_name})`} · {it.width}×{it.height}×{it.depth} m ×{it.quantity}
                {it.is_custom_size && (
                  <span className="badge badge-off ml-1.5 !text-[10px]">Maxsus o'lcham</span>
                )}
              </span>
              {it.is_custom_size && it.cost_amount == null ? (
                user?.role === "company_owner" ? (
                  <div className="flex items-center gap-1.5">
                    <input
                      className="input !w-28 !py-1 text-xs" type="number" min="0" placeholder="Tannarx"
                      value={costDraft[it.id] ?? ""}
                      onChange={(e) => setCostDraft((d) => ({ ...d, [it.id]: e.target.value }))}
                    />
                    <button className="btn-ghost !px-2 !py-1 text-xs" onClick={() => saveCost(it.id)}>Saqlash</button>
                  </div>
                ) : (
                  <span className="text-xs" style={{ color: "var(--muted)" }}>Narx belgilanmagan</span>
                )
              ) : (
                <span className="font-medium">{Number(it.subtotal).toLocaleString()} so'm</span>
              )}
            </div>
          ))}
        </div>
        {user?.role === "company_owner" && employees.length > 0 && (
          <div className="flex items-center gap-2 text-xs" style={{ color: "var(--muted)" }}>
            <span>Sotuvchi (komissiya uchun):</span>
            <select
              className="input !w-auto !py-1 text-xs"
              value={order.sold_by || ""}
              onChange={(e) => setSoldBy(e.target.value)}
            >
              <option value="">— tanlanmagan —</option>
              {employees.map((emp) => (
                <option key={emp.id} value={emp.id}>{emp.user_name || emp.user_email}</option>
              ))}
            </select>
          </div>
        )}
        {order.note && (
          <div className="flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs" style={{ background: "color-mix(in srgb, var(--primary) 18%, transparent)" }}>
            <MessageSquare size={13} /> {order.note}
          </div>
        )}
        <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
          <span className="text-lg font-bold">{Number(order.total_price).toLocaleString()} so'm</span>
          <div className="flex flex-wrap gap-2">
            {/* Buyurtma holatini o'zgartirish (qabul/bekor) — menejerlik
                qarori, faqat firma egasi uchun (backend ham shunday
                cheklaydi, qarang OrderViewSet.set_status). */}
            {user?.role === "company_owner" && (NEXT_STATUS[order.status] || [])
              .filter((s) => s !== "designing" || order.order_type === "custom_project")
              .map((s) => {
              const Icon = ORDER_STATUS[s].icon;
              return s === "cancelled" ? (
                <button key={s} className="btn-danger inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(s)}>
                  <X size={13} /> Bekor qilish
                </button>
              ) : (
                <button key={s} className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(s)}>
                  <Icon size={13} /> {ORDER_STATUS[s].label}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {order.order_type === "custom_project" && <DesignPanel orderId={order.id} />}

      {order.workflow_steps?.length > 0 && (
        <WorkflowPanel order={order} editable onChanged={load} />
      )}
    </div>
  );
}
