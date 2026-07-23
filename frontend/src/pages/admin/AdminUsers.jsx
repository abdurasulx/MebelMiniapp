import { useEffect, useState } from "react";
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

  useEffect(() => {
    const t = setTimeout(() => {
      const qs = new URLSearchParams();
      if (search) qs.set("search", search);
      if (role) qs.set("role", role);
      api(`/admin/users/?${qs}`)
        .then((d) => setUsers(d.results || []))
        .catch((e) => setError(e.message));
    }, 300);
    return () => clearTimeout(t);
  }, [search, role]);

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
              <th>Ro'yxatdan o'tgan</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td className="font-medium">{u.email}</td>
                <td>{u.first_name || "—"}</td>
                <td><span className="badge badge-brand">{ROLE_LABEL[u.role] || u.role}</span></td>
                <td>{u.company?.name || "—"}</td>
                <td>{new Date(u.date_joined).toLocaleDateString("uz-UZ")}</td>
              </tr>
            ))}
            {users.length === 0 && (
              <tr>
                <td colSpan={5} style={{ color: "var(--muted)" }}>Topilmadi.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
