import { useEffect } from "react";
import { useLocale } from "../locale";
import { SUPPORTED_LOCALES } from "../l10n/strings";
import { PRIVACY } from "../l10n/privacy";

const SUPPORT_URL = "https://t.me/Vida_robot";
const CONTACT_LABEL = "@Vida_robot";

/** Maxfiylik siyosati — 9 tilda; til `?lang=xx` (mobil ilovadan) yoki tanlovdan olinadi. */
export default function PrivacyPolicy() {
  const { code, setLocale } = useLocale();

  // Ilovadan `.../privacy?lang=ru` bilan ochilsa, shu tilga o'tadi.
  useEffect(() => {
    const q = new URLSearchParams(window.location.search).get("lang");
    if (q && PRIVACY[q] && q !== code) setLocale(q);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const doc = PRIVACY[code] || PRIVACY.uz;
  const last = doc.sections.length - 1;

  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <div className="mb-6 flex flex-wrap items-center gap-2" role="group" aria-label={doc.language}>
        <span className="text-sm" style={{ color: "var(--muted)" }}>
          {doc.language}:
        </span>
        {SUPPORTED_LOCALES.map((l) => (
          <button
            key={l.code}
            type="button"
            onClick={() => setLocale(l.code)}
            aria-pressed={l.code === code}
            className={l.code === code ? "btn !px-3 !py-1.5 text-sm" : "btn-ghost !px-3 !py-1.5 text-sm"}
          >
            {l.flag} {l.nativeName}
          </button>
        ))}
      </div>

      <h1 className="mb-2 text-2xl font-bold">{doc.title}</h1>
      <p className="mb-8 text-sm" style={{ color: "var(--muted)" }}>
        {doc.updated}
      </p>

      <div className="flex flex-col gap-7">
        {doc.sections.map((s, idx) => (
          <section key={idx}>
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
            {idx === 4 && (
              <a href="/delete-account" className="font-medium underline" style={{ color: "var(--secondary)" }}>
                {doc.deleteLabel}
              </a>
            )}
            {idx === last && (
              <a
                href={SUPPORT_URL}
                target="_blank"
                rel="noreferrer"
                className="font-medium underline"
                style={{ color: "var(--secondary)" }}
              >
                {CONTACT_LABEL}
              </a>
            )}
          </section>
        ))}
      </div>
    </div>
  );
}
