import { useEffect, useState } from "react";
import { api } from "../../api";
import { StatusBadge } from "../../orderStatus";

export default function AdminOrders() {
  const [orders, setOrders] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    api("/orders/")
      .then((d) => setOrders(d.results || []))
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div className="flex flex-col gap-4">
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
            </tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.id}>
                <td>{new Date(o.created_at).toLocaleDateString("uz-UZ")}</td>
                <td className="font-medium">{o.company_name}</td>
                <td>{o.customer_email}</td>
                <td>{o.items.map((i) => `${i.product_name} ×${i.quantity}`).join(", ")}</td>
                <td className="font-medium">{Number(o.total_price).toLocaleString()} so'm</td>
                <td><StatusBadge status={o.status} /></td>
              </tr>
            ))}
            {orders.length === 0 && (
              <tr>
                <td colSpan={6} style={{ color: "var(--muted)" }}>Buyurtmalar yo'q.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
