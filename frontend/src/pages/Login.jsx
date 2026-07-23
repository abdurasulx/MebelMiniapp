import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { PORTAL, portalForUser, portalURLFor } from "../portal";
import { getTokens } from "../api";

const TITLES = {
  market: "Xush kelibsiz",
  admin: "Platforma boshqaruviga kirish",
  firma: "Firma kabinetiga kirish",
};

export default function Login() {
  const { login } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const me = await login(email, password);

      // Hisob boshqa portalga tegishli bo'lsa (masalan firma egasi market'dan
      // kirsa), avtomatik o'sha subdomenga o'tkaziladi — token URL orqali
      // "uzatiladi" (main.jsx shuni o'qib oladi).
      const target = portalForUser(me);
      if (target !== PORTAL) {
        const base = portalURLFor(target);
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
      <form className="card flex w-full max-w-sm flex-col gap-4 p-8" onSubmit={submit}>
        <div className="text-center">
          <Sofa className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">{TITLES[PORTAL]}</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Hisobingizga kiring
          </p>
        </div>
        <div>
          <label className="label">Email</label>
          <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus />
        </div>
        <div>
          <label className="label">Parol</label>
          <input className="input" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </div>
        {error && <div className="error">{error}</div>}
        <button className="btn btn-brand w-full" type="submit" disabled={busy}>
          {busy ? "Kirilmoqda…" : "Kirish"}
        </button>
      </form>
    </div>
  );
}
