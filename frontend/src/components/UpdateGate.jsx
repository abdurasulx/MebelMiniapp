import { useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";
import { fetchAppPolicy } from "../api";
import { useLocale } from "../locale";

const isForced = (p) =>
  p && (p.status === "BLOCKED" || (p.status === "UPDATE_REQUIRED" && p.force_update));

/// Veb uchun versiya darvozasi: majburiy bo'lsa — to'liq ekranli to'siq
/// (faqat "Yangilash" = sahifani qayta yuklash), ixtiyoriy bo'lsa — yopish
/// mumkin bo'lgan banner. Backend 426 qaytarsa ham (`app:update-required`)
/// darhol to'siq ochiladi. Tarmoq xatosida hech narsa bloklanmaydi.
export default function UpdateGate({ children }) {
  const { t } = useLocale();
  const [policy, setPolicy] = useState(null);
  const [dismissed, setDismissed] = useState(false);
  const [checking, setChecking] = useState(false);

  const check = async () => {
    setChecking(true);
    const p = await fetchAppPolicy();
    setChecking(false);
    if (p) setPolicy(p);
  };

  useEffect(() => {
    check();
    const onRequired = (e) => setPolicy(e.detail);
    window.addEventListener("app:update-required", onRequired);
    return () => window.removeEventListener("app:update-required", onRequired);
  }, []);

  const reload = () => window.location.reload();

  if (isForced(policy)) {
    return (
      <div className="fixed inset-0 z-[100] flex flex-col items-center justify-center gap-4 p-8 text-center" style={{ background: "var(--bg)" }}>
        <RefreshCw size={44} style={{ color: "var(--brand-cta-bg)" }} />
        <h1 className="text-xl font-bold">{t("update_title")}</h1>
        <p className="max-w-sm text-sm" style={{ color: "var(--muted)" }}>{policy.message || t("update_forced_message")}</p>
        {policy.latest_version && <p className="text-xs" style={{ color: "var(--muted)" }}>v{policy.latest_version}</p>}
        <div className="flex gap-2">
          <button className="btn btn-brand" onClick={reload}>{t("update_button")}</button>
          <button className="btn-ghost" onClick={check} disabled={checking}>{t("update_retry")}</button>
        </div>
      </div>
    );
  }

  return (
    <>
      {children}
      {policy?.update_available && !dismissed && (
        <div
          className="fixed bottom-4 left-1/2 z-[90] flex w-[calc(100%-2rem)] max-w-md -translate-x-1/2 items-center gap-3 rounded-2xl px-4 py-3 shadow-lg"
          style={{ background: "var(--card)", border: "1px solid var(--border)" }}
        >
          <RefreshCw size={18} style={{ color: "var(--brand-cta-bg)" }} />
          <div className="min-w-0 flex-1 text-sm">
            <div className="font-semibold">{t("update_available_title")}</div>
            {policy.latest_version && <div className="text-xs" style={{ color: "var(--muted)" }}>v{policy.latest_version}</div>}
          </div>
          <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => setDismissed(true)}>{t("update_later")}</button>
          <button className="btn btn-brand !px-3 !py-1.5 text-xs" onClick={reload}>{t("update_button")}</button>
        </div>
      )}
    </>
  );
}
