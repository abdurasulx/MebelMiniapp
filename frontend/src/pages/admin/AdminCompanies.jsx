import { useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";
import { api } from "../../api";

export default function AdminCompanies() {
  const [companies, setCompanies] = useState([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");

  const load = () =>
    api("/companies/")
      .then((d) => setCompanies(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const toggle = async (c) => {
    try {
      await api(`/companies/${c.slug}/`, { method: "PATCH", body: { is_active: !c.is_active } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const shown = companies.filter((c) =>
    search.trim() ? c.name.toLowerCase().includes(search.trim().toLowerCase()) : true
  );

  return (
    <div className="flex flex-col gap-4">
      <div className="toolbar">
        <input
          className="input max-w-xs"
          placeholder="Kompaniya nomi bo'yicha qidirish…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <span className="ml-auto text-xs" style={{ color: "var(--muted)" }}>
          {shown.length} / {companies.length} kompaniya
        </span>
        <button className="icon-btn" onClick={load} title="Yangilash"><RefreshCw size={15} /></button>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Kompaniya</th>
              <th>Telefon</th>
              <th>Manzil</th>
              <th>Holat</th>
              <th className="text-right">Amal</th>
            </tr>
          </thead>
          <tbody>
            {shown.map((c) => (
              <tr key={c.id}>
                <td className="font-medium">
                  <div className="flex items-center gap-2">
                    <span
                      className="flex h-8 w-8 items-center justify-center rounded-lg text-xs font-bold"
                      style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)", color: "var(--primary-deep)" }}
                    >
                      {c.name[0]?.toUpperCase()}
                    </span>
                    {c.name}
                  </div>
                </td>
                <td>{c.phone || "—"}</td>
                <td>{c.address || "—"}</td>
                <td>
                  <span className={c.is_active ? "badge" : "badge badge-off"}>
                    {c.is_active ? "Faol" : "Bloklangan"}
                  </span>
                </td>
                <td className="text-right">
                  {c.is_active ? (
                    <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => toggle(c)}>
                      Bloklash
                    </button>
                  ) : (
                    <button className="btn !px-3 !py-1.5 text-xs" onClick={() => toggle(c)}>
                      Faollashtirish
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {shown.length === 0 && (
              <tr>
                <td colSpan={5} style={{ color: "var(--muted)" }}>
                  {companies.length === 0 ? "Kompaniyalar yo'q." : "Qidiruvga mos kompaniya topilmadi."}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
