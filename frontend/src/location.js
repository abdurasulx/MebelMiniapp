import { useCallback, useEffect, useRef, useState } from "react";
import { safeLocal } from "./storage";

// Foydalanuvchi joylashuvi — mahsulotlar firma xizmat radiusiga qarab
// serverda filtrlanadi (backend apps/products/views.py), shuning uchun
// mahsulot so'rovlariga `lat`/`lng` qo'shiladi. Natija qisqa vaqt keshlanadi.
const TTL_MS = 5 * 60 * 1000;
let cache = null;
let inflight = null;

// Oxirgi muvaffaqiyatli aniqlangan joylashuv (30 kun): brauzer/OT vaqtincha aniqlay
// olmasa (masalan macOS Location Services bir lahza "rad" qaytarsa) mahsulotlar
// yo'qolib qolmasin.
const LAST_KEY = "vida.lastCoords";
const LAST_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

function readLast() {
  try {
    const v = JSON.parse(safeLocal.getItem(LAST_KEY) || "null");
    if (v && Number.isFinite(v.lat) && Number.isFinite(v.lng) && Date.now() - v.t < LAST_MAX_AGE_MS) return v;
  } catch {
    /* e'tiborsiz */
  }
  return null;
}

async function permissionGranted() {
  try {
    const p = await navigator.permissions?.query({ name: "geolocation" });
    return p?.state === "granted";
  } catch {
    return false;
  }
}

function readCache() {
  return cache && Date.now() - cache.t < TTL_MS ? cache : null;
}

/** -> { status: "granted", lat, lng } | { status: "denied" | "unavailable" | "unsupported" } */
export function requestCoords() {
  const c = readCache();
  if (c) return Promise.resolve({ status: "granted", lat: c.lat, lng: c.lng });
  if (!("geolocation" in navigator)) return Promise.resolve({ status: "unsupported" });
  if (inflight) return inflight;
  inflight = new Promise((resolve) => {
    // Birinchi aniqlash (ayniqsa macOS/Wi-Fi bilan) 10 soniyadan ko'proq
    // olishi mumkin — "timeout"/"unavailable" ruxsat rad etilgani emas,
    // shuning uchun ruxsat kartasini ko'rsatishdan oldin bir marta
    // uzoqroq kutib qayta urinib ko'ramiz. Faqat code 1 (denied) darhol qaytadi.
    const attempt = (timeout, retriesLeft) =>
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          cache = { lat: pos.coords.latitude, lng: pos.coords.longitude, t: Date.now() };
          safeLocal.setItem(LAST_KEY, JSON.stringify(cache));
          resolve({ status: "granted", lat: cache.lat, lng: cache.lng });
        },
        async (err) => {
          const last = readLast();
          const fallback = () => resolve({ status: "granted", lat: last.lat, lng: last.lng, stale: true });
          if (err.code === 1) {
            // Brauzerda sayt uchun ruxsat berilgan, lekin OT aniqlay olmayapti — oxirgi joylashuv.
            if (last && (await permissionGranted())) return fallback();
            return resolve({ status: "denied" });
          }
          if (retriesLeft > 0) return attempt(20000, retriesLeft - 1);
          if (last) return fallback();
          resolve({ status: "unavailable" });
        },
        { timeout, maximumAge: TTL_MS },
      );
    attempt(10000, 1);
  }).finally(() => {
    inflight = null;
  });
  return inflight;
}

/** "?lat=..&lng=.." (yoki bo'sh) — `prefix` ("?" yoki "&") bilan. */
export function coordsParams(coords, prefix = "?") {
  return coords?.status === "granted" ? `${prefix}lat=${coords.lat}&lng=${coords.lng}` : "";
}

export function useGeolocation() {
  const [state, setState] = useState(() => {
    const c = readCache();
    return c ? { status: "granted", lat: c.lat, lng: c.lng } : { status: "loading" };
  });

  const retry = useCallback(() => {
    setState({ status: "loading" });
    requestCoords().then(setState);
  }, []);

  useEffect(() => {
    if (state.status === "loading") requestCoords().then(setState);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Ruxsat allaqachon berilgan bo'lsa (yoki keyin berilsa) — foydalanuvchi
  // hech narsa bosmasdan avtomatik qayta aniqlanadi.
  const status = state.status;
  const autoTried = useRef(false);
  useEffect(() => {
    let perm;
    let alive = true;
    const recheck = () => {
      if (alive && status !== "granted" && status !== "loading") retry();
    };
    navigator.permissions
      ?.query({ name: "geolocation" })
      .then((p) => {
        if (!alive) return;
        perm = p;
        if (p.state === "granted" && status !== "granted" && status !== "loading" && !autoTried.current) {
          autoTried.current = true; // cheksiz qayta urinishning oldini oladi
          retry();
        }
        p.onchange = () => {
          if (p.state === "granted") retry();
        };
      })
      .catch(() => {});
    // Sozlamalardan qaytganda (tab/oyna fokusi) qayta urinib ko'ramiz.
    const onVisible = () => document.visibilityState === "visible" && recheck();
    window.addEventListener("focus", recheck);
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      alive = false;
      if (perm) perm.onchange = null;
      window.removeEventListener("focus", recheck);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [retry, status]);

  return { ...state, retry };
}
