import { useEffect, useState } from "react";
import { api } from "../api";
import { POSITIONS } from "../positions";

export default function Employees() {
  const [list, setList] = useState([]);
  const [form, setForm] = useState({ email: "", positions: [], base_salary: "", bonus_per_task: "" });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [editing, setEditing] = useState(null);

  const load = () =>
    api("/employees/")
      .then((d) => setList(d.results || []))
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

  const add = async (e) => {
    e.preventDefault();
    setError("");
    if (form.positions.length === 0) {
      setError("Kamida bitta kasb tanlang");
      return;
    }
    try {
      await api("/employees/", {
        method: "POST",
        body: {
          ...form,
          base_salary: form.base_salary || 0,
          bonus_per_task: form.bonus_per_task || 0,
        },
      });
      setForm({ email: "", positions: [], base_salary: "", bonus_per_task: "" });
      setMsg("Xodim qo'shildi");
      setTimeout(() => setMsg(""), 3000);
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const remove = async (emp) => {
    if (!confirm(`${emp.user_email} xodimlikdan chiqarilsinmi?`)) return;
    try {
      await api(`/employees/${emp.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <form className="card flex flex-col gap-4 p-5" onSubmit={add}>
        <h2 className="text-base font-semibold">+ Yangi xodim</h2>
        <div className="max-w-md">
          <label className="label">Xodim emaili (avval ro'yxatdan o'tgan bo'lsin)</label>
          <input
            className="input"
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
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
        <button className="btn self-start" type="submit">+ Qo'shish</button>
      </form>

      {msg && <span className="badge self-start">{msg}</span>}
      {error && <div className="error">{error}</div>}

      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Email</th>
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
                <td className="font-medium">{emp.user_email}</td>
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
                    <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => remove(emp)}>
                      Chiqarish
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
