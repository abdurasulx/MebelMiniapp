import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Sofa, Palette, HardHat, Package, Target, Factory, ArrowRight } from "lucide-react";
import { api } from "../../api";
import StatCard from "../../components/StatCard";

export default function FirmaDashboard() {
  const [me, setMe] = useState(null);
  const [products, setProducts] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [orders, setOrders] = useState([]);
  const [leads, setLeads] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    Promise.all([api("/users/me/"), api("/products/"), api("/employees/"), api("/orders/"), api("/leads/")])
      .then(([m, ps, es, os, ls]) => {
        setMe(m);
        const mine = (ps.results || []).filter((p) => m.company && p.company === m.company.id);
        setProducts(mine);
        setEmployees(es.results || []);
        setOrders(os.results || []);
        setLeads(ls.results || []);
      })
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="error">{error}</div>;
  if (!me) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  if (!me.company)
    return (
      <div className="card mx-auto max-w-md p-6 text-center">
        <Factory className="mx-auto mb-2" size={32} style={{ color: "var(--muted)" }} />
        <h2 className="mb-1 text-lg font-semibold">Kompaniyangiz hali yo'q</h2>
        <p className="mb-4 text-sm" style={{ color: "var(--muted)" }}>
          Mahsulot joylash uchun avval kompaniya yarating.
        </p>
        <Link to="/settings" className="btn">Kompaniya yaratish</Link>
      </div>
    );

  const published = products.filter((p) => p.is_published).length;
  const variants = products.reduce((n, p) => n + p.variants.length, 0);

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard tone={0} icon={Sofa} label="Mahsulotlar" value={products.length} hint={`${published} sotuvda`} />
        <StatCard tone={1} icon={Palette} label="Variantlar" value={variants} />
        <StatCard tone={2} icon={HardHat} label="Xodimlar" value={employees.filter((e) => e.is_active).length} />
        <StatCard
          tone={3}
          icon={Package}
          label="Buyurtmalar"
          value={orders.length}
          hint={`${orders.filter((o) => o.status === "new").length} kutilmoqda`}
        />
        <StatCard
          tone={0}
          icon={Target}
          label="Leadlar"
          value={leads.length}
          hint={`${leads.filter((l) => l.status === "new").length} yangi`}
        />
      </div>

      <div className="card p-5">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-base font-semibold">So'nggi mahsulotlar</h2>
          <Link to="/products" className="inline-flex items-center gap-0.5 text-sm" style={{ color: "var(--secondary)" }}>
            Hammasi <ArrowRight size={14} />
          </Link>
        </div>
        {products.length === 0 ? (
          <div className="py-6 text-center">
            <p className="mb-3 text-sm" style={{ color: "var(--muted)" }}>Hali mahsulot yo'q.</p>
            <Link to="/products" className="btn">+ Birinchi mahsulotni qo'shish</Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {products.slice(0, 6).map((p) => (
              <div key={p.id} className="flex items-center gap-3 rounded-xl p-3" style={{ border: "1px solid var(--border)" }}>
                {p.image_url ? (
                  <img src={p.image_url} alt="" className="h-12 w-12 rounded-lg object-cover" />
                ) : (
                  <div
                    className="flex h-12 w-12 items-center justify-center rounded-lg"
                    style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)" }}
                  >
                    <Sofa size={18} />
                  </div>
                )}
                <div className="min-w-0">
                  <div className="truncate text-sm font-medium">{p.name_uz}</div>
                  <span className={p.is_published ? "badge" : "badge badge-off"}>
                    {p.is_published ? "Sotuvda" : "Yashirin"}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
