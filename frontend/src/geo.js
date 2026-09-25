// Xarita/joylashuv yordamchilari — OpenStreetMap Nominatim (kalitsiz, bepul).

export function currentPosition() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error("Brauzeringiz joylashuvni aniqlashni qo'llab-quvvatlamaydi"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ latitude: pos.coords.latitude, longitude: pos.coords.longitude }),
      (err) =>
        reject(
          new Error(
            err.code === 1
              ? "Brauzer joylashuvga ruxsat bermadi. Manzil satridagi qulf belgisi orqali \"Joylashuv\"ni yoqing " +
                "(yoki xaritadan tanlang)."
              : "Joylashuvni aniqlab bo'lmadi: " + err.message
          )
        ),
      { enableHighAccuracy: true, timeout: 15000 }
    );
  });
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
