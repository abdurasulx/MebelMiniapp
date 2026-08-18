import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { PORTAL, portalForUser, portalURLFor } from "../portal";
import { api, getTokens } from "../api";

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;
const API_BASE = import.meta.env.VITE_API_URL || "http://127.0.0.1:8000/api/v1";

// Login qilingandan keyin — hisob boshqa portalga tegishli bo'lsa (masalan
// firma egasi market'dan kirsa), avtomatik o'sha subdomenga o'tkaziladi,
// token URL orqali "uzatiladi" (main.jsx shuni o'qib oladi). Ro'yxatdan
// o'tish hali yakunlanmagan bo'lsa (yangi Google/Telegram hisob), portal
// tanlashdan oldin profil to'ldirish sahifasiga yuboriladi (qarang App.jsx
// top-level guard — bu yerda faqat market ichidagi navigatsiya kifoya).
function useAfterLogin() {
  const nav = useNavigate();
  return (me) => {
    if (!me.registration_completed) {
      nav("/complete-registration");
      return;
    }
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
}

export default function Login() {
  if (PORTAL === "admin") return <AdminLogin />;
  if (PORTAL === "firma") return <FirmaLoginRedirect />;
  return <MarketLogin />;
}

// Admin — yagona email/parol bilan kiradigan rol, o'zgarishsiz qoldi.
function AdminLogin() {
  const { login } = useAuth();
  const afterLogin = useAfterLogin();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

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

  return (
    <div className="flex min-h-[70vh] items-center justify-center p-4">
      <form className="card flex w-full max-w-sm flex-col gap-4 p-8" onSubmit={submit}>
        <div className="text-center">
          <Sofa className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">Platforma boshqaruviga kirish</h1>
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

// Firma — o'z login formasi yo'q: Google Console'ning "Authorized JavaScript
// origins"i wildcard subdomenlarni (*.qrbite.uz) qo'llab-quvvatlamaydi,
// shuning uchun Google/Telegram tugmalari faqat market'da. Firma egasi/
// xodimi ham market orqali kiradi — kirgach avtomatik shu subdomenga
// (token bilan) o'tkaziladi (qarang useAfterLogin).
function FirmaLoginRedirect() {
  const marketURL = portalURLFor("market");
  return (
    <div className="flex min-h-[70vh] items-center justify-center p-4">
      <div className="card flex w-full max-w-sm flex-col items-center gap-4 p-8 text-center">
        <Sofa size={30} style={{ color: "var(--secondary)" }} />
        <h1 className="text-lg font-bold">Firma kabinetiga kirish</h1>
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          Kirish uchun asosiy saytga o'ting — Google yoki Telegram bilan kirgach, firma
          kabinetiga avtomatik o'tkazilasiz.
        </p>
        <a className="btn btn-brand w-full" href={marketURL ? `${marketURL}/login` : "/login"}>
          Asosiy saytga o'tish
        </a>
      </div>
    </div>
  );
}

// Market — yagona login/ro'yxatdan o'tish nuqtasi: Google va Telegram.
// Email/parol yo'q (faqat admin uchun qoldirilgan).
function MarketLogin() {
  const { loginWithTokens } = useAuth();
  const afterLogin = useAfterLogin();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [botUsername, setBotUsername] = useState(null);
  const googleButtonRef = useRef(null);
  const pollRef = useRef(null);

  useEffect(() => {
    api("/auth/telegram/bot-info/")
      .then((d) => setBotUsername(d.username))
      .catch(() => setBotUsername(null));
    return () => clearInterval(pollRef.current);
  }, []);

  // Backend `auth/google/callback/` xatolik bilan qaytarsa (masalan token
  // yaroqsiz), `?error=`ni shu yerda ko'rsatamiz va URL'ni tozalaymiz.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const err = params.get("error");
    if (err) {
      setError(err);
      params.delete("error");
      const qs = params.toString();
      window.history.replaceState({}, "", window.location.pathname + (qs ? `?${qs}` : ""));
    }
  }, []);

  // Google Identity Services skriptini shu sahifada, kerak bo'lganda
  // yuklaymiz (index.html'ga qo'shmaymiz — faqat Login sahifasiga kerak).
  // `VITE_GOOGLE_CLIENT_ID` hali sozlanmagan bo'lsa, tugma ko'rsatilmaydi.
  //
  // MUHIM: popup rejimi (`ux_mode: 'popup'`, standart) Chrome'da uchinchi
  // tomon cookie bloklanganda `accounts.google.com/gsi/transform`
  // sahifasida abadiy osilib qolishi mumkin (hech qanday xato ko'rsatmasdan
  // — foydalanuvchiga "aylanaveradi" bo'lib ko'rinadi). Shuning uchun
  // REDIRECT rejimi ishlatiladi — Google ID token'ni to'g'ridan-to'g'ri
  // backendga (`login_uri`) to'liq sahifa POST orqali yuboradi, popup/
  // cookie muammosi umuman bo'lmaydi (qarang GoogleLoginCallbackView).
  useEffect(() => {
    if (!GOOGLE_CLIENT_ID || !googleButtonRef.current) return;

    const renderButton = () => {
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        ux_mode: "redirect",
        login_uri: `${API_BASE}/auth/google/callback/`,
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
  }, []);

  // Telegram: sessiya yaratamiz, botni deep-link bilan ochamiz, so'ng
  // foydalanuvchi botda "/start" bosishini kutib, natijani so'rab turamiz
  // (polling) — bot webhook'i shu sessiyani orqa fonda to'ldiradi.
  //
  // MUHIM: `window.open()` shu funksiyaning ENG BOSHIDA, hech qanday
  // `await`dan OLDIN chaqirilishi shart — aks holda (masalan tarmoq
  // so'rovidan keyin chaqirilsa) brauzer buni "foydalanuvchi bevosita
  // bosgani" deb hisoblamay, popup'ni jimgina bloklab qo'yadi (tugma
  // "Kutilmoqda…" holatida cheksiz osilib qoladi, hech qanday xato
  // ko'rsatilmaydi — aynan shu bug bo'lgan).
  const startTelegramLogin = async () => {
    setError("");
    setBusy(true);
    const tgWindow = window.open("about:blank", "_blank");
    if (!tgWindow) {
      setError("Brauzer popup oynani bloklab qo'ydi. Popup blokerni o'chirib, qayta urining.");
      setBusy(false);
      return;
    }
    try {
      const { session_id } = await api("/auth/telegram/session/", { method: "POST" });
      tgWindow.location.href = `https://t.me/${botUsername}?start=${session_id}`;

      pollRef.current = setInterval(async () => {
        try {
          const data = await api(`/auth/telegram/session/${session_id}/`);
          if (data.status === "done") {
            clearInterval(pollRef.current);
            pollRef.current = null;
            setBusy(false);
            afterLogin(await loginWithTokens({ access: data.access, refresh: data.refresh }));
          }
        } catch (err) {
          clearInterval(pollRef.current);
          pollRef.current = null;
          setBusy(false);
          setError(err.message);
        }
      }, 2000);

      // ~5 daqiqadan so'ng hali "done" bo'lmasa — abadiy kutib turishning
      // oldini olamiz (masalan foydalanuvchi botda /start bosmasa).
      setTimeout(() => {
        if (pollRef.current) {
          clearInterval(pollRef.current);
          pollRef.current = null;
          setBusy(false);
          setError("Kutish vaqti tugadi. Qayta urining.");
        }
      }, 5 * 60 * 1000);
    } catch (err) {
      tgWindow.close();
      setError(err.message);
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-[70vh] items-center justify-center p-4">
      <div className="card flex w-full max-w-sm flex-col gap-4 p-8">
        <div className="text-center">
          <Sofa className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">Xush kelibsiz</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Google yoki Telegram bilan kiring — hisobingiz yo'q bo'lsa, avtomatik yaratiladi.
          </p>
        </div>
        {error && <div className="error">{error}</div>}
        {GOOGLE_CLIENT_ID && <div ref={googleButtonRef} className="flex justify-center" />}
        {botUsername && (
          <button
            type="button"
            className="btn w-full"
            style={{ background: "#26A5E4", color: "#fff" }}
            onClick={startTelegramLogin}
            disabled={busy}
          >
            {busy ? "Kutilmoqda…" : "Telegram orqali kirish"}
          </button>
        )}
      </div>
    </div>
  );
}
