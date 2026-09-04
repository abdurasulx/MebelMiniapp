import { createContext, useContext, useEffect, useState } from "react";
import { DEFAULT_LOCALE, SUPPORTED_LOCALES, tr } from "./l10n/strings";

const STORAGE_KEY = "vida_locale";
const LocaleContext = createContext(null);

/// Birinchi marta ochilganda (hali qo'lda tanlanmagan bo'lsa) brauzer tiliga
/// qarab avtomatik aniqlanadi — qo'llab-quvvatlanmasa o'zbekchaga qaytadi
/// (mobil ilovadagi `LocaleStore._detectDeviceLocale` bilan bir xil naqsh).
function detectBrowserLocale() {
  const codes = SUPPORTED_LOCALES.map((l) => l.code);
  for (const lang of navigator.languages || [navigator.language || ""]) {
    const short = lang.slice(0, 2).toLowerCase();
    if (codes.includes(short)) return short;
  }
  return DEFAULT_LOCALE;
}

export function LocaleProvider({ children }) {
  const [code, setCode] = useState(() => localStorage.getItem(STORAGE_KEY) || detectBrowserLocale());

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, code);
  }, [code]);

  const t = (key) => tr(code, key);

  return (
    <LocaleContext.Provider value={{ code, setLocale: setCode, t }}>
      {children}
    </LocaleContext.Provider>
  );
}

export function useLocale() {
  return useContext(LocaleContext);
}
