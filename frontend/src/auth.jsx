import { createContext, useContext, useEffect, useState } from "react";
import { api, setTokens } from "./api";
import { setActivePosition } from "./positions";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api("/users/me/")
      .then(setUser)
      .catch(() => setUser(null))
      .finally(() => setLoading(false));
  }, []);

  // Sessiya sahifa ochilgandan keyin biror joyda (masalan like/savat
  // tugmasi bosilganda) tugab qolsa — `api.js` refresh tokenini ham
  // yaroqsiz deb topganda shu eventni yuboradi. Shunda `user`ni darhol
  // `null`ga tushiramiz, aks holda UI "kirgan" ko'rsatib turaverar, lekin
  // har qanday himoyalangan amal sababsiz muvaffaqiyatsiz bo'lardi.
  useEffect(() => {
    const onExpired = () => setUser(null);
    window.addEventListener("auth:session-expired", onExpired);
    return () => window.removeEventListener("auth:session-expired", onExpired);
  }, []);

  // Tokenlar qanday olinishidan qat'iy nazar (parol, Google, Telegram) —
  // saqlash va profil yuklash bir xil.
  const applyTokens = async (tokens) => {
    setTokens(tokens);
    const me = await api("/users/me/");
    setUser(me);
    return me;
  };

  // Email+parol — endi faqat admin portalida ishlatiladi (mijoz/firma
  // egasi/xodim Google yoki Telegram orqali kiradi).
  const login = async (email, password) => {
    const tokens = await api("/auth/token/", { method: "POST", body: { email, password } });
    return applyTokens(tokens);
  };

  // Telegram — session-poll oqimi (qarang Login.jsx) tokenlarni to'g'ridan-
  // to'g'ri qaytaradi, backendga qo'shimcha almashtirish so'rovi kerak emas.
  const loginWithTokens = async (tokens) => applyTokens(tokens);

  // `/complete-registration` sahifasi profilni to'ldirgandan keyin
  // `user`ni (rol/registration_completed) yangilash uchun.
  const refreshUser = async () => {
    const me = await api("/users/me/");
    setUser(me);
    return me;
  };

  const logout = () => {
    setTokens(null);
    setUser(null);
    setActivePosition(null);
  };

  return (
    <AuthContext.Provider
      value={{ user, loading, login, loginWithTokens, refreshUser, logout }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
