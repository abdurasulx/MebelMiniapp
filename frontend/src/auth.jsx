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

  const login = async (email, password) => {
    const tokens = await api("/auth/token/", { method: "POST", body: { email, password } });
    setTokens(tokens);
    const me = await api("/users/me/");
    setUser(me);
    return me;
  };

  // `credential` — Google Identity Services'dan kelgan ID token (JWT).
  // Backend uni server-side verify qilib, bizning JWT juftligimizni
  // qaytaradi — bu yerdan keyingi qadamlar oddiy `login()` bilan bir xil.
  const loginWithGoogle = async (credential) => {
    const tokens = await api("/auth/google/", { method: "POST", body: { credential } });
    setTokens(tokens);
    const me = await api("/users/me/");
    setUser(me);
    return me;
  };

  const register = async (payload) => {
    await api("/auth/register/", { method: "POST", body: payload });
    return login(payload.email, payload.password);
  };

  const logout = () => {
    setTokens(null);
    setUser(null);
    setActivePosition(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, loginWithGoogle, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
