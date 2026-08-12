import { useEffect, useState } from "react";
import { Wallet, TrendingUp, HandCoins, PiggyBank } from "lucide-react";
import { api } from "../../api";
import StatCard from "../../components/StatCard";

function som(n) {
  return `${Math.round(Number(n) || 0).toLocaleString()} so'm`;
}

export default function AdminFinance() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api("/finance/summary/")
      .then(setData)
      .catch((e) => setError(e.message));
  }, []);

  if (error) return <div className="error">{error}</div>;
  if (!data) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  const maxMonthly = Math.max(1, ...data.monthly_revenue.map((m) => Number(m.revenue) || 0));

  return (
    <div className="flex flex-col gap-6">
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        {data.scope === "platform"
          ? `Butun bozor bo'yicha (${data.companies_count} ta kompaniya) — barcha firmalarning umumiy moliyaviy holati.`
          : "Kompaniyangizning moliyaviy holati — yakunlangan buyurtmalar, ishlab chiqarish tannarxi va ish haqi asosida."}
      </p>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          tone={0}
          icon={TrendingUp}
          label="Daromad (yakunlangan)"
          value={som(data.revenue_total)}
          hint={`${data.completed_orders_count}/${data.orders_count} buyurtma`}
        />
        <StatCard
          tone={1}
          icon={Wallet}
          label="Ishlab chiqarish foydasi"
          value={som(data.unit_profit_total)}
          hint={`Tannarx: ${som(data.material_cost_total + data.labor_cost_total)}`}
        />
        <StatCard
          tone={2}
          icon={HandCoins}
          label="Ish haqi fondi"
          value={som(data.payroll_total)}
          hint={data.payroll_unpaid > 0 ? `${som(data.payroll_unpaid)} to'lanmagan` : "Hammasi to'langan"}
        />
        <StatCard
          tone={data.net_profit >= 0 ? 2 : 3}
          icon={PiggyBank}
          label="Sof foyda"
          value={som(data.net_profit)}
          hint="Ishlab chiqarish foydasi − ish haqi"
        />
      </div>

      <div className="card p-5">
        <h2 className="mb-4 text-base font-semibold">Oxirgi 6 oy — daromad (yakunlangan buyurtmalar)</h2>
        {data.monthly_revenue.length === 0 ? (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali yakunlangan buyurtma yo'q.</p>
        ) : (
          <div className="flex items-end gap-3" style={{ height: 160 }}>
            {data.monthly_revenue.map((m) => (
              <div key={m.month} className="flex flex-1 flex-col items-center gap-1.5">
                <span className="text-[10px]" style={{ color: "var(--muted)" }}>
                  {Number(m.revenue).toLocaleString()}
                </span>
                <div
                  className="w-full rounded-t-lg"
                  style={{
                    height: `${Math.max(4, (Number(m.revenue) / maxMonthly) * 120)}px`,
                    background: "var(--brand-cta-bg)",
                  }}
                />
                <span className="text-[10px] font-medium" style={{ color: "var(--muted)" }}>{m.month}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {data.scope === "platform" && (
        <div className="card p-5">
          <h2 className="mb-4 text-base font-semibold">Eng ko'p daromad keltirgan firmalar</h2>
          {data.top_companies.length === 0 ? (
            <p className="text-sm" style={{ color: "var(--muted)" }}>Hali ma'lumot yo'q.</p>
          ) : (
            <div className="flex flex-col gap-2">
              {data.top_companies.map((c, i) => (
                <div key={c.name + i} className="flex items-center justify-between rounded-xl px-3 py-2" style={{ border: "1px solid var(--border)" }}>
                  <span className="text-sm font-medium">{i + 1}. {c.name}</span>
                  <span className="text-sm font-bold" style={{ color: "var(--secondary)" }}>{som(c.revenue)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
