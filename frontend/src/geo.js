// Xarita/joylashuv yordamchilari — OpenStreetMap Nominatim (kalitsiz, bepul).

// Avval oddiy aniqlikda (Wi-Fi/tarmoq bo'yicha, kesh bilan) so'raymiz — GPS'siz
// noutbuk/kompyuterda ham tez ishlaydi. Faqat ruxsat bilan bog'liq bo'lmagan
// xatoda (aniqlab bo'lmadi / vaqt tugadi) yuqori aniqlik bilan qayta uriniladi.
function getPosition(options, graceMs = 0) {
  return new Promise((resolve, reject) => {
    let timer = null;
    let done = false;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        if (done) return;
        done = true;
        clearTimeout(timer);
        resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude });
      },
      (err) => {
        if (done) return;
        // Ruxsat berilgan bo'lsa-yu, Chrome ba'zan avval "User denied" xatosini,
        // KEYIN esa shu so'rovning muvaffaqiyatli natijasini qaytaradi —
        // `graceMs` ichida muvaffaqiyatni kutamiz, so'ng xatoni qaytaramiz.
        if (err.code === 1 && graceMs > 0 && !timer) {
          timer = setTimeout(() => {
            done = true;
            reject(err);
          }, graceMs);
          return;
        }
        done = true;
        clearTimeout(timer);
        reject(err);
      },
      options,
    );
  });
}

async function permissionState() {
  try {
    return (await navigator.permissions.query({ name: "geolocation" })).state;
  } catch {
    return "unknown";
  }
}

export async function currentPosition() {
  if (!navigator.geolocation) {
    throw new Error("Brauzeringiz joylashuvni aniqlashni qo'llab-quvvatlamaydi");
  }
  const options = { enableHighAccuracy: false, timeout: 10000, maximumAge: 300000 };
  const grace = (await permissionState()) === "granted" ? 4000 : 0;
  let err;
  try {
    return await getPosition(options, grace);
  } catch (e) {
    err = e;
  }
  // Ruxsat aslida berilgan bo'lsa-yu, tizim joylashuv xizmati uyg'onayotganda
  // birinchi so'rov "User denied" qaytarishi mumkin (macOS/Chrome) — bir marta qayta urinamiz.
  if (err.code === 1 && grace > 0) {
    await new Promise((r) => setTimeout(r, 600));
    try {
      return await getPosition(options, grace);
    } catch (e) {
      err = e;
    }
  }
  if (err.code !== 1) {
    try {
      return await getPosition({ enableHighAccuracy: true, timeout: 15000 });
    } catch (e) {
      err = e;
    }
  }
  if (err.code === 1) {
    throw new Error(
      "Brauzer joylashuvga ruxsat bermadi. Manzil satridagi qulf belgisi orqali \"Joylashuv\"ni yoqing " +
        "(yoki xaritadan tanlang)."
    );
  }
  throw new Error(
    "Joylashuvni aniqlab bo'lmadi" +
      (err.code === 3 ? " (vaqt tugadi)" : "") +
      ". Qurilmada joylashuv xizmati yoqilganini tekshiring yoki xaritadan tanlang."
  );
}

export async function reverseGeocode(latitude, longitude) {
  try {
    const r = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=jsonv2&accept-language=uz&lat=${latitude}&lon=${longitude}`
    );
    if (!r.ok) return null;
    const d = await r.json();
    return d.display_name || null;
  } catch {
    return null;
  }
}

export async function searchPlaces(query) {
  try {
    const r = await fetch(
      `https://nominatim.openstreetmap.org/search?format=jsonv2&accept-language=uz&limit=5&q=${encodeURIComponent(query)}`
    );
    if (!r.ok) return [];
    const list = await r.json();
    return list.map((p) => ({ name: p.display_name, latitude: Number(p.lat), longitude: Number(p.lon) }));
  } catch {
    return [];
  }
}

export const fixCoord = (n) => Number(n).toFixed(6);
