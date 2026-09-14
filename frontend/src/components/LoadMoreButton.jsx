/** Ro'yxat sahifalarida keyingi DRF pagination sahifasini yuklash uchun
 * umumiy tugma — `next` mavjud bo'lmasa hech narsa ko'rsatmaydi. */
export default function LoadMoreButton({ next, busy, onClick }) {
  if (!next) return null;
  return (
    <button className="btn-ghost self-center !px-4 !py-2 text-sm" onClick={onClick} disabled={busy}>
      {busy ? "Yuklanmoqda…" : "Yana yuklash"}
    </button>
  );
}
