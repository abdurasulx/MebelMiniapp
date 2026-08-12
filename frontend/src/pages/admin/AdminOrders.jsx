import { useEffect, useState } from "react";
import { api } from "../../api";
import { NEXT_STATUS, ORDER_STATUS, StatusBadge } from "../../orderStatus";

export default function AdminOrders() {
  const [orders, setOrders] = useState([]);
  const [filter, setFilter] = useState("");
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState(null);

  const load = () =>
    api("/orders/")
      .then((d) => setOrders(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const setStatus = async (o, status) => {
    const label = ORDER_STATUS[status]?.label || status;
    if (status === "cancelled" && !confirm(`Buyurtma "${label}" holatiga o'tkazilsinmi?`)) return;
    setBusyId(o.id);
    setError("");
    try {
      await api(`/orders/${o.id}/set_status/`, { method: "POST", body: { status } });
      load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const shown = filter ? orders.filter((o) => o.status === filter) : orders;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-2">
        <button
          className={filter === "" ? "btn btn-brand !px-3 !py-1.5 text-xs" : "btn-ghost !px-3 !py-1.5 text-xs"}
          onClick={() => setFilter("")}
        >
          Barchasi ({orders.length})
        </button>
        {Object.entries(ORDER_STATUS).map(([k, s]) => {
          const n = orders.filter((o) => o.status === k).length;
          return (
            <button
              key={k}
              className="rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={
                filter === k
                  ? { background: s.color, color: "#fff" }
                  : { border: "1px solid var(--border)", color: "var(--muted)" }
              }
              onClick={() => setFilter(k)}
            >
              {s.label} ({n})
            </button>
          );
        })}
      </div>

      {error && <div className="error">{error}</div>}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Sana</th>
              <th>Kompaniya</th>
              <th>Mijoz</th>
              <th>Mahsulotlar</th>
              <th>Summa</th>
              <th>Holat</th>
              <th>Amal</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((o) => (
              <tr key={o.id}>
                <td>{new Date(o.created_at).toLocaleDateString("uz-UZ")}</td>
                <td className="font-medium">{o.company_name}</td>
                <td>{o.customer_email}</td>
                <td>{o.items.map((i) => `${i.product_name} ×${i.quantity}`).join(", ")}</td>
                <td className="font-medium">{Number(o.total_price).toLocaleString()} so'm</td>
                <td><StatusBadge status={o.status} /></td>
                <td>
                  <div className="flex flex-wrap gap-1.5">
                    {(NEXT_STATUS[o.status] || []).map((s) => {
                      const Icon = ORDER_STATUS[s].icon;
                      return s === "cancelled" ? (
                        <button
                          key={s}
                          disabled={busyId === o.id}
                          className="btn-danger inline-flex items-center gap-1 !px-2.5 !py-1 text-[11px]"
                          onClick={() => setStatus(o, s)}
                        >
                          <Icon size={11} /> {ORDER_STATUS[s].label}
                        </button>
                      ) : (
                        <button
                          key={s}
                          disabled={busyId === o.id}
                          className="btn inline-flex items-center gap-1 !px-2.5 !py-1 text-[11px]"
                          onClick={() => setStatus(o, s)}
                        >
                          <Icon size={11} /> {ORDER_STATUS[s].label}
                        </button>
                      );
                    })}
                  </div>
                </td>
              </tr>
            ))}
            {shown.length === 0 && (
              <tr>
                <td colSpan={7} style={{ color: "var(--muted)" }}>Buyurtmalar yo'q.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
