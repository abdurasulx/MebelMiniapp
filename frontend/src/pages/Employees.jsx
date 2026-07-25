import { useEffect, useState } from "react";
import { api } from "../api";
import { POSITIONS } from "../positions";

const INVITATION_STATUS_BADGE = {
  pending: "badge-off",
  accepted: "badge",
  declined: "badge-off",
};

export default function Employees() {
  const [list, setList] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [form, setForm] = useState({ worker_id: "", positions: [], base_salary: "", bonus_per_task: "" });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [editing, setEditing] = useState(null);

  const load = () =>
    Promise.all([api("/employees/"), api("/employee-invitations/")])
      .then(([emp, inv]) => {
        setList(emp.results || []);
        setInvitations(inv.results || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const togglePosition = (p) =>
    setForm((f) => ({
      ...f,
      positions: f.positions.includes(p)
        ? f.positions.filter((x) => x !== p)
        : [...f.positions, p],
    }));

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
        },
      });
      setForm({ worker_id: "", positions: [], base_salary: "", bonus_per_task: "" });
      setMsg("Taklif yuborildi — xodim o'z ilovasida qabul qilishi kerak");
      setTimeout(() => setMsg(""), 4000);
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

  return (
    <div className="flex flex-col gap-4">
      <form className="card flex flex-col gap-4 p-5" onSubmit={invite}>
        <h2 className="text-base font-semibold">Ishga taklif qilish</h2>
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
                  {p.icon} {p.label}
                </button>
              );
            })}
          </div>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 sm:max-w-md">
          <div>
            <label className="label">Bazaviy oylik (so'm)</label>
            <input
              className="input"
              type="number"
              min="0"
              placeholder="0"
              value={form.base_salary}
              onChange={(e) => setForm({ ...form, base_salary: e.target.value })}
            />
          </div>
          <div>
            <label className="label">Har vazifa uchun bonus (so'm)</label>
            <input
              className="input"
              type="number"
              min="0"
              placeholder="0"
              value={form.bonus_per_task}
              onChange={(e) => setForm({ ...form, bonus_per_task: e.target.value })}
            />
          </div>
        </div>
        <button className="btn self-start" type="submit">Taklif yuborish</button>
      </form>

      {msg && <span className="badge self-start">{msg}</span>}
      {error && <div className="error">{error}</div>}

      {invitations.length > 0 && (
        <div className="card flex flex-col gap-3 p-5">
          <h2 className="text-base font-semibold">Yuborilgan takliflar</h2>
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Ismi</th>
                  <th>Kasblari</th>
                  <th>Holat</th>
                  <th>Sana</th>
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
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Ismi</th>
              <th>Kasblari</th>
              <th>Oylik</th>
              <th>Bonus/vazifa</th>
              <th>Holat</th>
              <th className="text-right">Amal</th>
            </tr>
          </thead>
          <tbody>
            {list.map((emp) => (
              <tr key={emp.id}>
                <td className="font-medium">{emp.user_worker_id}</td>
                <td>{emp.user_name || "—"}</td>
                <td>
                  <div className="flex flex-wrap gap-1">
                    {(emp.positions || []).map((p) => {
                      const Icon = POSITIONS[p]?.icon;
                      return (
                        <span key={p} className="badge badge-brand inline-flex items-center gap-1">
                          {Icon && <Icon size={12} />} {POSITIONS[p]?.label || p}
                        </span>
                      );
                    })}
                    {(!emp.positions || emp.positions.length === 0) && "—"}
                  </div>
                </td>
                <td>{Number(emp.base_salary || 0).toLocaleString()} so'm</td>
                <td>{Number(emp.bonus_per_task || 0).toLocaleString()} so'm</td>
                <td>
                  <span className={emp.is_active ? "badge" : "badge badge-off"}>
                    {emp.is_active ? "Faol" : "Nofaol"}
                  </span>
                </td>
                <td className="text-right">
                  <div className="flex justify-end gap-2">
                    <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => setEditing(emp)}>
                      Oylikni tahrirlash
                    </button>
                    <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => fire(emp)}>
                      Ishdan bo'shatish
                    </button>
                  </div>
                </td>
              </tr>
            ))}
            {list.length === 0 && (
              <tr>
                <td colSpan={7} style={{ color: "var(--muted)" }}>Hali xodimlar yo'q.</td>
              </tr>
            )}
          </tbody>
        </table>
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
  const [baseSalary, setBaseSalary] = useState(employee.base_salary || 0);
  const [bonusPerTask, setBonusPerTask] = useState(employee.bonus_per_task || 0);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api(`/employees/${employee.id}/`, {
        method: "PATCH",
        body: { base_salary: baseSalary, bonus_per_task: bonusPerTask },
      });
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
        <div>
          <label className="label">Bazaviy oylik (so'm)</label>
          <input
            className="input"
            type="number"
            min="0"
            value={baseSalary}
            onChange={(e) => setBaseSalary(e.target.value)}
          />
        </div>
        <div>
          <label className="label">Har vazifa uchun bonus (so'm)</label>
          <input
            className="input"
            type="number"
            min="0"
            value={bonusPerTask}
            onChange={(e) => setBonusPerTask(e.target.value)}
          />
        </div>
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
