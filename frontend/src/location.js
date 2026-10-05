import { useCallback, useEffect, useRef, useState } from "react";

// Foydalanuvchi joylashuvi — mahsulotlar firma xizmat radiusiga qarab
// serverda filtrlanadi (backend apps/products/views.py), shuning uchun
// mahsulot so'rovlariga `lat`/`lng` qo'shiladi. Natija qisqa vaqt keshlanadi.
const TTL_MS = 5 * 60 * 1000;
let cache = null;
let inflight = null;

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
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        cache = { lat: pos.coords.latitude, lng: pos.coords.longitude, t: Date.now() };
        resolve({ status: "granted", lat: cache.lat, lng: cache.lng });
      },
      (err) => resolve({ status: err.code === 1 ? "denied" : "unavailable" }),
      { timeout: 10000, maximumAge: TTL_MS },
    );
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
