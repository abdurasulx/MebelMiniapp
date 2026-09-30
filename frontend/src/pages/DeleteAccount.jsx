const SUPPORT_URL = "https://t.me/Vida_robot";

export default function DeleteAccount() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="mb-2 text-2xl font-bold">Hisobni va ma'lumotlarni o'chirish</h1>
      <p className="mb-8 text-sm" style={{ color: "var(--muted)" }}>
        VIDA Market — Android, iOS va veb
      </p>

      <div className="flex flex-col gap-7">
        <section>
          <h2 className="mb-2 text-lg font-semibold">Qanday so'rov yuboriladi</h2>
          <p className="mb-3 leading-relaxed" style={{ color: "var(--text)" }}>
            Hisobingizni va unga bog'liq shaxsiy ma'lumotlaringizni o'chirishni
            so'rash uchun quyidagi Telegram bot orqali murojaat qiling va
            ro'yxatdan o'tgan telefon raqamingizni ko'rsatib, hisobni
            o'chirishni so'rang:
          </p>
          <a
            href={SUPPORT_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-block font-medium underline"
            style={{ color: "var(--primary)" }}
          >
            @Vida_robot
          </a>
        </section>

        <section>
          <h2 className="mb-2 text-lg font-semibold">Nima o'chiriladi</h2>
          <ul className="list-disc space-y-1 pl-5 leading-relaxed" style={{ color: "var(--text)" }}>
            <li>Profil ma'lumotlari (ism, telefon raqami, email).</li>
            <li>Google/Telegram orqali bog'langan hisob ma'lumotlari.</li>
            <li>Sevimlilar ro'yxati va savatdagi mahsulotlar.</li>
            <li>Saqlangan manzillar va geolokatsiya ma'lumotlari.</li>
            <li>Push-bildirishnoma uchun saqlangan qurilma tokeni.</li>
          </ul>
        </section>

        <section>
          <h2 className="mb-2 text-lg font-semibold">Nima saqlanib qoladi</h2>
          <p className="leading-relaxed" style={{ color: "var(--text)" }}>
            Qonunchilik (buxgalteriya hisobi, soliq hisoboti) talabiga ko'ra,
            yakunlangan buyurtmalarga oid moliyaviy yozuvlar shaxsni
            aniqlab bo'lmaydigan holatda saqlanishi mumkin. Boshqa barcha
            shaxsiy ma'lumotlar to'liq o'chiriladi.
          </p>
        </section>

        <section>
          <h2 className="mb-2 text-lg font-semibold">Qancha vaqt ichida</h2>
          <p className="leading-relaxed" style={{ color: "var(--text)" }}>
            So'rov tasdiqlangandan so'ng 30 kun ichida amalga oshiriladi.
          </p>
        </section>
      </div>
    </div>
  );
}
