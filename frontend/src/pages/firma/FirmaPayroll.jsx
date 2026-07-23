import { useEffect, useMemo, useState } from "react";
import { Calculator, Wallet } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";

function currentPeriod() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

function periodLabel(period) {
  const [y, m] = period.split("-");
  const names = [
    "Yanvar", "Fevral", "Mart", "Aprel", "May", "Iyun",
    "Iyul", "Avgust", "Sentabr", "Oktabr", "Noyabr", "Dekabr",
  ];
  return `${names[parseInt(m, 10) - 1]} ${y}`;
}

export default function FirmaPayroll() {
  const { user } = useAuth();
  return user?.role === "company_owner" ? <ManagerPayroll /> : <MyPayslips />;
}

function ManagerPayroll() {
  const [period, setPeriod] = useState(currentPeriod());
  const [payslips, setPayslips] = useState([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(false);

  const load = () => {
    setLoaded(false);
    api(`/payslips/?period=${period}`)
      .then((d) => setPayslips(d.results || []))
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
  };

  useEffect(() => {
    load();
  }, [period]);

  const generate = async () => {
    setBusy(true);
    setError("");
    try {
      const results = await api("/payslips/generate/", { method: "POST", body: { period } });
      setPayslips(results);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  const markPaid = async (p) => {
    if (!confirm(`${p.employee_name} uchun ${Number(p.total_amount).toLocaleString()} so'm to'landi deb belgilansinmi?`)) return;
    try {
      await api(`/payslips/${p.id}/mark_paid/`, { method: "POST" });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const totals = useMemo(() => {
    const total = payslips.reduce((s, p) => s + Number(p.total_amount), 0);
    const paid = payslips.filter((p) => p.is_paid).reduce((s, p) => s + Number(p.total_amount), 0);
    return { total, paid, unpaid: total - paid };
  }, [payslips]);

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <label className="label">Oy</label>
          <input
            className="input !w-44"
            type="month"
            value={period}
            onChange={(e) => setPeriod(e.target.value)}
          />
        </div>
        <button className="btn inline-flex items-center gap-1.5" onClick={generate} disabled={busy}>
          {busy ? "Hisoblanmoqda…" : <><Calculator size={15} /> {periodLabel(period)} uchun hisoblash</>}
        </button>
      </div>

      {error && <div className="error">{error}</div>}

      {payslips.length > 0 && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
          <div className="card p-4">
            <div className="text-xs" style={{ color: "var(--muted)" }}>Jami ish haqi</div>
            <div className="text-xl font-bold">{totals.total.toLocaleString()} so'm</div>
          </div>
          <div className="card p-4">
            <div className="text-xs" style={{ color: "var(--muted)" }}>To'langan</div>
            <div className="text-xl font-bold" style={{ color: "#27ae60" }}>{totals.paid.toLocaleString()} so'm</div>
          </div>
          <div className="card p-4">
            <div className="text-xs" style={{ color: "var(--muted)" }}>To'lanmagan</div>
            <div className="text-xl font-bold" style={{ color: "#e67e22" }}>{totals.unpaid.toLocaleString()} so'm</div>
          </div>
        </div>
      )}

      {loaded && payslips.length === 0 && (
        <div className="card flex flex-col items-center gap-2 p-8 text-center">
          <Calculator size={32} style={{ color: "var(--muted)" }} />
          <p className="text-sm" style={{ color: "var(--muted)" }}>
            {periodLabel(period)} uchun hali hisoblanmagan. Yuqoridagi tugmani bosing.
          </p>
        </div>
      )}

      {payslips.length > 0 && (
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Xodim</th>
                <th>Kasblari</th>
                <th>Bazaviy oylik</th>
                <th>Bajarilgan vazifa</th>
                <th>Bonus</th>
                <th>Workflow bosqichlari</th>
                <th>Jami</th>
                <th>Holat</th>
                <th className="text-right">Amal</th>
              </tr>
            </thead>
            <tbody>
              {payslips.map((p) => (
                <tr key={p.id}>
                  <td className="font-medium">{p.employee_name}</td>
                  <td>
                    <div className="flex flex-wrap gap-1">
                      {(p.positions || []).map((pos) => {
                        const Icon = POSITIONS[pos]?.icon;
                        return (
                          <span key={pos} className="badge badge-brand inline-flex items-center gap-1">
                            {Icon && <Icon size={12} />} {POSITIONS[pos]?.label || pos}
                          </span>
                        );
                      })}
                    </div>
                  </td>
                  <td>{Number(p.base_salary).toLocaleString()} so'm</td>
                  <td>{p.tasks_completed} ta</td>
                  <td>{Number(p.bonus_amount).toLocaleString()} so'm</td>
                  <td>{Number(p.workflow_earnings || 0).toLocaleString()} so'm</td>
                  <td className="font-bold">{Number(p.total_amount).toLocaleString()} so'm</td>
                  <td>
                    <span className={p.is_paid ? "badge" : "badge badge-off"}>
                      {p.is_paid ? "To'landi" : "Kutilmoqda"}
                    </span>
                  </td>
                  <td className="text-right">
                    {!p.is_paid && (
                      <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => markPaid(p)}>
                        <Wallet size={13} /> To'landi deb belgilash
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <p className="text-xs" style={{ color: "var(--muted)" }}>
        Jami = bazaviy oylik + (shu oyda bajarilgan vazifalar soni × har-vazifa bonusi). Oylik/bonus
        stavkalarini <strong>Xodimlar</strong> bo'limida sozlang. To'langan oylar qayta hisoblanganda o'zgarmaydi.
      </p>
    </div>
  );
}

function MyPayslips() {
  const [payslips, setPayslips] = useState([]);
  const [error, setError] = useState("");

  useEffect(() => {
    api("/payslips/")
      .then((d) => setPayslips(d.results || []))
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-base font-semibold">Mening ish haqim</h2>
      {error && <div className="error">{error}</div>}
      {payslips.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali hisoblangan oylik yo'q.</p>
      )}
      <div className="flex flex-col gap-3">
        {payslips.map((p) => (
          <div key={p.id} className="card flex flex-wrap items-center justify-between gap-3 p-4">
            <div>
              <div className="font-semibold">{periodLabel(p.period.slice(0, 7))}</div>
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                Bazaviy {Number(p.base_salary).toLocaleString()} so'm + {p.tasks_completed} ta vazifa ×{" "}
                {Number(p.bonus_per_task).toLocaleString()} so'm
              </div>
            </div>
            <div className="text-right">
              <div className="text-lg font-bold">{Number(p.total_amount).toLocaleString()} so'm</div>
              <span className={p.is_paid ? "badge" : "badge badge-off"}>
                {p.is_paid ? "To'landi" : "Kutilmoqda"}
              </span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
