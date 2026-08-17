import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { api, getTokens } from "../api";
import { portalURLFor } from "../portal";

// Google/Telegram orqali yangi hisob ochilgandan keyingi yakuniy qadam —
// App.jsx'dagi top-level guard foydalanuvchini shu yerga yo'naltiradi
// (qarang `registration_completed`). Bir marta to'ldiriladi.
export default function CompleteRegistration() {
  const { refreshUser } = useAuth();
  const nav = useNavigate();
  const [form, setForm] = useState({
    role: "customer",
    first_name: "",
    last_name: "",
    phone: "",
    company_name: "",
  });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api("/users/me/complete-registration/", { method: "POST", body: form });
      const me = await refreshUser();
      if (me.role === "company_owner") {
        const base = portalURLFor("firma");
        if (base) {
          const { access, refresh } = getTokens();
          window.location.href = `${base}/?access=${encodeURIComponent(access)}&refresh=${encodeURIComponent(refresh)}`;
          return;
        }
      }
      nav("/");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-[70vh] items-center justify-center p-4">
      <form className="card flex w-full max-w-md flex-col gap-4 p-8" onSubmit={submit}>
        <div className="text-center">
          <Sofa className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">Ro'yxatdan o'tishni yakunlang</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Bir necha ma'lumot — va tayyor
          </p>
        </div>
        <div>
          <label className="label">Kim sifatida?</label>
          <select className="input" value={form.role} onChange={set("role")}>
            <option value="customer">Mijoz</option>
            <option value="company_owner">Mebel kompaniyasi</option>
          </select>
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Ism</label>
            <input className="input" value={form.first_name} onChange={set("first_name")} required autoFocus />
          </div>
          <div>
            <label className="label">Familiya</label>
            <input className="input" value={form.last_name} onChange={set("last_name")} />
          </div>
        </div>
        <div>
          <label className="label">Telefon</label>
          <input className="input" value={form.phone} onChange={set("phone")} placeholder="+998…" />
        </div>
        {form.role === "company_owner" && (
          <div>
            <label className="label">Kompaniya nomi</label>
            <input className="input" value={form.company_name} onChange={set("company_name")} required />
          </div>
        )}
        {error && <div className="error">{error}</div>}
        <button className="btn btn-brand w-full" type="submit" disabled={busy}>
          {busy ? "Saqlanmoqda…" : "Yakunlash"}
        </button>
      </form>
    </div>
  );
}
