import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Users, Factory, Sofa, Package, ArrowRight } from "lucide-react";
import { api } from "../../api";
import StatCard from "../../components/StatCard";

export default function AdminDashboard() {
  const [stats, setStats] = useState(null);
  const [companies, setCompanies] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    Promise.all([api("/admin/stats/"), api("/companies/")])
      .then(([s, cs]) => {
        setStats(s);
        setCompanies((cs.results || []).slice(0, 5));
      })
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="error">{error}</div>;
  if (!stats) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4">
        <StatCard compact tone={0} icon={Users} label="Foydalanuvchilar" value={stats.users} hint={`${stats.customers} mijoz`} />
        <StatCard compact tone={1} icon={Factory} label="Kompaniyalar" value={stats.companies} hint={`${stats.active_companies} faol`} />
        <StatCard compact tone={2} icon={Sofa} label="Mahsulotlar" value={stats.products} hint={`${stats.published_products} sotuvda`} />
        <StatCard compact tone={3} icon={Package} label="Buyurtmalar" value={stats.orders} hint={`${stats.new_orders} kutilmoqda`} />
      </div>

      <div className="card p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-semibold">So'nggi kompaniyalar</h2>
          <Link to="/companies" className="inline-flex items-center gap-0.5 text-sm" style={{ color: "var(--secondary)" }}>
            Hammasi <ArrowRight size={14} />
          </Link>
        </div>
        {companies.length === 0 ? (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali kompaniyalar yo'q.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {companies.map((c) => (
              <div
                key={c.id}
                className="flex items-center justify-between rounded-xl px-3 py-2"
                style={{ border: "1px solid var(--border)" }}
              >
                <div className="flex items-center gap-3">
                  <div
                    className="flex h-9 w-9 items-center justify-center rounded-lg text-sm font-bold"
                    style={{ background: "color-mix(in srgb, var(--primary) 35%, transparent)", color: "var(--primary-deep)" }}
                  >
                    {c.name[0]}
                  </div>
                  <div>
                    <div className="text-sm font-medium">{c.name}</div>
                    <div className="text-xs" style={{ color: "var(--muted)" }}>{c.phone || "—"}</div>
                  </div>
                </div>
                <span className={c.is_active ? "badge" : "badge badge-off"}>
                  {c.is_active ? "Faol" : "Bloklangan"}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
