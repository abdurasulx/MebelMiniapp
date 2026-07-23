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
  const doFetch = async (access) => {
    const headers = {};
    if (access) headers.Authorization = `Bearer ${access}`;
    if (body && !isForm) headers["Content-Type"] = "application/json";
    return fetch(`${BASE}${path}`, {
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
    const msg =
      data?.detail ||
      (data && typeof data === "object"
        ? Object.entries(data)
            .map(([k, v]) => `${k}: ${Array.isArray(v) ? v.join(", ") : v}`)
            .join("; ")
        : "Xatolik yuz berdi");
    const err = new Error(msg);
    err.body = data;
    throw err;
  }
  return data;
}
