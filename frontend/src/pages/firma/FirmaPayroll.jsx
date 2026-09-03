import { Fragment, useEffect, useMemo, useState } from "react";
import { Calculator, ChevronDown, ChevronUp, Wallet } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";
import LoadMoreButton from "../../components/LoadMoreButton";

function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

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
  const [expandedId, setExpandedId] = useState(null);

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
            <div className="text-xl font-bold" style={{ color: "var(--success)" }}>{totals.paid.toLocaleString()} so'm</div>
          </div>
          <div className="card p-4">
            <div className="text-xs" style={{ color: "var(--muted)" }}>To'lanmagan</div>
            <div className="text-xl font-bold" style={{ color: "var(--warning)" }}>{totals.unpaid.toLocaleString()} so'm</div>
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
                <Fragment key={p.id}>
                <tr>
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
                    {!p.is_paid && Number(p.paid_total) > 0 && (
                      <div className="mt-1 text-[11px]" style={{ color: "var(--muted)" }}>
                        {Number(p.paid_total).toLocaleString()} avans berilgan
                      </div>
                    )}
                  </td>
                  <td className="text-right">
                    <div className="flex items-center justify-end gap-1.5">
                      {!p.is_paid && (
                        <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => markPaid(p)}>
                          <Wallet size={13} /> To'liq to'lash
                        </button>
                      )}
                      <button
                        className="btn-ghost inline-flex items-center gap-1 !px-2 !py-1.5 text-xs"
                        onClick={() => setExpandedId((id) => (id === p.id ? null : p.id))}
                      >
                        To'lovlar {expandedId === p.id ? <ChevronUp size={13} /> : <ChevronDown size={13} />}
                      </button>
                    </div>
                  </td>
                </tr>
                {expandedId === p.id && (
                  <tr>
                    <td colSpan={9} className="!p-0">
                      <PayslipPaymentsPanel payslip={p} onChanged={load} />
                    </td>
                  </tr>
                )}
                </Fragment>
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

/// Bitta oylik uchun to'lovlar tarixi (avans + yakuniy) + yangi to'lov
/// qo'shish formasi — jadval qatori kengaytirilganda ko'rinadi (qarang
/// ManagerPayroll). Backend `/payslips/{id}/payments/` (GET/POST) orqali.
function PayslipPaymentsPanel({ payslip, onChanged }) {
  const [payments, setPayments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ kind: "advance", amount: "", paid_at: todayISO(), note: "" });

  const load = () => {
    setLoading(true);
    api(`/payslips/${payslip.id}/payments/`)
      .then(setPayments)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payslip.id]);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(`/payslips/${payslip.id}/payments/`, {
        method: "POST",
        body: { kind: form.kind, amount: form.amount, paid_at: form.paid_at, note: form.note },
      });
      setForm({ kind: "advance", amount: "", paid_at: todayISO(), note: "" });
      load();
      onChanged();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const outstanding = Number(payslip.outstanding_amount);

  return (
    <div className="flex flex-col gap-3 p-4" style={{ background: "var(--bg)", borderTop: "1px solid var(--border)" }}>
      <div className="flex flex-wrap gap-4 text-xs" style={{ color: "var(--muted)" }}>
        <span>Jami: <strong style={{ color: "var(--text)" }}>{Number(payslip.total_amount).toLocaleString()} so'm</strong></span>
        <span>To'langan: <strong style={{ color: "var(--success)" }}>{Number(payslip.paid_total).toLocaleString()} so'm</strong></span>
        <span>Qoldiq: <strong style={{ color: outstanding > 0 ? "var(--warning)" : "var(--success)" }}>{outstanding.toLocaleString()} so'm</strong></span>
      </div>

      {loading ? (
        <p className="text-xs" style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>
      ) : payments.length === 0 ? (
        <p className="text-xs" style={{ color: "var(--muted)" }}>Hali to'lov qilinmagan.</p>
      ) : (
        <div className="flex flex-col gap-1">
          {payments.map((pm) => (
            <div key={pm.id} className="flex items-center justify-between rounded-lg px-3 py-1.5 text-xs" style={{ background: "var(--card)", border: "1px solid var(--border)" }}>
              <span>
                <strong>{pm.kind_display}</strong> — {Number(pm.amount).toLocaleString()} so'm
                {pm.note && <span style={{ color: "var(--muted)" }}> ({pm.note})</span>}
              </span>
              <span style={{ color: "var(--muted)" }}>{pm.paid_at}</span>
            </div>
          ))}
        </div>
      )}

      {error && <div className="error">{error}</div>}

      {outstanding > 0 && (
        <form onSubmit={submit} className="flex flex-wrap items-end gap-2">
          <div>
            <label className="label">Turi</label>
            <select className="input !w-32 !py-1.5 text-xs" value={form.kind} onChange={(e) => setForm({ ...form, kind: e.target.value })}>
              <option value="advance">Avans</option>
              <option value="final">Yakuniy</option>
            </select>
          </div>
          <div>
            <label className="label">Summa (max {outstanding.toLocaleString()})</label>
            <input
              className="input !w-32 !py-1.5 text-xs" type="number" min="1" max={outstanding} required
              value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })}
            />
          </div>
          <div>
            <label className="label">Sana</label>
            <input
              className="input !w-36 !py-1.5 text-xs" type="date"
              value={form.paid_at} onChange={(e) => setForm({ ...form, paid_at: e.target.value })}
            />
          </div>
          <div className="min-w-[160px] flex-1">
            <label className="label">Izoh (ixtiyoriy)</label>
            <input className="input !py-1.5 text-xs" value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
          </div>
          <button className="btn !px-3 !py-1.5 text-xs" disabled={busy} type="submit">
            {busy ? "Saqlanmoqda…" : "To'lov qo'shish"}
          </button>
        </form>
      )}
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
              {!p.is_paid && Number(p.paid_total) > 0 && (
                <div className="mt-1 text-[11px]" style={{ color: "var(--muted)" }}>
                  {Number(p.paid_total).toLocaleString()} avans olingan
                </div>
              )}
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
