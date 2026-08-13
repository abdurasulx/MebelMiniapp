import { useEffect, useState } from "react";
import { UserPlus, Users, Mail, X } from "lucide-react";
import { api } from "../api";
import { POSITIONS } from "../positions";
import LoadMoreButton from "../components/LoadMoreButton";

const INVITATION_STATUS_BADGE = {
  pending: "badge-off",
  accepted: "badge",
  declined: "badge-off",
};

const PAY_TYPES = {
  fixed: "Faqat oylik",
  fixed_bonus: "Oylik + vazifa bonusi",
  commission: "Komissiya (% sotuvdan)",
  hourly: "Soatbay",
};

/// Bir lavozim uchun eng mos standart: avval firmaning o'ziniki, bo'lmasa
/// platforma standarti (qarang backend PositionPayStandard).
function pickStandard(standards, position) {
  const forPosition = standards.filter((s) => s.position === position);
  return forPosition.find((s) => !s.is_platform_default) || forPosition.find((s) => s.is_platform_default) || null;
}

function PayTypeFields({ payType, values, onChange, standard }) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 sm:max-w-md">
      <div className="sm:col-span-2">
        <label className="label">To'lov turi</label>
        <select className="input" value={payType} onChange={(e) => onChange({ pay_type: e.target.value })}>
          {Object.entries(PAY_TYPES).map(([k, label]) => (
            <option key={k} value={k}>{label}</option>
          ))}
        </select>
        {standard && Number(standard.max_salary) > 0 && (
          <p className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
            Tavsiya etilgan oylik: {Number(standard.min_salary).toLocaleString()}–
            {Number(standard.max_salary).toLocaleString()} so'm
          </p>
        )}
      </div>
      {(payType === "fixed" || payType === "fixed_bonus") && (
        <div>
          <label className="label">Bazaviy oylik (so'm)</label>
          <input className="input" type="number" min="0" placeholder="0"
            value={values.base_salary} onChange={(e) => onChange({ base_salary: e.target.value })} />
        </div>
      )}
      {payType === "fixed_bonus" && (
        <div>
          <label className="label">Har vazifa uchun bonus (so'm)</label>
          <input className="input" type="number" min="0" placeholder="0"
            value={values.bonus_per_task} onChange={(e) => onChange({ bonus_per_task: e.target.value })} />
        </div>
      )}
      {payType === "commission" && (
        <div>
          <label className="label">Komissiya (% sotuvdan)</label>
          <input className="input" type="number" min="0" max="100" placeholder="0"
            value={values.commission_percent} onChange={(e) => onChange({ commission_percent: e.target.value })} />
        </div>
      )}
      {payType === "hourly" && (
        <div>
          <label className="label">Soatbay narx (so'm)</label>
          <input className="input" type="number" min="0" placeholder="0"
            value={values.hourly_rate} onChange={(e) => onChange({ hourly_rate: e.target.value })} />
        </div>
      )}
    </div>
  );
}

function initials(name) {
  if (!name) return "?";
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase())
    .join("");
}

export default function Employees() {
  const [list, setList] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [standards, setStandards] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({
    worker_id: "", positions: [], pay_type: "fixed_bonus",
    base_salary: "", bonus_per_task: "", commission_percent: "", hourly_rate: "",
  });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [editing, setEditing] = useState(null);
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    Promise.all([api("/employees/"), api("/employee-invitations/"), api("/pay-standards/")])
      .then(([emp, inv, pay]) => {
        setList(emp.results || []);
        setNextPage(emp.next || null);
        setInvitations(inv.results || []);
        setStandards(pay.results || []);
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setList((l) => [...l, ...(d.results || [])]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const togglePosition = (p) =>
    setForm((f) => {
      const adding = !f.positions.includes(p);
      const positions = adding ? [...f.positions, p] : f.positions.filter((x) => x !== p);
      // Birinchi kasb tanlanganda standart to'lov turini/summasini boshlang'ich
      // taklif sifatida to'ldiramiz — foydalanuvchi keyin o'zi o'zgartirishi mumkin.
      if (adding && f.positions.length === 0) {
        const standard = pickStandard(standards, p);
        if (standard) {
          return {
            ...f, positions,
            pay_type: standard.pay_type,
            bonus_per_task: standard.default_bonus_per_task || "",
            commission_percent: standard.default_commission_percent || "",
            hourly_rate: standard.default_hourly_rate || "",
          };
        }
      }
      return { ...f, positions };
    });

  const invite = async (e) => {
    e.preventDefault();
    setError("");
    if (form.positions.length === 0) {
      setError("Kamida bitta kasb tanlang");
      return;
    }
    try {
      await api("/employee-invitations/", {
        method: "POST",
        body: {
          ...form,
          base_salary: form.base_salary || 0,
          bonus_per_task: form.bonus_per_task || 0,
          commission_percent: form.commission_percent || 0,
          hourly_rate: form.hourly_rate || 0,
        },
      });
      setForm({
        worker_id: "", positions: [], pay_type: "fixed_bonus",
        base_salary: "", bonus_per_task: "", commission_percent: "", hourly_rate: "",
      });
      setMsg("Taklif yuborildi — xodim o'z ilovasida qabul qilishi kerak");
      setTimeout(() => setMsg(""), 4000);
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const cancelInvitation = async (inv) => {
    if (!confirm(`${inv.invited_worker_id} uchun taklif bekor qilinsinmi?`)) return;
    try {
      await api(`/employee-invitations/${inv.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const fire = async (emp) => {
    if (!confirm(`${emp.user_name || emp.user_email} ishdan bo'shatilsinmi?`)) return;
    try {
      await api(`/employees/${emp.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  if (loading) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="flex flex-col gap-4">
      <form className="card flex flex-col gap-4 p-5" onSubmit={invite}>
        <h2 className="inline-flex items-center gap-2 text-base font-semibold">
          <UserPlus size={17} /> Ishga taklif qilish
        </h2>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          Xodim mobil ilovadagi profilida ko'rsatilgan shaxsiy ID raqamini sizga aytadi — shu ID orqali
          taklif yuborasiz. Xodim taklifni o'z ilovasida (Flutter/iOS) qabul qilgandan keyingina
          ro'yxatga qo'shiladi — yangi xodim to'g'ridan-to'g'ri bu yerdan yaratilmaydi.
        </p>
        <div className="max-w-md">
          <label className="label">Xodimning ID raqami</label>
          <input
            className="input"
            value={form.worker_id}
            onChange={(e) => setForm({ ...form, worker_id: e.target.value })}
            placeholder="masalan 4829173650"
            required
          />
        </div>
        <div>
          <label className="label">Kasblari (bir nechtasini tanlash mumkin)</label>
          <div className="flex flex-wrap gap-2">
            {Object.entries(POSITIONS).map(([key, p]) => {
              const on = form.positions.includes(key);
              return (
                <button
                  type="button"
                  key={key}
                  onClick={() => togglePosition(key)}
                  className="flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
                  style={
                    on
                      ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                      : {
                          background: "transparent",
                          color: "var(--muted)",
                          border: "1px solid var(--border)",
                        }
                  }
                >
                  <p.icon size={13} /> {p.label}
                </button>
              );
            })}
          </div>
        </div>
        <PayTypeFields
          payType={form.pay_type}
          values={form}
          onChange={(patch) => setForm((f) => ({ ...f, ...patch }))}
          standard={form.positions[0] ? pickStandard(standards, form.positions[0]) : null}
        />
        <button className="btn self-start" type="submit">Taklif yuborish</button>
      </form>

      {msg && <span className="badge self-start">{msg}</span>}
      {error && <div className="error">{error}</div>}

      {invitations.length > 0 && (
        <div className="card flex flex-col gap-3 p-5">
          <h2 className="inline-flex items-center gap-2 text-base font-semibold">
            <Mail size={16} /> Yuborilgan takliflar
          </h2>
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Ismi</th>
                  <th>Kasblari</th>
                  <th>Holat</th>
                  <th>Sana</th>
                  <th className="text-right">Amal</th>
                </tr>
              </thead>
              <tbody>
                {invitations.map((inv) => (
                  <tr key={inv.id}>
                    <td className="font-medium">{inv.invited_worker_id}</td>
                    <td>{inv.invited_user_name || "—"}</td>
                    <td>
                      <div className="flex flex-wrap gap-1">
                        {(inv.positions || []).map((p) => (
                          <span key={p} className="badge badge-brand">{POSITIONS[p]?.label || p}</span>
                        ))}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${INVITATION_STATUS_BADGE[inv.status] || ""}`}>
                        {inv.status_display}
                      </span>
                    </td>
                    <td style={{ color: "var(--muted)" }}>{new Date(inv.created_at).toLocaleDateString()}</td>
                    <td className="text-right">
                      {inv.status === "pending" && (
                        <button
                          className="btn-ghost !px-2 !py-1 text-xs inline-flex items-center gap-1"
                          onClick={() => cancelInvitation(inv)}
                          title="Taklifni bekor qilish"
                        >
                          <X size={12} /> Bekor qilish
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <div>
        <h2 className="mb-3 inline-flex items-center gap-2 text-base font-semibold">
          <Users size={17} /> Xodimlar ({list.length})
        </h2>

        {list.length === 0 ? (
          <div className="card p-8 text-center">
            <Users size={28} style={{ color: "var(--muted)", margin: "0 auto 8px" }} />
            <p className="text-sm" style={{ color: "var(--muted)" }}>
              Hali xodimlar yo'q — yuqoridagi forma orqali birinchi xodimni ishga taklif qiling.
            </p>
          </div>
        ) : (
          <div className="card flex flex-col divide-y" style={{ borderColor: "var(--border)" }}>
            {list.map((emp) => (
              <div key={emp.id} className="flex flex-wrap items-center gap-3 p-4">
                <div
                  className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-sm font-bold"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  {initials(emp.user_name)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-semibold">{emp.user_name || emp.user_email || "—"}</span>
                    <span className={emp.is_active ? "badge" : "badge badge-off"}>
                      {emp.is_active ? "Faol" : "Nofaol"}
                    </span>
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
                    <span className="font-mono">{emp.user_worker_id}</span>
                    {(emp.positions || []).map((p) => {
                      const Icon = POSITIONS[p]?.icon;
                      return (
                        <span key={p} className="badge badge-brand inline-flex items-center gap-1">
                          {Icon && <Icon size={12} />} {POSITIONS[p]?.label || p}
                        </span>
                      );
                    })}
                  </div>
                </div>
                <div className="flex flex-col items-end text-sm">
                  <span className="badge badge-off !text-[10px]">{PAY_TYPES[emp.pay_type] || emp.pay_type_display}</span>
                  {(emp.pay_type === "fixed" || emp.pay_type === "fixed_bonus") && (
                    <span>{Number(emp.base_salary || 0).toLocaleString()} so'm/oy</span>
                  )}
                  {emp.pay_type === "fixed_bonus" && (
                    <span className="text-xs" style={{ color: "var(--muted)" }}>
                      +{Number(emp.bonus_per_task || 0).toLocaleString()} so'm/vazifa
                    </span>
                  )}
                  {emp.pay_type === "commission" && (
                    <span>{Number(emp.commission_percent || 0)}% sotuvdan</span>
                  )}
                  {emp.pay_type === "hourly" && (
                    <span>{Number(emp.hourly_rate || 0).toLocaleString()} so'm/soat</span>
                  )}
                </div>
                <div className="flex gap-2">
                  <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => setEditing(emp)}>
                    Oylikni tahrirlash
                  </button>
                  <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => fire(emp)}>
                    Ishdan bo'shatish
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
        <div className="mt-3 flex justify-center">
          <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
        </div>
      </div>

      {editing && (
        <SalaryEditModal
          employee={editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            load();
          }}
        />
      )}
    </div>
  );
}

function SalaryEditModal({ employee, onClose, onSaved }) {
  const [values, setValues] = useState({
    pay_type: employee.pay_type || "fixed_bonus",
    base_salary: employee.base_salary || 0,
    bonus_per_task: employee.bonus_per_task || 0,
    commission_percent: employee.commission_percent || 0,
    hourly_rate: employee.hourly_rate || 0,
  });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api(`/employees/${employee.id}/`, { method: "PATCH", body: values });
      onSaved();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-sm flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 className="text-base font-semibold">{employee.user_name || employee.user_email} — oylik</h2>
        <PayTypeFields
          payType={values.pay_type}
          values={values}
          onChange={(patch) => setValues((v) => ({ ...v, ...patch }))}
        />
        {error && <div className="error">{error}</div>}
        <div className="flex gap-2">
          <button className="btn" type="submit" disabled={busy}>
            {busy ? "Saqlanmoqda…" : "Saqlash"}
          </button>
          <button className="btn-ghost" type="button" onClick={onClose}>
            Bekor
          </button>
        </div>
      </form>
    </div>
  );
}
