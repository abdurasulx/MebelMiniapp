import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { AuthProvider } from "./auth";
import { LocaleProvider } from "./locale";
import { setTokens } from "./api";
import "./index.css";

// Boshqa subdomendan (masalan lvh.me'dan firma.lvh.me'ga) login qilingandan keyin
// yo'naltirilganda tokenlar URL orqali "uzatiladi" — localStorage har subdomen
// uchun alohida bo'lgani sababli. Shu yerda o'qib olib, darhol URL'dan tozalanadi.
const handoffParams = new URLSearchParams(window.location.search);
const handoffAccess = handoffParams.get("access");
const handoffRefresh = handoffParams.get("refresh");
if (handoffAccess && handoffRefresh) {
  setTokens({ access: handoffAccess, refresh: handoffRefresh });
  handoffParams.delete("access");
  handoffParams.delete("refresh");
  const rest = handoffParams.toString();
  window.history.replaceState({}, "", window.location.pathname + (rest ? `?${rest}` : ""));
}

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <BrowserRouter>
      <LocaleProvider>
        <AuthProvider>
          <App />
        </AuthProvider>
      </LocaleProvider>
    </BrowserRouter>
  </StrictMode>
);
