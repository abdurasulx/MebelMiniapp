import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Factory, Sofa, MapPin, Star, AtSign, Send, Link as LinkIcon, Globe } from "lucide-react";

const SOCIAL_LINKS = [
  { key: "instagram_url", icon: AtSign, label: "Instagram" },
  { key: "telegram_url", icon: Send, label: "Telegram" },
  { key: "facebook_url", icon: LinkIcon, label: "Facebook" },
  { key: "website_url", icon: Globe, label: "Veb-sayt" },
];
import { api } from "../api";
import { useAuth } from "../auth";
import CompanyBadge from "../components/CompanyBadge";

function StarRow({ count }) {
  return (
    <span className="inline-flex items-center gap-0.5" style={{ color: "#f5b301" }}>
      {Array.from({ length: count }).map((_, i) => (
        <Star key={i} size={13} fill="currentColor" />
      ))}
    </span>
  );
}

export default function Shop() {
  const { slug } = useParams();
  const { user } = useAuth();
  const [company, setCompany] = useState(null);
  const [products, setProducts] = useState([]);
  const [reviews, setReviews] = useState([]);
  const [error, setError] = useState("");
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState("");
  const [busy, setBusy] = useState(false);
  const [reviewMsg, setReviewMsg] = useState("");

  useEffect(() => {
    api(`/companies/${slug}/`)
      .then(setCompany)
      .catch((e) => setError(e.message));
    api(`/products/?company=${slug}`)
      .then((d) => setProducts(d.results || []))
      .catch(() => {});
    api(`/reviews/?company=${slug}`)
      .then((d) => setReviews(d.results || []))
      .catch(() => {});
  }, [slug]);

  const submitReview = async (e) => {
    e.preventDefault();
    setReviewMsg("");
    setBusy(true);
    try {
      await api("/reviews/", { method: "POST", body: { company: company.id, rating, comment } });
      setReviewMsg("Rahmat! Bahoyingiz saqlandi.");
      setComment("");
      const [c, r] = await Promise.all([
        api(`/companies/${slug}/`),
        api(`/reviews/?company=${slug}`),
      ]);
      setCompany(c);
      setReviews(r.results || []);
    } catch (e) {
      setReviewMsg(e.message);
    } finally {
      setBusy(false);
    }
  };

  if (error && !company)
    return (
      <div className="mx-auto max-w-6xl px-4 py-8">
        <div className="error">{error}</div>
      </div>
    );
  if (!company)
    return (
      <div className="mx-auto max-w-6xl px-4 py-8" style={{ color: "var(--muted)" }}>
        Yuklanmoqda…
      </div>
    );

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      {/* Do'kon banneri */}
      <div
        className="mb-8 flex flex-col gap-4 rounded-3xl p-8 sm:flex-row sm:items-center"
        style={{
          background:
            "linear-gradient(120deg, var(--brand-surface), color-mix(in srgb, var(--brand-surface) 80%, var(--brand-surface-text)))",
          color: "var(--brand-surface-text)",
        }}
      >
        {company.logo_url ? (
          <img src={company.logo_url} alt={company.name} className="h-20 w-20 rounded-2xl object-cover" />
        ) : (
          <div
            className="flex h-20 w-20 items-center justify-center rounded-2xl"
            style={{ background: "color-mix(in srgb, var(--brand-surface-text) 15%, transparent)" }}
          >
            <Factory size={32} />
          </div>
        )}
        <div>
          <div className="mb-1 flex flex-wrap items-center gap-2">
            <h1 className="text-2xl font-bold">{company.name}</h1>
            <CompanyBadge tier={company.tier} />
          </div>
          {company.description && <p className="max-w-xl text-sm opacity-80">{company.description}</p>}
          {(company.address || (company.latitude && company.longitude)) && (
            <p className="mt-1 flex items-center gap-1 text-xs opacity-70">
              <MapPin size={12} /> {company.address}
              {company.latitude && company.longitude && (
                <a
                  href={`https://www.google.com/maps?q=${company.latitude},${company.longitude}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="ml-1 underline"
                >
                  Xaritada ko'rish
                </a>
              )}
            </p>
          )}
          {SOCIAL_LINKS.some(({ key }) => company[key]) && (
            <div className="mt-2 flex items-center gap-2">
              {SOCIAL_LINKS.filter(({ key }) => company[key]).map(({ key, icon: Icon, label }) => (
                <a
                  key={key}
                  href={company[key]}
                  target="_blank"
                  rel="noopener noreferrer"
                  title={label}
                  className="flex h-8 w-8 items-center justify-center rounded-full transition hover:opacity-80"
                  style={{ background: "color-mix(in srgb, var(--brand-surface-text) 15%, transparent)" }}
                >
                  <Icon size={15} />
                </a>
              ))}
            </div>
          )}
        </div>
      </div>

      <h2 className="mb-4 text-lg font-semibold">Mahsulotlar</h2>
      {products.length === 0 ? (
        <p className="mb-8 text-sm" style={{ color: "var(--muted)" }}>Hozircha mahsulotlar yo'q.</p>
      ) : (
        <div className="mb-10 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {products.map((p) => (
            <Link
              to={`/products/${p.id}`}
              key={p.id}
              className="card group overflow-hidden transition hover:-translate-y-1 hover:shadow-lg"
            >
              {(p.image_url || p.images?.[0]?.image_url) ? (
                <img src={p.image_url || p.images[0].image_url} alt={p.name_uz} className="h-40 w-full object-cover transition group-hover:scale-105" />
              ) : (
                <div
                  className="flex h-40 w-full items-center justify-center"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  <Sofa size={28} />
                </div>
              )}
              <div className="p-3">
                <span className="text-sm font-semibold">{p.name_uz}</span>
              </div>
            </Link>
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div>
          <h2 className="mb-4 text-lg font-semibold">Mijoz baholari ({reviews.length})</h2>
          {reviews.length === 0 ? (
            <p className="text-sm" style={{ color: "var(--muted)" }}>Hali baho yo'q.</p>
          ) : (
            <div className="flex flex-col gap-3">
              {reviews.map((r) => (
                <div key={r.id} className="card p-4">
                  <div className="mb-1 flex items-center justify-between">
                    <span className="text-sm font-medium">{r.customer_name || "Mijoz"}</span>
                    <StarRow count={r.rating} />
                  </div>
                  {r.comment && <p className="text-sm" style={{ color: "var(--muted)" }}>{r.comment}</p>}
                </div>
              ))}
            </div>
          )}
        </div>

        {user && company.can_review && (
          <div className="card h-fit p-6">
            <h2 className="mb-3 text-lg font-semibold">Baho qoldirish</h2>
            <form onSubmit={submitReview} className="flex flex-col gap-3">
              <div>
                <label className="label">Baho</label>
                <select className="input" value={rating} onChange={(e) => setRating(Number(e.target.value))}>
                  {[5, 4, 3, 2, 1].map((n) => (
                    <option key={n} value={n}>{n} yulduz</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="label">Izoh (ixtiyoriy)</label>
                <textarea className="input" rows={3} value={comment} onChange={(e) => setComment(e.target.value)} />
              </div>
              {reviewMsg && <div className="text-sm" style={{ color: "var(--secondary)" }}>{reviewMsg}</div>}
              <button className="btn btn-brand" disabled={busy} type="submit">
                {busy ? "Yuborilmoqda…" : "Baho qoldirish"}
              </button>
            </form>
          </div>
        )}
        {user && !company.can_review && (
          <div className="card h-fit p-6">
            <p className="text-xs" style={{ color: "var(--muted)" }}>
              Faqat shu firmadan yakunlangan buyurtmangiz bo'lsa baho qoldira olasiz.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
