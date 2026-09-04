import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { Workflow } from "lucide-react";
import { api } from "../api";
import { useLocale } from "../locale";
import { FLOW, ORDER_STATUS, StatusBadge } from "../orderStatus";
import WorkflowPanel from "../components/WorkflowPanel";

export default function MyOrders() {
  const { t } = useLocale();
  const [orders, setOrders] = useState([]);
  const [error, setError] = useState("");
  const [openWorkflow, setOpenWorkflow] = useState(null);
  // Push bosilganda (`/orders?highlight=<id>`) o'sha buyurtmaga o'tib,
  // vizual ajratib ko'rsatish uchun — qarang src/push.js va
  // public/firebase-messaging-sw.js.
  const [searchParams] = useSearchParams();
  const highlightId = searchParams.get("highlight");

  const load = () =>
    api("/orders/")
      .then((d) => setOrders(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  useEffect(() => {
    if (!highlightId || orders.length === 0) return;
    const el = document.getElementById(`order-${highlightId}`);
    el?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [highlightId, orders]);

  const cancel = async (o) => {
    if (!confirm(t("orders_cancel_confirm"))) return;
    try {
      await api(`/orders/${o.id}/set_status/`, { method: "POST", body: { status: "cancelled" } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">{t("orders_title")}</h1>
      {error && <div className="error mb-4">{error}</div>}
      {orders.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>{t("orders_empty")}</p>
      )}
      <div className="flex flex-col gap-4">
        {orders.map((o) => (
          <div
            key={o.id}
            id={`order-${o.id}`}
            className="card flex flex-col gap-4 p-5"
            style={
              String(o.id) === highlightId
                ? { outline: "2px solid var(--brand-cta-bg)", outlineOffset: "2px" }
                : undefined
            }
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <span className="font-semibold">{o.company_name}</span>
                <span className="ml-2 text-xs" style={{ color: "var(--muted)" }}>
                  {new Date(o.created_at).toLocaleDateString("uz-UZ")}
                </span>
              </div>
              <StatusBadge status={o.status} />
            </div>

            {/* Status timeline */}
            {o.status !== "cancelled" && (
              <div className="flex items-center gap-1">
                {FLOW.map((s, i) => {
                  const reached = FLOW.indexOf(o.status) >= i;
                  const StepIcon = ORDER_STATUS[s].icon;
                  return (
                    <div key={s} className="flex flex-1 items-center gap-1" title={ORDER_STATUS[s].label}>
                      <div
                        className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs"
                        style={{
                          background: reached ? "var(--brand-cta-bg)" : "var(--border)",
                          color: reached ? "var(--brand-cta-text)" : "var(--muted)",
                        }}
                      >
                        <StepIcon size={14} />
                      </div>
                      {i < FLOW.length - 1 && (
                        <div
                          className="h-0.5 flex-1 rounded"
                          style={{
                            background:
                              FLOW.indexOf(o.status) > i ? "var(--brand-cta-bg)" : "var(--border)",
                          }}
                        />
                      )}
                    </div>
                  );
                })}
              </div>
            )}

            <div className="text-sm">
              {o.items.map((it) => (
                <div key={it.id} className="flex justify-between py-1">
                  <span>
                    {it.product_name} {it.variant_name && `(${it.variant_name})`} · {it.width}×{it.height}×{it.depth} m ×{it.quantity}
                  </span>
                  {it.is_custom_size && it.cost_amount == null ? (
                    <span className="text-xs" style={{ color: "var(--muted)" }}>{t("orders_price_unset")}</span>
                  ) : (
                    <span className="font-medium">{Number(it.subtotal).toLocaleString()} so'm</span>
                  )}
                </div>
              ))}
            </div>
            <div className="flex items-center justify-between border-t pt-3" style={{ borderColor: "var(--border)" }}>
              <span className="text-sm" style={{ color: "var(--muted)" }}>{t("orders_total")}</span>
              <span className="text-lg font-bold">{Number(o.total_price).toLocaleString()} so'm</span>
            </div>
            <div className="flex flex-wrap gap-2">
              {o.workflow_steps?.length > 0 && (
                <button
                  className={openWorkflow === o.id ? "btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                  onClick={() => setOpenWorkflow(openWorkflow === o.id ? null : o.id)}
                >
                  <Workflow size={13} /> {t("orders_workflow_progress")} ({o.progress_percent ?? 0}%)
                </button>
              )}
              {o.status === "new" && (
                <button className="btn-danger self-start !px-3 !py-1.5 text-xs" onClick={() => cancel(o)}>
                  {t("orders_cancel")}
                </button>
              )}
            </div>
            {openWorkflow === o.id && <WorkflowPanel order={o} />}
          </div>
        ))}
      </div>
    </div>
  );
}
