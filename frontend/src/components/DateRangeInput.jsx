/**
 * Bitta umumiy sana oralig'i komponenti — loyihada har qanday "boshlanish/
 * tugash sanasi" kerak bo'lgan joyda (filtrlar, hisobotlar, topshiriq
 * rejalashtirish) ALOHIDA ikkita <input type="date"> o'rniga shu ishlatiladi
 * (docs "Buyurtmalar va topshiriqlar tizimi" §9). Bitta yaxlit ramka ichida
 * ikkita segment ko'rinadi — foydalanuvchi ketma-ket ikki marta bosib
 * (avval boshlanish, keyin tugash) sana tanlaydi, lekin bu bitta `value`
 * ({ start, stop }) bilan boshqariladigan yagona komponent.
 *
 * Agar tugash sanasi boshlanishdan oldingi bo'lsa — ikkalasi avtomatik
 * almashtiriladi (docs §10).
 */
export default function DateRangeInput({ start, stop, onChange, className = "" }) {
  const swapIfReversed = (nextStart, nextStop) => {
    if (nextStart && nextStop && nextStop < nextStart) {
      return { start: nextStop, stop: nextStart };
    }
    return { start: nextStart, stop: nextStop };
  };

  const handleStartChange = (e) => {
    onChange(swapIfReversed(e.target.value, stop));
  };

  const handleStopChange = (e) => {
    onChange(swapIfReversed(start, e.target.value));
  };

  return (
    <div
      className={`flex items-center gap-1.5 rounded-xl px-3 py-2 text-sm ${className}`}
      style={{ border: "1px solid var(--border)", background: "var(--card)" }}
    >
      <input
        type="date"
        className="bg-transparent outline-none"
        style={{ color: "var(--text)", colorScheme: "var(--input-color-scheme, light)" }}
        value={start || ""}
        onChange={handleStartChange}
        aria-label="Boshlanish sanasi"
      />
      <span style={{ color: "var(--muted)" }}>—</span>
      <input
        type="date"
        className="bg-transparent outline-none"
        style={{ color: "var(--text)", colorScheme: "var(--input-color-scheme, light)" }}
        value={stop || ""}
        onChange={handleStopChange}
        aria-label="Tugash sanasi"
      />
    </div>
  );
}
