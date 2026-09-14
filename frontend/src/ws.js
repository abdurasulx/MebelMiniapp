import { getTokens, refreshAccess } from "./api";

/// JWT'ning `exp` da'vosini (payload'dan, imzoni tekshirmasdan) o'qib,
/// muddati tugagan/tugashiga yaqin (10s qoldi) bo'lsa `true` qaytaradi.
/// Buzuq/formatsiz token ham "tugagan" deb hisoblanadi (xavfsizroq tomon).
function isTokenExpiring(token) {
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return !payload.exp || payload.exp * 1000 < Date.now() + 10000;
  } catch {
    return true;
  }
}

const API_BASE = import.meta.env.VITE_API_URL || "http://127.0.0.1:8000/api/v1";

function wsUrl() {
  const httpBase = API_BASE.replace(/\/api\/v1\/?$/, "");
  const wsBase = httpBase.replace(/^https/, "wss").replace(/^http/, "ws");
  const tokens = getTokens();
  return `${wsBase}/ws/notifications/?token=${encodeURIComponent(tokens?.access || "")}`;
}

/**
 * Bildirishnoma qo'ng'irog'i uchun — avval har 30s'da `/notifications/
 * unread_count/` so'ralardi, endi WebSocket orqali real vaqtda keladi
 * (qarang backend apps/notifications/consumers.py). Ulanish uzilsa
 * (tarmoq, token muddati va h.k.) eksponensial orqaga chekinish bilan
 * qayta ulanadi — token har safar `getTokens()`dan QAYTA o'qiladi, shunda
 * orada yangilangan bo'lsa ham eskirgan token bilan sinamaydi.
 *
 * `onMessage(data)` — har bir kelgan JSON xabar bilan chaqiriladi
 * (`{type: "unread_count", count}`). Qaytarilgan funksiya ulanishni
 * butunlay to'xtatadi (masalan logout bo'lganda chaqiriladi).
 */
export function connectNotificationSocket(onMessage) {
  if (!getTokens()?.access) return () => {};

  let ws = null;
  let stopped = false;
  let retryDelay = 1000;
  let retryTimer = null;

  async function connect() {
    if (stopped) return;
    let tokens = getTokens();
    if (!tokens?.access) return;

    // Sahifa uzoq vaqt ochiq turib, boshqa API so'rov bo'lmasa, access
    // tokeni muddati tugab qolgan bo'lishi mumkin — bu holda avvalgi
    // (eskirgan) qiymat bilan qayta-qayta ulanishga urinib, cheksiz 403
    // olinardi. Ulanishdan oldin tekshirib, kerak bo'lsa yangilaymiz.
    if (isTokenExpiring(tokens.access)) {
      await refreshAccess();
      tokens = getTokens();
      if (stopped || !tokens?.access) return;
    }

    ws = new WebSocket(wsUrl());
    ws.onopen = () => {
      retryDelay = 1000;
    };
    ws.onmessage = (event) => {
      try {
        onMessage(JSON.parse(event.data));
      } catch {
        // jim o'tkazamiz — buzuq xabar
      }
    };
    ws.onclose = () => {
      if (stopped) return;
      retryTimer = setTimeout(connect, retryDelay);
      retryDelay = Math.min(retryDelay * 2, 30000);
    };
    ws.onerror = () => ws?.close();
  }

  connect();

  return () => {
    stopped = true;
    if (retryTimer) clearTimeout(retryTimer);
    ws?.close();
  };
}
