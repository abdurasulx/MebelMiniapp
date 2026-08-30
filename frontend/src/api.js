const BASE = import.meta.env.VITE_API_URL || "http://127.0.0.1:8000/api/v1";

export function getTokens() {
  try {
    return JSON.parse(localStorage.getItem("tokens")) || null;
  } catch {
    return null;
  }
}

export function setTokens(tokens) {
  if (tokens) localStorage.setItem("tokens", JSON.stringify(tokens));
  else localStorage.removeItem("tokens");
}

async function refreshAccess() {
  const tokens = getTokens();
  if (!tokens?.refresh) return null;
  const res = await fetch(`${BASE}/auth/token/refresh/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh: tokens.refresh }),
  });
  if (!res.ok) {
    setTokens(null);
    return null;
  }
  const data = await res.json();
  setTokens(data);
  return data.access;
}

export async function api(path, { method = "GET", body, isForm = false } = {}) {
  // DRF pagination'ning `next`/`previous` maydonlari to'liq absolyut URL
  // qaytaradi (masalan "http://host/api/v1/products/?page=2") — shuni
  // to'g'ridan-to'g'ri shu yerga uzatish mumkin bo'lishi uchun, BASE prefiksi
  // faqat path hali to'liq URL bo'lmagan holatdagina qo'shiladi.
  const url = /^https?:\/\//.test(path) ? path : `${BASE}${path}`;
  const doFetch = async (access) => {
    const headers = {};
    if (access) headers.Authorization = `Bearer ${access}`;
    if (body && !isForm) headers["Content-Type"] = "application/json";
    return fetch(url, {
      method,
      headers,
      body: body ? (isForm ? body : JSON.stringify(body)) : undefined,
    });
  };

  let res = await doFetch(getTokens()?.access);
  if (res.status === 401 && getTokens()?.refresh) {
    const access = await refreshAccess();
    if (access) res = await doFetch(access);
  }
  if (res.status === 204) return null;
  const data = await res.json().catch(() => null);
  if (!res.ok) {
    // DRF qo'lda `ValidationError("xabar")` ko'tarilganda javob tanasi
    // to'g'ridan-to'g'ri `["xabar"]` bo'ladi ("detail" kaliti YO'Q — DRF
    // `exc.detail` ro'yxat bo'lganda uni o'rab qo'ymaydi) — buni hisobga
    // olmasa "0: xabar" kabi tushunarsiz matn ko'rsatilib qolardi.
    const msg =
      (Array.isArray(data) && data.length ? data[0] : null) ||
      data?.detail ||
      (data && typeof data === "object"
        ? Object.entries(data)
            .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(", ") : v}`)
            .join("; ")
        : "Xatolik yuz berdi");
    const err = new Error(msg);
    err.body = data;
    err.status = res.status;
    throw err;
  }
  return data;
}
