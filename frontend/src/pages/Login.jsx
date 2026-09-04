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
  if (PORTAL === "firma") return <FirmaLogin />;
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

// Google/Telegram tugmalari — market va firma login sahifalarida bir xil.
// Google: to'liq-sahifa backend redirect (`?portal=` orqali qaysi subdomendan
// boshlanganini bildiradi — callback aynan shu subdomenga qaytaradi, qarang
// backend GoogleLoginStartView/GoogleLoginCallbackView). Telegram esa
// to'g'ridan-to'g'ri shu sahifadagi JS orqali ishlaydi (session polling),
// hech qanday backend redirectga bog'liq emas — shuning uchun ikkalasi ham
// firma sahifasida to'g'ridan-to'g'ri ishlatilishi mumkin, market'ga
// chiqib-kirib o'tirishning hojati yo'q.
function AuthButtons({ portal }) {
  const { loginWithTokens } = useAuth();
  const afterLogin = useAfterLogin();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [botUsername, setBotUsername] = useState(null);
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

  // Telegram: sessiya yaratamiz, botni deep-link bilan ochamiz, so'ng
  // foydalanuvchi botda "/start" bosishini kutib, natijani so'rab turamiz
  // (polling, 800ms — bot webhook'i sessiyani darhol to'ldiradi, tez-tez
  // so'rash sezilarli kechikishni oldini oladi) — bot webhook'i shu
  // sessiyani orqa fonda to'ldiradi.
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
      const { session_id } = await api("/auth/telegram/session/", {
        method: "POST",
        body: { client: "web" },
      });
      tgWindow.location.href = `https://t.me/${botUsername}?start=${session_id}`;

      const checkOnce = async () => {
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
      };
      pollRef.current = setInterval(checkOnce, 800);

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
    <>
      {error && <div className="error">{error}</div>}
      {GOOGLE_CLIENT_ID && (
        <a
          className="btn w-full flex items-center justify-center gap-2"
          style={{ background: "#fff", color: "#1f1f1f", border: "1px solid #dadce0" }}
          href={`${API_BASE}/auth/google/start/?portal=${portal}`}
        >
          <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
            <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.57 2.7-3.87 2.7-6.62z" />
            <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.96v2.33A9 9 0 0 0 9 18z" />
            <path fill="#FBBC05" d="M3.95 10.7A5.4 5.4 0 0 1 3.67 9c0-.59.1-1.17.28-1.7V4.97H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.03l2.99-2.33z" />
            <path fill="#EA4335" d="M9 3.58c1.32 0 2.51.46 3.44 1.35l2.58-2.58A8.6 8.6 0 0 0 9 0 9 9 0 0 0 .96 4.97l2.99 2.33C4.66 5.17 6.65 3.58 9 3.58z" />
          </svg>
          Google orqali kirish
        </a>
      )}
      {botUsername && (
        <button
          type="button"
          className="btn w-full flex items-center justify-center gap-2"
          style={{ background: "#29B6F6", color: "#fff" }}
          onClick={startTelegramLogin}
          disabled={busy}
        >
          {!busy && (
            <svg width="18" height="18" viewBox="0 0 240 240" aria-hidden="true">
              <path
                fill="#fff"
                d="M53.9 122.4l100.6-38.8c4.7-1.9 8.8 1.1 7.3 8.2l-.1.1-17.1 80.6c-1.3 5.7-4.7 7.1-9.5 4.4l-26.2-19.3-12.6 12.2c-1.4 1.4-2.6 2.6-5.3 2.6l1.9-26.9 49-44.3c2.1-1.9-.5-2.9-3.3-1l-60.6 38.2-26.1-8.2c-5.7-1.8-5.8-5.7 1.2-8.5z"
              />
            </svg>
          )}
          {busy ? "Kutilmoqda…" : "Telegram orqali kirish"}
        </button>
      )}
    </>
  );
}

// Firma — endi o'z login sahifasiga ega: Google callback subdomen-ogohli
// (`?portal=firma`), Telegram esa har doim shu sahifada to'g'ridan-to'g'ri
// ishlagan. Hisobi yo'q bo'lsa avtomatik yaratiladi (market bilan bir xil).
// Email+parol ham qo'shildi — lekin FAQAT firma egasi uchun (xodimlar hamon
// Google/Telegram orqali kiradi, qarang backend FirmaTokenObtainPairSerializer).
function FirmaLogin() {
  const { loginFirma } = useAuth();
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
      afterLogin(await loginFirma(email, password));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex min-h-[70vh] items-center justify-center p-4">
      <div className="card flex w-full max-w-sm flex-col gap-4 p-8">
        <div className="text-center">
          <Sofa className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">Firma kabinetiga kirish</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Firma egasi — email/parol, xodimlar — Google yoki Telegram bilan kiring.
          </p>
        </div>
        <form className="flex flex-col gap-4" onSubmit={submit}>
          <div>
            <label className="label">Email</label>
            <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
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
        <div className="flex items-center gap-2 text-xs" style={{ color: "var(--muted)" }}>
          <div className="h-px flex-1" style={{ background: "var(--border)" }} />
          yoki
          <div className="h-px flex-1" style={{ background: "var(--border)" }} />
        </div>
        <AuthButtons portal="firma" />
      </div>
    </div>
  );
}

// Market — yagona login/ro'yxatdan o'tish nuqtasi: Google va Telegram.
// Email/parol yo'q (faqat admin uchun qoldirilgan).
function MarketLogin() {
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
        <AuthButtons portal="market" />
      </div>
    </div>
  );
}
