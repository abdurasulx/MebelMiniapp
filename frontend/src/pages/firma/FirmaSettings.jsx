import { useEffect, useState } from "react";
import { api } from "../../api";
import { useAuth } from "../../auth";

export default function FirmaSettings() {
  const { user } = useAuth();
  const [company, setCompany] = useState(null);
  const [loaded, setLoaded] = useState(false);
  const [form, setForm] = useState({ name: "", phone: "", address: "", description: "" });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");

  useEffect(() => {
    api("/users/me/")
      .then((me) =>
        me.company ? api(`/companies/${me.company.slug}/`) : null
      )
      .then((c) => {
        if (c) {
          setCompany(c);
          setForm({
            name: c.name || "",
            phone: c.phone || "",
            address: c.address || "",
            description: c.description || "",
          });
        }
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
  }, []);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const isOwner = user?.role === "company_owner";

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      if (company) {
        await api(`/companies/${company.slug}/`, { method: "PATCH", body: form });
        setMsg("Saqlandi");
      } else {
        await api("/companies/", { method: "POST", body: form });
        setMsg("Kompaniya yaratildi");
        window.location.reload();
      }
      setTimeout(() => setMsg(""), 3000);
    } catch (err) {
      setError(err.message);
    }
  };

  if (!loaded) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <form className="card mx-auto flex w-full max-w-xl flex-col gap-4 p-6" onSubmit={submit}>
      <h2 className="text-base font-semibold">
        {company ? "Kompaniya ma'lumotlari" : "Kompaniyangizni yarating"}
      </h2>
      {!isOwner && (
        <div className="error">Faqat kompaniya egasi ma'lumotlarni o'zgartira oladi.</div>
      )}
      <div>
        <label className="label">Nomi *</label>
        <input className="input" value={form.name} onChange={set("name")} required disabled={!isOwner} />
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label className="label">Telefon</label>
          <input className="input" value={form.phone} onChange={set("phone")} placeholder="+998…" disabled={!isOwner} />
        </div>
        <div>
          <label className="label">Manzil</label>
          <input className="input" value={form.address} onChange={set("address")} disabled={!isOwner} />
        </div>
      </div>
      <div>
        <label className="label">Tavsif</label>
        <textarea className="input" rows={3} value={form.description} onChange={set("description")} disabled={!isOwner} />
      </div>
      {error && <div className="error">{error}</div>}
      {msg && <span className="badge">{msg}</span>}
      {isOwner && (
        <button className="btn self-start" type="submit">
          {company ? "Saqlash" : "Yaratish"}
        </button>
      )}
    </form>
  );
}
