import { useEffect, useState } from "react";
import { Ban, CheckCircle2 } from "lucide-react";
import { api } from "../../api";

const ROLE_LABEL = {
  platform_admin: "Platforma admin",
  company_owner: "Kompaniya egasi",
  employee: "Xodim",
  customer: "Mijoz",
};

export default function AdminUsers() {
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState("");
  const [role, setRole] = useState("");
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState(null);

  const load = () => {
    const qs = new URLSearchParams();
    if (search) qs.set("search", search);
    if (role) qs.set("role", role);
    api(`/admin/users/?${qs}`)
      .then((d) => setUsers(d.results || []))
      .catch((e) => setError(e.message));
  };

  useEffect(() => {
    const t = setTimeout(load, 300);
    return () => clearTimeout(t);
  }, [search, role]);

  const toggleActive = async (u) => {
    const action = u.is_active ? "bloklansinmi" : "blokdan chiqarilsinmi";
    if (!confirm(`"${u.email}" ${action}?`)) return;
    setBusyId(u.id);
    setError("");
    try {
      const updated = await api(`/admin/users/${u.id}/toggle-active/`, { method: "POST" });
      setUsers((prev) => prev.map((x) => (x.id === u.id ? updated : x)));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-3">
        <input
          className="input max-w-xs"
          placeholder="Email bo'yicha qidirish…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select className="input max-w-[200px]" value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">Barcha rollar</option>
          {Object.entries(ROLE_LABEL).map(([k, v]) => (
            <option key={k} value={k}>{v}</option>
          ))}
        </select>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Email</th>
              <th>Ismi</th>
              <th>Rol</th>
              <th>Kompaniya</th>
              <th>Holati</th>
              <th>Ro'yxatdan o'tgan</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td className="font-medium">{u.email}</td>
                <td>{u.first_name || "—"}</td>
                <td><span className="badge badge-brand">{ROLE_LABEL[u.role] || u.role}</span></td>
                <td>{u.company?.name || "—"}</td>
                <td>
                  <span className={u.is_active === false ? "badge badge-off" : "badge"}>
                    {u.is_active === false ? "Bloklangan" : "Faol"}
                  </span>
                </td>
                <td>{new Date(u.date_joined).toLocaleDateString("uz-UZ")}</td>
                <td>
                  {u.role !== "platform_admin" && (
                    <button
                      className={u.is_active === false ? "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn-danger inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                      disabled={busyId === u.id}
                      onClick={() => toggleActive(u)}
                    >
                      {u.is_active === false ? <><CheckCircle2 size={12} /> Blokdan chiqarish</> : <><Ban size={12} /> Bloklash</>}
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan={7} style={{ color: "var(--muted)" }}>Topilmadi.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
