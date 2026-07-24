import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Box, Heart, Sofa, ArrowRight } from "lucide-react";
import { api } from "../api";
import { useAuth } from "../auth";
import { PORTAL, portalForUser, portalURLFor } from "../portal";

const PORTAL_LABEL = { admin: "platforma boshqaruvi", firma: "firma kabineti" };

export default function Catalog() {
  const { user } = useAuth();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [cat, setCat] = useState("");
  const [error, setError] = useState("");

  const toggleLike = async (e, product) => {
    e.preventDefault();
    e.stopPropagation();
    if (!user) return;
    try {
      const res = await api("/likes/toggle/", { method: "POST", body: { product: product.id } });
      setProducts((prev) => prev.map((p) => (p.id === product.id ? { ...p, is_liked: res.liked } : p)));
    } catch {
      // jim turamiz
    }
  };

  useEffect(() => {
    api("/categories/")
      .then((d) => setCategories(d.results || []))
      .catch(() => {});
    api("/products/")
      .then((d) => setProducts(d.results || []))
      .catch((e) => setError(e.message));
  }, []);

  const shown = cat ? products.filter((p) => p.category === cat) : products;

  const targetPortal = user ? portalForUser(user) : null;
  const showPortalNotice = targetPortal && targetPortal !== PORTAL;
  const targetPortalURL = showPortalNotice ? portalURLFor(targetPortal) : null;

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      {showPortalNotice && (
        <div
          className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-2xl px-5 py-3 text-sm"
          style={{ background: "color-mix(in srgb, var(--secondary) 15%, var(--card))", border: "1px solid var(--border)" }}
        >
          <span>
            Siz <strong>{PORTAL_LABEL[targetPortal]}</strong> hisobi bilan kirgansiz — bu yerda mijoz sifatida
            xarid qilishingiz mumkin.
          </span>
          {targetPortalURL ? (
            <a href={targetPortalURL} className="btn btn-brand inline-flex items-center gap-1 !px-4 !py-1.5 text-xs whitespace-nowrap">
              {PORTAL_LABEL[targetPortal]}ga o'tish <ArrowRight size={13} />
            </a>
          ) : (
            <span className="text-xs" style={{ color: "var(--muted)" }}>
              (subdomen orqali kirganda avtomatik o'tkaziladi)
            </span>
          )}
        </div>
      )}
      {/* Hero */}
      <div
        className="mb-8 rounded-3xl p-8 sm:p-12"
        style={{
          background:
            "linear-gradient(120deg, var(--brand-surface), color-mix(in srgb, var(--brand-surface) 80%, var(--brand-surface-text)))",
          color: "var(--brand-surface-text)",
        }}
      >
        <h1 className="mb-2 text-2xl font-bold sm:text-3xl">
          Orzuingizdagi mebel — o'lchamingizga mos
        </h1>
        <p className="max-w-xl text-sm opacity-80">
          O'zbekistonning eng yaxshi mebel ustalari bir joyda. O'lchamni kiriting,
          narxni darhol bilib oling, buyurtma bering.
        </p>
      </div>

      {/* Filtr */}
      <div className="mb-6 flex flex-wrap items-center gap-2">
        <button
          className={cat === "" ? "btn btn-brand !px-4 !py-1.5 text-xs" : "btn-ghost !px-4 !py-1.5 text-xs"}
          onClick={() => setCat("")}
        >
          Barchasi
        </button>
        {categories.map((c) => (
          <button
            key={c.id}
            className={cat === c.id ? "btn btn-brand !px-4 !py-1.5 text-xs" : "btn-ghost !px-4 !py-1.5 text-xs"}
            onClick={() => setCat(c.id)}
          >
            {c.name_uz}
          </button>
        ))}
      </div>

      {error && <div className="error mb-4">{error}</div>}
      {shown.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hozircha mahsulotlar yo'q.</p>
      )}

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {shown.map((p) => (
          <Link
            to={`/products/${p.id}`}
            key={p.id}
            className="card group relative overflow-hidden transition hover:-translate-y-1 hover:shadow-lg"
          >
            <div className="absolute right-2 top-2 z-10 flex items-center gap-1.5">
              {p.model3d?.glb_url && (
                <span
                  className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-bold shadow"
                  style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
                  title="3D / AR mavjud"
                >
                  <Box size={12} /> 3D
                </span>
              )}
              {user && (
                <button
                  onClick={(e) => toggleLike(e, p)}
                  className="flex h-7 w-7 items-center justify-center rounded-full shadow"
                  style={{ background: "var(--card)" }}
                  title={p.is_liked ? "Sevimlilardan olib tashlash" : "Sevimlilarga qo'shish"}
                >
                  <Heart size={14} fill={p.is_liked ? "currentColor" : "none"} style={{ color: p.is_liked ? "#e74c3c" : "var(--muted)" }} />
                </button>
              )}
            </div>
            {(p.image_url || p.images?.[0]?.image_url) ? (
              <img
                src={p.image_url || p.images[0].image_url}
                alt={p.name_uz}
                className="h-44 w-full object-cover transition group-hover:scale-105"
              />
            ) : (
              <div
                className="flex h-44 w-full items-center justify-center"
                style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
              >
                <Sofa size={36} />
              </div>
            )}
            <div className="flex flex-col gap-1 p-4">
              <span className="font-semibold">{p.name_uz}</span>
              <span className="text-xs" style={{ color: "var(--muted)" }}>{p.company_name}</span>
              {p.variants.length > 0 && (
                <span className="mt-1 text-sm font-bold" style={{ color: "var(--secondary)" }}>
                  {Number(p.variants[0].base_price).toLocaleString()} so'm/m³ dan
                </span>
              )}
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
