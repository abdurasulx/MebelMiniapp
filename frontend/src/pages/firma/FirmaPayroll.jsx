import { useEffect, useMemo, useState } from "react";
import { Calculator, Wallet } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";
import LoadMoreButton from "../../components/LoadMoreButton";

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

/// To'lov turiga mos asosiy summa tavsifi (KPI/workflow bonusidan tashqari).
function payBreakdown(p) {
  switch (p.pay_type) {
    case "fixed":
      return `${Number(p.base_salary).toLocaleString()} so'm/oy`;
    case "fixed_bonus":
      return `${Number(p.base_salary).toLocaleString()} so'm + ${p.tasks_completed} ta × ${Number(p.bonus_per_task).toLocaleString()}`;
    case "commission":
      return `${Number(p.commission_sales).toLocaleString()} so'mdan ${Number(p.commission_amount).toLocaleString()} so'm`;
    case "hourly":
      return `${Number(p.manual_hours).toLocaleString()} soat × ${Number(p.hourly_amount / (p.manual_hours || 1)).toLocaleString()}`;
    default:
      return "—";
  }
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
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hoursDraft, setHoursDraft] = useState({});

  const load = () => {
    setLoaded(false);
    api(`/payslips/?period=${period}`)
      .then((d) => {
        setPayslips(d.results || []);
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
  };

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setPayslips((prev) => [...prev, ...(d.results || [])]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
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

  const saveHours = async (p) => {
    try {
      await api(`/payslips/${p.id}/set_hours/`, {
        method: "POST",
        body: { manual_hours: hoursDraft[p.id] ?? p.manual_hours },
      });
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
                <th>To'lov turi</th>
                <th>Asosiy summa</th>
                <th>Workflow bosqichlari</th>
                <th>KPI</th>
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
                  <td className="text-xs" style={{ color: "var(--muted)" }}>{p.pay_type_display}</td>
                  <td className="text-xs">
                    {payBreakdown(p)}
                    {p.pay_type === "hourly" && !p.is_paid && (
                      <div className="mt-1 flex items-center gap-1">
                        <input
                          className="input !w-20 !py-1 text-xs"
                          type="number" min="0" step="0.5"
                          placeholder={p.manual_hours}
                          value={hoursDraft[p.id] ?? ""}
                          onChange={(e) => setHoursDraft((d) => ({ ...d, [p.id]: e.target.value }))}
                        />
                        <button className="btn-ghost !px-2 !py-1 text-xs" onClick={() => saveHours(p)}>Soat kiritish</button>
                      </div>
                    )}
                  </td>
                  <td>{Number(p.workflow_earnings || 0).toLocaleString()} so'm</td>
                  <td>
                    {Number(p.kpi_bonus_amount) > 0 ? (
                      <span className="badge">✓ +{Number(p.kpi_bonus_amount).toLocaleString()}</span>
                    ) : (
                      <span className="text-xs" style={{ color: "var(--muted)" }}>—</span>
                    )}
                  </td>
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
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>

      <p className="text-xs" style={{ color: "var(--muted)" }}>
        Jami = to'lov turiga mos asosiy summa (oylik/bonus/komissiya/soatbay) + workflow bosqichlari +
        KPI bonusi (agar lavozim standartidagi maqsad bajarilgan bo'lsa). To'lov turi/stavkalarini{" "}
        <strong>Xodimlar</strong>, KPI maqsadlarini esa <strong>Sozlamalar</strong> yoki platforma admin
        panelida sozlang. To'langan oylar qayta hisoblanganda o'zgarmaydi.
      </p>
    </div>
  );
}

function MyPayslips() {
  const [payslips, setPayslips] = useState([]);
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  useEffect(() => {
    api("/payslips/")
      .then((d) => {
        setPayslips(d.results || []);
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message));
  }, []);

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setPayslips((prev) => [...prev, ...(d.results || [])]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  };

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
                {p.pay_type_display} · {payBreakdown(p)}
                {Number(p.workflow_earnings) > 0 && ` + ${Number(p.workflow_earnings).toLocaleString()} workflow`}
                {Number(p.kpi_bonus_amount) > 0 && ` + ${Number(p.kpi_bonus_amount).toLocaleString()} KPI bonus`}
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
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}
