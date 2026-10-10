import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ArrowLeft, Sofa } from "lucide-react";
import { api } from "../api";
import { useLocale } from "../locale";

const rows = (d) => (Array.isArray(d) ? d : d.results || []);

/** Vitrina (demo): faol firma yo'q hududdagi foydalanuvchi uchun test mahsulotlar.
 *  Savat/buyurtma yo'q; nomlar tanlangan tilda qayta yuklanadi. */
export default function Showcase() {
  const { code, t } = useLocale();
  const [items, setItems] = useState(null);
  const [error, setError] = useState("");
  const [open, setOpen] = useState(null);

  useEffect(() => {
    let alive = true;
    setError("");
    api(`/showcase/products/?lang=${code}`)
      .then((d) => alive && setItems(rows(d)))
      .catch((e) => alive && setError(e.message));
    return () => {
      alive = false;
    };
  }, [code]);

  const price = (p) =>
    p.price_from ? `${Number(p.price_from).toLocaleString("ru-RU")} ${t("currency_som")}${t("price_from_suffix")}` : null;

  return (
    <div className="mx-auto max-w-[1200px] px-4 py-6 lg:px-6">
      <div
        className="mb-5 rounded-xl px-4 py-3 text-sm font-bold"
        style={{ background: "var(--accent)", color: "var(--on-accent)" }}
      >
        {t("showcase_demo_banner")}
      </div>
      <div className="mb-4 flex items-center gap-3">
        <Link to="/" className="icon-btn" aria-label="back">
          <ArrowLeft size={18} />
        </Link>
        <h1 className="text-2xl font-bold">{t("showcase_title")}</h1>
      </div>

      {error && <div className="error mb-4">{error}</div>}
      {items === null && !error && <p style={{ color: "var(--muted)" }}>…</p>}
      {items && items.length === 0 && <p style={{ color: "var(--muted)" }}>{t("showcase_empty")}</p>}

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {(items || []).map((p) => (
          <button
            key={p.id}
            className="card overflow-hidden p-3 text-left transition hover:border-[var(--muted)]"
            onClick={() => setOpen(p)}
          >
            <div
              className="flex aspect-[4/3] w-full items-center justify-center overflow-hidden rounded-xl"
              style={{ background: "var(--surface-muted)" }}
            >
              {p.image_url ? (
                <img src={p.image_url} alt={p.name} className="h-full w-full object-contain p-3" loading="lazy" />
              ) : (
                <Sofa size={36} style={{ color: "var(--disabled)" }} />
              )}
            </div>
            <div className="px-1 pb-1 pt-3">
              <div className="line-clamp-2 text-sm font-semibold">{p.name}</div>
              {price(p) && <div className="mt-1 text-sm font-bold">{price(p)}</div>}
            </div>
          </button>
        ))}
      </div>

      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: "rgba(0,0,0,0.5)" }}
          onClick={() => setOpen(null)}
        >
          <div className="card max-h-[90vh] w-full max-w-lg overflow-auto p-4" onClick={(e) => e.stopPropagation()}>
            <div
              className="mb-3 flex aspect-[4/3] w-full items-center justify-center overflow-hidden rounded-xl"
              style={{ background: "var(--surface-muted)" }}
            >
              {(open.images?.[0] || open.image_url) && (
                <img src={open.image_url || open.images[0]} alt={open.name} className="h-full w-full object-contain p-3" />
              )}
            </div>
            <h2 className="text-xl font-bold">{open.name}</h2>
            {price(open) && <div className="mt-1 text-lg font-bold">{price(open)}</div>}
            {open.description && <p className="mt-3 text-sm">{open.description}</p>}
            <button className="btn mt-4 w-full" onClick={() => setOpen(null)}>
              OK
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
