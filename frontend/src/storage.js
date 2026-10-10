// localStorage/sessionStorage ba'zi kontekstlarda (maxfiylik rejimi, uchinchi tomon
// cookie bloki, sandbox iframe, DevTools emulyatsiyasi) xato beradi:
// "Access to storage is not allowed from this context". Bunday holatda ilova
// osilib qolmasligi uchun barcha murojaatlar shu yerdan o'tadi — xotirada zaxira bilan.
function make(kind) {
  const memory = new Map();
  const real = () => {
    try {
      return window[kind];
    } catch {
      return null;
    }
  };
  return {
    getItem(key) {
      try {
        const v = real()?.getItem(key);
        if (v !== undefined && v !== null) return v;
      } catch {
        /* xotiraga tushamiz */
      }
      return memory.has(key) ? memory.get(key) : null;
    },
    setItem(key, value) {
      memory.set(key, String(value));
      try {
        real()?.setItem(key, String(value));
      } catch {
        /* faqat xotirada */
      }
    },
    removeItem(key) {
      memory.delete(key);
      try {
        real()?.removeItem(key);
      } catch {
        /* e'tiborsiz */
      }
    },
  };
}

export const safeLocal = make("localStorage");
export const safeSession = make("sessionStorage");
