const SUPPORT_URL = "https://t.me/Vida_robot";

const SECTIONS = [
  {
    title: "1. Umumiy ma'lumot",
    body: [
      `VIDA Market ("biz", "ilova") — mebel ishlab chiqaruvchilari va xaridorlarni
      bog'laydigan platforma. Ushbu sahifa ilova (Android, iOS) va vebsayt orqali
      qanday ma'lumot to'planishi, qanday ishlatilishi va qanday himoyalanishini
      tushuntiradi.`,
    ],
  },
  {
    title: "2. To'playdigan ma'lumotlarimiz",
    list: [
      "Ism va telefon raqami — ro'yxatdan o'tish va buyurtma bilan bog'lanish uchun.",
      "Google/Telegram orqali kirishda — hisob identifikatori, ism va (agar berilgan bo'lsa) email.",
      "Geolokatsiya (GPS) — sizga yaqin viloyatdagi mahsulot va ustalarni ko'rsatish uchun; faqat ruxsat bergan holatda va faqat ilova ochiq paytida so'raladi.",
      "Kamera/rasmlar — mahsulotni AR (kengaytirilgan reallik) orqali xonangizda ko'rish va rasm bo'yicha mahsulot qidirish funksiyalari uchun; qidiruv uchun yuklangan rasm faqat natija topish uchun ishlatiladi.",
      "Push-bildirishnoma tokeni (Firebase Cloud Messaging) — buyurtma holati haqida xabar yuborish uchun.",
      "Buyurtmalar, sevimlilar va savat tarixi — xizmatni ko'rsatish uchun.",
      "Qurilma va ilova ishlatilishi haqidagi texnik ma'lumot (masalan xatolik hisobotlari) — ilovani barqaror ishlashini ta'minlash uchun.",
    ],
  },
  {
    title: "3. Ma'lumotlardan qanday foydalanamiz",
    list: [
      "Hisobingizni yaratish va buyurtmalarni amalga oshirish uchun.",
      "Sizga yaqin mahsulot/ustalarni ko'rsatish uchun.",
      "Buyurtma holati va boshqa muhim voqealar haqida bildirishnoma yuborish uchun.",
      "Xizmatni yaxshilash va texnik nosozliklarni bartaraf etish uchun.",
    ],
  },
  {
    title: "4. Uchinchi tomon xizmatlari",
    body: [
      `Ilova quyidagi xizmatlardan foydalanadi, ular o'z maxfiylik siyosatiga ega:`,
    ],
    list: [
      "Google Sign-In — hisobga kirish uchun.",
      "Firebase (Google) — push-bildirishnoma yetkazish uchun.",
      "Telegram — bot orqali hisobga kirish/bog'lanish uchun.",
    ],
  },
  {
    title: "5. Ma'lumotni saqlash muddati",
    body: [
      `Hisobingiz faol bo'lgan davomida ma'lumotlaringiz saqlanadi. Hisobni
      o'chirishni so'raganingizda, qonun talab qiladigan hisobot/buxgalteriya
      yozuvlaridan (masalan yakunlangan buyurtmalar) tashqari, shaxsiy
      ma'lumotlaringiz o'chiriladi — batafsil: `,
    ],
    linkTo: "/delete-account",
    linkLabel: "Hisobni o'chirish sahifasi",
  },
  {
    title: "6. Sizning huquqlaringiz",
    list: [
      "Profilingizdagi ma'lumotlarni istalgan vaqtda ko'rish va tahrirlash.",
      "Hisobingiz va unga bog'liq shaxsiy ma'lumotlarni o'chirishni so'rash.",
      "Push-bildirishnomalarni qurilma sozlamalaridan o'chirib qo'yish.",
    ],
  },
  {
    title: "7. Bolalar maxfiyligi",
    body: [
      `Ilova 13 yoshdan kichik bolalar uchun mo'ljallanmagan va ularning
      ma'lumotlarini ataylab to'plamaydi.`,
    ],
  },
  {
    title: "8. O'zgarishlar",
    body: [
      `Ushbu siyosat vaqti-vaqti bilan yangilanishi mumkin — muhim o'zgarishlar
      bo'lsa ilova ichida xabar beramiz.`,
    ],
  },
  {
    title: "9. Bog'lanish",
    body: [`Savol yoki so'rovlaringiz bo'lsa, Telegram orqali murojaat qiling:`],
    linkHref: SUPPORT_URL,
    linkLabel: "@Vida_robot",
  },
];

export default function PrivacyPolicy() {
  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <h1 className="mb-2 text-2xl font-bold">Maxfiylik siyosati</h1>
      <p className="mb-8 text-sm" style={{ color: "var(--muted)" }}>
        Oxirgi yangilanish: 2026-yil
      </p>

      <div className="flex flex-col gap-7">
        {SECTIONS.map((s) => (
          <section key={s.title}>
            <h2 className="mb-2 text-lg font-semibold">{s.title}</h2>
            {s.body?.map((p, i) => (
              <p key={i} className="mb-2 leading-relaxed" style={{ color: "var(--text)" }}>
                {p}
              </p>
            ))}
            {s.list && (
              <ul className="list-disc space-y-1 pl-5 leading-relaxed" style={{ color: "var(--text)" }}>
                {s.list.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            )}
            {s.linkTo && (
              <a href={s.linkTo} className="font-medium underline" style={{ color: "var(--secondary)" }}>
                {s.linkLabel}
              </a>
            )}
            {s.linkHref && (
              <a
                href={s.linkHref}
                target="_blank"
                rel="noreferrer"
                className="font-medium underline"
                style={{ color: "var(--secondary)" }}
              >
                {s.linkLabel}
              </a>
            )}
          </section>
        ))}
      </div>
    </div>
  );
}
