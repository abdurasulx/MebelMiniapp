import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { PORTAL } from "../portal";

export default function Register() {
  const { register } = useAuth();
  const nav = useNavigate();
  const [form, setForm] = useState({
    email: "",
    password: "",
    first_name: "",
    phone: "",
    role: PORTAL === "firma" ? "company_owner" : "customer",
  });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await register(form);
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
          <h1 className="text-lg font-bold">Ro'yxatdan o'tish</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            {PORTAL === "firma" ? "Mebel kompaniyangizni platformaga qo'shing" : "Bir daqiqada hisob yarating"}
          </p>
        </div>
        {PORTAL === "market" && (
          <div>
            <label className="label">Kim sifatida?</label>
            <select className="input" value={form.role} onChange={set("role")}>
              <option value="customer">Mijoz</option>
              <option value="company_owner">Mebel kompaniyasi</option>
            </select>
          </div>
        )}
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Ism</label>
            <input className="input" value={form.first_name} onChange={set("first_name")} />
          </div>
          <div>
            <label className="label">Telefon</label>
            <input className="input" value={form.phone} onChange={set("phone")} placeholder="+998…" />
          </div>
        </div>
        <div>
          <label className="label">Email</label>
          <input className="input" type="email" value={form.email} onChange={set("email")} required />
        </div>
        <div>
          <label className="label">Parol (kamida 8 belgi)</label>
          <input className="input" type="password" value={form.password} onChange={set("password")} required />
        </div>
        {error && <div className="error">{error}</div>}
        <button className="btn btn-brand w-full" type="submit" disabled={busy}>
          {busy ? "Yaratilmoqda…" : "Ro'yxatdan o'tish"}
        </button>
      </form>
    </div>
  );
}
