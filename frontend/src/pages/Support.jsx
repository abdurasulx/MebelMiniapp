const SUPPORT_URL = "https://t.me/Vida_robot";
const SUPPORT_EMAIL = "support@vidamarket.uz";

const FAQ = [
  {
    q: "Hisobni qanday o'chiraman?",
    a: "Ilovada Profil bo'limida \"Hisobni o'chirish\" tugmasini bosing. So'rov ko'rib chiqilgach hisob va unga bog'liq ma'lumotlar o'chiriladi.",
  },
  {
    q: "Buyurtmam holatini qayerdan ko'raman?",
    a: "Profil → So'nggi buyurtmalar bo'limida yoki bildirishnomalar orqali.",
  },
  {
    q: "Nomaqbul sharh yoki foydalanuvchini qanday xabar qilaman?",
    a: "Sharh yoki firma sahifasidagi menyudan \"Xabar berish\" yoki \"Bloklash\" ni tanlang. Xabarlar 24 soat ichida ko'rib chiqiladi.",
  },
  {
    q: "Kirish kodi (SMS) kelmayapti.",
    a: "Raqamni +998 formatida kiriting va 1 daqiqa kuting. Yordam bo'lmasa, Google, Apple yoki Telegram orqali kirishingiz mumkin.",
  },
];

export default function Support() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-8">
      <h1 className="mb-2 text-2xl font-bold">VIDA Market — Yordam</h1>
      <p className="mb-6 leading-relaxed">
        Savol, muammo yoki taklifingiz bo'lsa, biz bilan bog'laning. Odatda 1–2 ish kuni ichida javob beramiz.
      </p>

      <div className="mb-8 space-y-2 rounded-xl border p-4" style={{ borderColor: "var(--border, #ddd)" }}>
        <p>
          Email:{" "}
          <a className="font-medium underline" href={`mailto:${SUPPORT_EMAIL}`}>
            {SUPPORT_EMAIL}
          </a>
        </p>
        <p>
          Telegram:{" "}
          <a className="font-medium underline" href={SUPPORT_URL} target="_blank" rel="noreferrer">
            @Vida_robot
          </a>
        </p>
        <p>
          <a className="font-medium underline" href="/privacy">
            Maxfiylik siyosati
          </a>
        </p>
      </div>

      <h2 className="mb-3 text-lg font-semibold">Ko'p beriladigan savollar</h2>
      <div className="space-y-4">
        {FAQ.map((f) => (
          <section key={f.q}>
            <h3 className="font-semibold">{f.q}</h3>
            <p className="leading-relaxed">{f.a}</p>
          </section>
        ))}
      </div>
    </div>
  );
}
