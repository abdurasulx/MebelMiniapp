import { useEffect, useRef, useState } from "react";
import { CheckCircle2, AlertTriangle, PhoneCall } from "lucide-react";
import { useAuth } from "../auth";
import { api } from "../api";
import PhoneVerifyModal from "../components/PhoneVerifyModal";

const API_BASE = import.meta.env.VITE_API_URL || "http://127.0.0.1:8000/api/v1";

// Google — hisob bog'lash `?lt=` (link_token) orqali to'liq-sahifa
// redirect bilan ishlaydi (Login.jsx'dagi kirish oqimi bilan bir xil
// sabab: to'liq-sahifa navigatsiya Authorization header'ini olib
// ketolmaydi — qarang backend GoogleLinkStartView docstring).
function GoogleLinkRow({ hasGoogle }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const startLink = async () => {
    setError("");
    setBusy(true);
    try {
      const { link_token } = await api("/users/me/google/link/prepare/", { method: "POST" });
      window.location.href = `${API_BASE}/auth/google/link/start/?lt=${encodeURIComponent(link_token)}`;
    } catch (err) {
      setError(err.message);
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true">
            <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.57 2.7-3.87 2.7-6.62z" />
            <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.96v2.33A9 9 0 0 0 9 18z" />
            <path fill="#FBBC05" d="M3.95 10.7A5.4 5.4 0 0 1 3.67 9c0-.59.1-1.17.28-1.7V4.97H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.03l2.99-2.33z" />
            <path fill="#EA4335" d="M9 3.58c1.32 0 2.51.46 3.44 1.35l2.58-2.58A8.6 8.6 0 0 0 9 0 9 9 0 0 0 .96 4.97l2.99 2.33C4.66 5.17 6.65 3.58 9 3.58z" />
          </svg>
          <span className="text-sm font-medium">Google</span>
        </div>
        {hasGoogle ? (
          <span className="flex items-center gap-1 text-xs font-medium" style={{ color: "var(--success, #16a34a)" }}>
            <CheckCircle2 size={14} /> Bog'langan
          </span>
        ) : (
          <button className="btn" onClick={startLink} disabled={busy}>
            {busy ? "Yo'naltirilmoqda…" : "Bog'lash"}
          </button>
        )}
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

// Telegram — sessiya yaratib deep-link ochamiz, so'ng poll qilamiz
// (Login.jsx'dagi kirish oqimi bilan bir xil naqsh, faqat authenticated
// "link" endpointlariga so'rov yuboradi — login emas, bog'lash).
function TelegramLinkRow({ hasTelegram, onLinked }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [botUsername, setBotUsername] = useState(null);
  const pollRef = useRef(null);

  useEffect(() => {
    api("/auth/telegram/bot-info/")
      .then((d) => setBotUsername(d.username))
      .catch(() => setBotUsername(null));
    return () => clearInterval(pollRef.current);
  }, []);

  const startLink = async () => {
    setError("");
    setBusy(true);
    const tgWindow = window.open("about:blank", "_blank");
    if (!tgWindow) {
      setError("Brauzer popup oynani bloklab qo'ydi. Popup blokerni o'chirib, qayta urining.");
      setBusy(false);
      return;
    }
    try {
      const { session_id } = await api("/users/me/telegram/link/session/", { method: "POST" });
      tgWindow.location.href = `https://t.me/${botUsername}?start=${session_id}`;

      pollRef.current = setInterval(async () => {
        try {
          const data = await api(`/users/me/telegram/link/session/${session_id}/`);
          if (data.status === "done") {
            clearInterval(pollRef.current);
            pollRef.current = null;
            setBusy(false);
            onLinked();
          }
        } catch (err) {
          clearInterval(pollRef.current);
          pollRef.current = null;
          setBusy(false);
          setError(err.message);
        }
      }, 2000);

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
    <div className="flex flex-col gap-1">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <svg width="18" height="18" viewBox="0 0 240 240" aria-hidden="true">
            <circle cx="120" cy="120" r="120" fill="#29B6F6" />
            <path
              fill="#fff"
              d="M53.9 122.4l100.6-38.8c4.7-1.9 8.8 1.1 7.3 8.2l-.1.1-17.1 80.6c-1.3 5.7-4.7 7.1-9.5 4.4l-26.2-19.3-12.6 12.2c-1.4 1.4-2.6 2.6-5.3 2.6l1.9-26.9 49-44.3c2.1-1.9-.5-2.9-3.3-1l-60.6 38.2-26.1-8.2c-5.7-1.8-5.8-5.7 1.2-8.5z"
            />
          </svg>
          <span className="text-sm font-medium">Telegram</span>
        </div>
        {hasTelegram ? (
          <span className="flex items-center gap-1 text-xs font-medium" style={{ color: "var(--success, #16a34a)" }}>
            <CheckCircle2 size={14} /> Bog'langan
          </span>
        ) : (
          <button className="btn" onClick={startLink} disabled={busy || !botUsername}>
            {busy ? "Kutilmoqda…" : "Bog'lash"}
          </button>
        )}
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

export default function Profile() {
  const { user, refreshUser } = useAuth();
  const [notice, setNotice] = useState("");
  const [noticeError, setNoticeError] = useState("");
  const [showPhoneVerify, setShowPhoneVerify] = useState(false);

  // Google bog'lash callback'i shu sahifaga `?linked=google` yoki
  // `?link_error=...` bilan qaytaradi (qarang backend
  // GoogleLinkCallbackView) — shu yerda ko'rsatib, URL tozalanadi.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const linked = params.get("linked");
    const err = params.get("link_error");
    if (linked === "google") {
      setNotice("Google hisobi muvaffaqiyatli bog'landi");
      refreshUser();
    } else if (err) {
      setNoticeError(err);
    }
    if (linked || err) {
      params.delete("linked");
      params.delete("link_error");
      const qs = params.toString();
      window.history.replaceState({}, "", window.location.pathname + (qs ? `?${qs}` : ""));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!user) return null;

  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">Profil</h1>

      {notice && <div className="mb-4 rounded-lg bg-green-50 p-3 text-sm text-green-700">{notice}</div>}
      {noticeError && <div className="error mb-4">{noticeError}</div>}

      <div className="card mb-4 flex flex-col gap-3 p-5">
        <h2 className="text-base font-semibold">Tasdiqlash holati</h2>
        <div className="flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <PhoneCall size={16} style={{ color: "var(--muted)" }} />
            <span className="text-sm">{user.phone || "Telefon raqam kiritilmagan"}</span>
          </div>
          {user.phone_verified ? (
            <span className="flex items-center gap-1 text-xs font-medium" style={{ color: "var(--success, #16a34a)" }}>
              <CheckCircle2 size={14} /> Tasdiqlangan
            </span>
          ) : (
            <button className="btn btn-brand" onClick={() => setShowPhoneVerify(true)}>
              Tasdiqlash
            </button>
          )}
        </div>
        {!user.phone_verified && (
          <p className="flex items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
            <AlertTriangle size={12} /> Tasdiqlanmagan profil bilan buyurtma bera olmaysiz.
          </p>
        )}
      </div>

      <div className="card flex flex-col gap-4 p-5">
        <h2 className="text-base font-semibold">Bog'langan hisoblar</h2>
        <GoogleLinkRow hasGoogle={user.has_google} />
        <TelegramLinkRow hasTelegram={user.has_telegram} onLinked={refreshUser} />
      </div>

      {showPhoneVerify && (
        <PhoneVerifyModal
          initialPhone={user.phone}
          onVerified={() => {
            setShowPhoneVerify(false);
            refreshUser();
          }}
          onClose={() => setShowPhoneVerify(false)}
        />
      )}
    </div>
  );
}
