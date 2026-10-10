import { useEffect, useRef, useState } from "react";

function readStored() {
  try {
    return localStorage.getItem("theme");
  } catch {
    return null;
  }
}

function systemPrefersDark() {
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-color-scheme: dark)").matches;
}

export function useTheme() {
  const [dark, setDark] = useState(() => {
    const stored = readStored();
    return stored ? stored === "dark" : systemPrefersDark();
  });
  // Tanlov faqat foydalanuvchi almashtirganda saqlanadi — aks holda tizim
  // rejimi (prefers-color-scheme) birinchi ochilishdayoq "qotib" qolardi.
  const touched = useRef(false);

  useEffect(() => {
    const root = document.documentElement;
    root.classList.toggle("dark-mode", dark);
    root.setAttribute("data-theme", dark ? "dark" : "light");
    if (touched.current) {
      try {
        localStorage.setItem("theme", dark ? "dark" : "light");
      } catch {
        /* private rejim */
      }
    }
  }, [dark]);

  return {
    dark,
    toggle: () => {
      touched.current = true;
      setDark((d) => !d);
    },
  };
}
