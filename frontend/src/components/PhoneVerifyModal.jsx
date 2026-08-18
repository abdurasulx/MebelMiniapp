import { useState } from "react";
import { PhoneCall } from "lucide-react";
import { api } from "../api";

// Google/Telegram orqali kirgan-u hali telefonini tasdiqlamagan
// foydalanuvchi buyurtma berishga urinsa backend 403 qaytaradi (qarang
// OrderViewSet.perform_create) — shu oyna ochilib, SMS-kod bilan
// tasdiqlangach avtomatik qayta buyurtma yuboriladi (`onVerified`).
export default function PhoneVerifyModal({ initialPhone, onVerified, onClose }) {
  const [step, setStep] = useState("phone"); // "phone" | "code"
  const [phone, setPhone] = useState(initialPhone || "");
  const [code, setCode] = useState("");
  const [debugCode, setDebugCode] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const requestCode = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const resp = await api("/users/me/phone/request-otp/", {
        method: "POST",
        body: { phone },
      });
      setDebugCode(resp.debug_code || null);
      setStep("code");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const confirmCode = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api("/users/me/phone/verify-otp/", {
        method: "POST",
        body: { phone, code },
      });
      onVerified();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-sm flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={step === "phone" ? requestCode : confirmCode}
      >
        <div className="text-center">
          <PhoneCall className="mx-auto mb-1" size={26} style={{ color: "var(--secondary)" }} />
          <h2 className="text-base font-bold">Telefon raqamini tasdiqlang</h2>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Buyurtma berishdan oldin telefon raqamingizni SMS-kod bilan tasdiqlashingiz kerak.
          </p>
        </div>

        {step === "phone" ? (
          <div>
            <label className="label">Telefon</label>
            <input
              className="input"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+998…"
              required
              autoFocus
            />
          </div>
        ) : (
          <div>
            <label className="label">SMS-kod</label>
            <input
              className="input"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="000000"
              inputMode="numeric"
              maxLength={6}
              required
              autoFocus
            />
            {debugCode && (
              <p className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
                Dev rejim — kod: {debugCode}
              </p>
            )}
            <button
              type="button"
              className="mt-1 text-xs underline"
              style={{ color: "var(--muted)" }}
              onClick={() => setStep("phone")}
            >
              Raqamni o'zgartirish
            </button>
          </div>
        )}

        {error && <div className="error">{error}</div>}
        <button className="btn btn-brand w-full" type="submit" disabled={busy}>
          {busy ? "Yuborilmoqda…" : step === "phone" ? "Kod yuborish" : "Tasdiqlash"}
        </button>
      </form>
    </div>
  );
}
