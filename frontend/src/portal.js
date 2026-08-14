// Subdomen bo'yicha portal aniqlash:
//   domen.uz (lvh.me)        -> market  (mijozlar marketplace'i)
//   admin.domen.uz           -> admin   (platforma admini)
//   firma.domen.uz           -> firma   (kompaniya egasi + xodimlar)
//
// Dev'da sinash uchun: ?portal=admin yoki ?portal=firma (faqat DEV buildda ishlaydi).
const sub = window.location.hostname.split(".")[0];

let portal = sub === "admin" ? "admin" : sub === "firma" ? "firma" : "market";

if (import.meta.env.DEV) {
  const forced = new URLSearchParams(window.location.search).get("portal");
  if (["market", "admin", "firma"].includes(forced)) portal = forced;
}

export const PORTAL = portal;

// Har bir portal o'zining brend nomiga ega — sarlavha (title) va
// sidebar/header'da shu nom ko'rsatiladi.
export const BRAND_NAME = { market: "VIDA Market", admin: "VIDA Admin", firma: "VIDA ERP" }[PORTAL];

if (typeof document !== "undefined") document.title = BRAND_NAME;

/**
 * Boshqa portal (subdomen)ning to'liq URL'ini hisoblaydi. Faqat `*.lvh.me`
 * (yoki umuman ko'p-darajali domen) da ishlaydi — 127.0.0.1/localhost kabi
 * subdomensiz manzillarda `null` qaytaradi (bunday holda joriy portalda qolamiz).
 */
export function portalURLFor(target) {
  const { protocol, hostname, port } = window.location;
  const isLocalDev = /^(localhost|\d+\.\d+\.\d+\.\d+)$/.test(hostname);
  if (isLocalDev) return null;

  const parts = hostname.split(".");
  const base = ["admin", "firma"].includes(parts[0]) ? parts.slice(1).join(".") : hostname;
  const prefix = target === "market" ? "" : `${target}.`;
  const portSuffix = port ? `:${port}` : "";
  return `${protocol}//${prefix}${base}${portSuffix}`;
}

/** Foydalanuvchi roliga qarab qaysi portalga tegishli ekanini aniqlaydi. */
export function portalForUser(me) {
  if (me.role === "platform_admin") return "admin";
  if (me.role === "company_owner" || me.role === "employee") return "firma";
  return "market";
}
