import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { ArrowLeft, Box, Camera, Heart, Search, Sofa, ArrowRight, X } from "lucide-react";
import { api } from "../api";
import { useAuth } from "../auth";
import { useLocale } from "../locale";
import PriceTag from "../components/PriceTag";
import { PORTAL, portalForUser, portalURLFor } from "../portal";

// Kartochkada nomdan keyin ko'rsatiladigan qisqa xususiyat qatori — masalan
// "kulrang · 60×90×60 sm" (rang avtomatik aniqlangan, o'lcham birinchi
// variantdan, metrdan santimetrga o'tkazilib).
function attributeSummary(p) {
  const parts = [];
  if (p.color_tag) parts.push(p.color_tag);
  const v = p.variants?.[0];
  if (v) {
    const w = Math.round(Number(v.width) * 100);
    const h = Math.round(Number(v.height) * 100);
    const d = Math.round(Number(v.depth) * 100);
    if (w > 1 && h > 1 && d > 1) parts.push(`${w}×${h}×${d} sm`);
  }
  return parts.length ? parts.join(" · ") : null;
}

export default function Catalog() {
  const { user } = useAuth();
  const { t } = useLocale();
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [cat, setCat] = useState("");
  const [error, setError] = useState("");
  const [imageResults, setImageResults] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [imageSearching, setImageSearching] = useState(false);
  const [imageError, setImageError] = useState("");
  const [search, setSearch] = useState("");
  const [searchResults, setSearchResults] = useState(null);
  const [searching, setSearching] = useState(false);
  const fileInputRef = useRef(null);

  useEffect(() => {
    const q = search.trim();
    if (!q) {
      setSearchResults(null);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      api(`/products/?search=${encodeURIComponent(q)}`)
        .then((d) => setSearchResults(d.results || []))
        .catch((e) => setError(e.message))
        .finally(() => setSearching(false));
    }, 350);
    return () => clearTimeout(timer);
  }, [search]);

  const backToHome = () => {
    setSearch("");
    setSearchResults(null);
    clearImageSearch();
  };

  const pickImage = () => fileInputRef.current?.click();

  const searchByImage = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setImageError("");
    setImageSearching(true);
    setImagePreview(URL.createObjectURL(file));
    try {
      const fd = new FormData();
      fd.append("image", file);
      const results = await api("/products/search-by-image/", { method: "POST", body: fd, isForm: true });
      setImageResults(results || []);
    } catch (err) {
      setImageError(err.message);
      setImageResults(null);
    } finally {
      setImageSearching(false);
    }
  };

  const clearImageSearch = () => {
    setImageResults(null);
    setImagePreview(null);
    setImageError("");
  };

  const toggleLike = async (e, product) => {
    e.preventDefault();
    e.stopPropagation();
    if (!user) {
      setError(t("catalog_like_login_required"));
      return;
    }
    try {
      const res = await api("/likes/toggle/", { method: "POST", body: { product: product.id } });
      setProducts((prev) => prev.map((p) => (p.id === product.id ? { ...p, is_liked: res.liked } : p)));
    } catch (err) {
      setError(err.message);
    }
  };

  const loadProducts = (lat, lng) => {
    const query = lat != null && lng != null ? `?lat=${lat}&lng=${lng}` : "";
    api(`/products/${query}`)
      .then((d) => setProducts(d.results || []))
      .catch((e) => setError(e.message));
  };

  useEffect(() => {
    api("/categories/")
      .then((d) => setCategories(d.results || []))
      .catch(() => {});
    // Foydalanuvchi joylashuvi ruxsat berilsa — firma xizmat radiusiga mos
    // mahsulotlar ko'rsatiladi (qarang backend apps/products/views.py). Rad
    // etilsa yoki mavjud bo'lmasa, oddiy (filtrsiz) ro'yxat ko'rsatiladi.
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => loadProducts(pos.coords.latitude, pos.coords.longitude),
        () => loadProducts(),
        { timeout: 5000 },
      );
    } else {
      loadProducts();
    }
  }, []);

  const isSearching = Boolean(imageResults || searchResults !== null);
  const shown = imageResults ?? searchResults ?? (cat ? products.filter((p) => p.category === cat) : products);

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
            {t("catalog_portal_notice_prefix")}<strong>{t(`portal_label_${targetPortal}`)}</strong>{t("catalog_portal_notice_suffix")}
          </span>
          {targetPortalURL ? (
            <a href={targetPortalURL} className="btn btn-brand inline-flex items-center gap-1 !px-4 !py-1.5 text-xs whitespace-nowrap">
              {t(`portal_label_${targetPortal}`)}{t("catalog_go_to_portal_suffix")} <ArrowRight size={13} />
            </a>
          ) : (
            <span className="text-xs" style={{ color: "var(--muted)" }}>
              {t("catalog_subdomain_note")}
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
          {t("catalog_hero_title")}
        </h1>
        <p className="max-w-xl text-sm opacity-80">
          {t("catalog_hero_subtitle")}
        </p>
      </div>

      {/* Qidiruv */}
      <div className="mb-4 flex items-center gap-2">
        {isSearching && (
          <button
            className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl"
            style={{ border: "1px solid var(--border)", background: "var(--card)" }}
            onClick={backToHome}
            title={t("catalog_back_home_tooltip")}
          >
            <ArrowLeft size={16} />
          </button>
        )}
        <div className="relative flex-1">
          <Search size={16} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
          <input
            type="text"
            value={search}
            onChange={(e) => { setSearch(e.target.value); if (e.target.value) clearImageSearch(); }}
            placeholder={t("catalog_search_hint")}
            className="w-full rounded-xl py-2.5 pl-9 pr-9 text-sm"
            style={{ border: "1px solid var(--border)", background: "var(--card)" }}
          />
          {search && (
            <button
              className="absolute right-2 top-1/2 flex h-6 w-6 -translate-y-1/2 items-center justify-center rounded-full"
              onClick={() => { setSearch(""); setSearchResults(null); }}
              style={{ color: "var(--muted)" }}
            >
              <X size={14} />
            </button>
          )}
        </div>
        <button
          className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl"
          style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
          onClick={pickImage}
          disabled={imageSearching}
          title={t("catalog_image_search_tooltip")}
        >
          <Camera size={16} />
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          className="hidden"
          onChange={searchByImage}
        />
      </div>

      {/* Filtr */}
      {!isSearching && (
        <div className="mb-6 flex flex-wrap items-center gap-2">
          <button
            className={cat === "" ? "btn btn-brand !px-4 !py-1.5 text-xs" : "btn-ghost !px-4 !py-1.5 text-xs"}
            onClick={() => setCat("")}
          >
            {t("catalog_filter_all")}
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
      )}

      {imagePreview && (
        <div
          className="mb-6 flex flex-wrap items-center gap-3 rounded-2xl px-4 py-3 text-sm"
          style={{ background: "var(--card)", border: "1px solid var(--border)" }}
        >
          <img src={imagePreview} alt="" className="h-12 w-12 rounded-lg object-cover" />
          <span style={{ color: "var(--muted)" }}>
            {imageSearching
              ? t("catalog_image_searching")
              : `${t("catalog_image_results_prefix")}${imageResults?.length ?? 0}${t("catalog_image_results_suffix")}`}
          </span>
        </div>
      )}
      {imageError && <div className="error mb-4">{imageError}</div>}
      {searching && <p className="mb-4 text-sm" style={{ color: "var(--muted)" }}>{t("catalog_searching")}</p>}
      {searchResults !== null && !searching && (
        <p className="mb-4 text-sm" style={{ color: "var(--muted)" }}>{searchResults.length}{t("catalog_results_suffix")}</p>
      )}

      {error && <div className="error mb-4">{error}</div>}
      {shown.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          {imageResults ? t("catalog_no_similar") : t("catalog_no_products")}
        </p>
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
                  title={t("catalog_ar_badge_title")}
                >
                  <Box size={12} /> 3D
                </span>
              )}
              {user && (
                <button
                  onClick={(e) => toggleLike(e, p)}
                  className="flex h-7 w-7 items-center justify-center rounded-full shadow"
                  style={{ background: "var(--card)" }}
                  title={p.is_liked ? t("catalog_like_remove") : t("catalog_like_add")}
                >
                  <Heart size={14} fill={p.is_liked ? "currentColor" : "none"} style={{ color: p.is_liked ? "var(--danger)" : "var(--muted)" }} />
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
              {attributeSummary(p) && (
                <span className="text-xs font-medium" style={{ color: "var(--brand-cta-bg)" }}>
                  {attributeSummary(p)}
                </span>
              )}
              <span className="text-xs" style={{ color: "var(--muted)" }}>{p.company_name}</span>
              <PriceTag variant={p.variants[0]} />
            </div>
          </Link>
        ))}
      </div>
    </div>
  );
}
