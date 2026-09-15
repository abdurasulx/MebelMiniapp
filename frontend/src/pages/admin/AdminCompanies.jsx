import { useEffect, useState } from "react";
import { Plus, RefreshCw } from "lucide-react";
import { api } from "../../api";

const EMPTY_FORM = {
  name: "",
  phone: "",
  address: "",
  owner_email: "",
  owner_password: "",
  owner_first_name: "",
  owner_last_name: "",
  owner_phone: "",
};

function NewCompanyModal({ onClose, onCreated }) {
  const [form, setForm] = useState(EMPTY_FORM);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const set = (field) => (e) => setForm({ ...form, [field]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api("/companies/", { method: "POST", body: form });
      onCreated();
    } catch (e2) {
      setError(e2.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-lg flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h3 className="text-lg font-semibold">Yangi kompaniya</h3>

        <div className="flex flex-col gap-3">
          <label className="flex flex-col gap-1 text-sm">
            Kompaniya nomi
            <input className="input" required value={form.name} onChange={set("name")} />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            Telefon
            <input className="input" value={form.phone} onChange={set("phone")} />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            Manzil
            <input className="input" value={form.address} onChange={set("address")} />
          </label>
        </div>

        <hr style={{ borderColor: "var(--border)" }} />
        <p className="text-sm font-medium">Kompaniya admini (egasi)</p>

        <div className="flex flex-col gap-3">
          <label className="flex flex-col gap-1 text-sm">
            Email
            <input
              className="input"
              type="email"
              required
              value={form.owner_email}
              onChange={set("owner_email")}
            />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            Parol
            <input
              className="input"
              type="password"
              required
              minLength={6}
              value={form.owner_password}
              onChange={set("owner_password")}
            />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="flex flex-col gap-1 text-sm">
              Ism
              <input className="input" value={form.owner_first_name} onChange={set("owner_first_name")} />
            </label>
            <label className="flex flex-col gap-1 text-sm">
              Familiya
              <input className="input" value={form.owner_last_name} onChange={set("owner_last_name")} />
            </label>
          </div>
          <label className="flex flex-col gap-1 text-sm">
            Telefon (admin)
            <input className="input" value={form.owner_phone} onChange={set("owner_phone")} />
          </label>
        </div>

        {error && <div className="error">{error}</div>}

        <div className="flex justify-end gap-2">
          <button type="button" className="btn-ghost" onClick={onClose}>
            Bekor qilish
          </button>
          <button type="submit" className="btn" disabled={busy}>
            {busy ? "Yaratilmoqda…" : "Yaratish"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function AdminCompanies() {
  const [companies, setCompanies] = useState([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState("");
  const [showNew, setShowNew] = useState(false);

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
        <button className="btn !px-3 !py-1.5 text-xs" onClick={() => setShowNew(true)}>
          <Plus size={14} /> Yangi kompaniya
        </button>
      </div>
      {error && <div className="error">{error}</div>}
      {showNew && (
        <NewCompanyModal
          onClose={() => setShowNew(false)}
          onCreated={() => {
            setShowNew(false);
            load();
          }}
        />
      )}
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
