import { useEffect, useRef, useState } from "react";
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

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

export default function Login() {
  const { login, loginWithGoogle } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const googleButtonRef = useRef(null);

  // Login qilingandan keyin — hisob boshqa portalga tegishli bo'lsa
  // (masalan firma egasi market'dan kirsa), avtomatik o'sha subdomenga
  // o'tkaziladi, token URL orqali "uzatiladi" (main.jsx shuni o'qib oladi).
  const afterLogin = (me) => {
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
  };

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      afterLogin(await login(email, password));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const handleGoogleCredential = async (response) => {
    setError("");
    setBusy(true);
    try {
      afterLogin(await loginWithGoogle(response.credential));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  // Google Identity Services skriptini shu sahifada, kerak bo'lganda
  // yuklaymiz (index.html'ga qo'shmaymiz — faqat Login sahifasiga kerak).
  // `VITE_GOOGLE_CLIENT_ID` hali sozlanmagan bo'lsa (Google Cloud Console
  // ma'lumotlari kelmagan bo'lsa), tugma shunchaki ko'rsatilmaydi.
  useEffect(() => {
    if (!GOOGLE_CLIENT_ID || !googleButtonRef.current) return;

    const renderButton = () => {
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: handleGoogleCredential,
      });
      window.google.accounts.id.renderButton(googleButtonRef.current, {
        theme: "outline",
        size: "large",
        width: 320,
        text: "continue_with",
      });
    };

    if (window.google?.accounts?.id) {
      renderButton();
      return;
    }
    const scriptId = "google-identity-services";
    let script = document.getElementById(scriptId);
    if (!script) {
      script = document.createElement("script");
      script.id = scriptId;
      script.src = "https://accounts.google.com/gsi/client";
      script.async = true;
      script.defer = true;
      document.body.appendChild(script);
    }
    script.addEventListener("load", renderButton);
    return () => script.removeEventListener("load", renderButton);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
        {GOOGLE_CLIENT_ID && (
          <>
            <div className="flex items-center gap-3 text-xs" style={{ color: "var(--muted)" }}>
              <div className="h-px flex-1" style={{ background: "var(--border)" }} />
              yoki
              <div className="h-px flex-1" style={{ background: "var(--border)" }} />
            </div>
            <div ref={googleButtonRef} className="flex justify-center" />
          </>
        )}
      </form>
    </div>
  );
}
