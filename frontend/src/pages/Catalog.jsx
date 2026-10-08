import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import {
  ArrowLeft, Armchair, Baby, BedDouble, Box, Camera, CookingPot, DoorClosed, Heart, Lamp, LampDesk, Library,
  MapPinOff, PackageCheck, RectangleHorizontal, Search, Sofa, Store, Trees, ArrowRight, X,
} from "lucide-react";
import { api } from "../api";
import { coordsParams, useGeolocation } from "../location";
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

// Kategoriya nomi/slug'idagi kalit so'zga qarab ikonka (backend'da ikonka maydoni yo'q).
const CATEGORY_ICONS = [
  [["kitob", "javon", "polka", "shelf"], Library],
  [["divan", "sofa", "yumshoq", "mehmon", "zal"], Sofa],
  [["karavat", "krovat", "yotoq", "bed", "matras"], BedDouble],
  [["shkaf", "garderob", "jovon", "komod"], DoorClosed],
  [["stol", "table", "jurnal"], RectangleHorizontal],
  [["oshxona", "kuxn", "kitchen"], CookingPot],
  [["bolalar", "bola", "kids", "child"], Baby],
  [["bog", "tashqi", "garden", "outdoor"], Trees],
  [["ofis", "office"], LampDesk],
  [["yoritgich", "chiroq", "lamp"], Lamp],
  [["kreslo", "stul", "chair"], Armchair],
];
function categoryIcon(c) {
  const k = `${c.slug || ""} ${c.name_uz || ""}`.toLowerCase();
  for (const [words, Icon] of CATEGORY_ICONS) {
    if (words.some((w) => k.includes(w))) return Icon;
  }
  return Sofa;
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
  const geo = useGeolocation();
  const [productsLoaded, setProductsLoaded] = useState(false);

  useEffect(() => {
    const q = search.trim();
    if (!q) {
      setSearchResults(null);
      return;
    }
    setSearching(true);
    const timer = setTimeout(() => {
      api(`/products/?search=${encodeURIComponent(q)}${coordsParams(geo, "&")}`)
        .then((d) => setSearchResults(d.results || []))
        .catch((e) => setError(e.message))
        .finally(() => setSearching(false));
    }, 350);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, geo.status, geo.lat, geo.lng]);

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
      if (geo.status === "granted") {
        fd.append("lat", geo.lat);
        fd.append("lng", geo.lng);
      }
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

  useEffect(() => {
    api("/categories/")
      .then((d) => setCategories(d.results || []))
      .catch(() => {});
  }, []);

  // Mahsulotlar joylashuvga bog'liq (firma xizmat radiusi, serverda
  // filtrlanadi) — joylashuv aniqlanmaguncha yoki ruxsat berilmaguncha
  // so'rov yuborilmaydi va mahsulotlar ko'rsatilmaydi.
  useEffect(() => {
    if (geo.status !== "granted") {
      setProducts([]);
      setProductsLoaded(false);
      return;
    }
    setProductsLoaded(false);
    api(`/products/${coordsParams(geo)}`)
      .then((d) => setProducts(d.results || []))
      .catch((e) => setError(e.message))
      .finally(() => setProductsLoaded(true));
  }, [geo.status, geo.lat, geo.lng]); // eslint-disable-line react-hooks/exhaustive-deps

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

      {geo.status !== "granted" ? (
        <StateMessage
          icon={geo.status === "loading" ? null : MapPinOff}
          title={t(geo.status === "loading" ? "loc_checking" : geo.status === "denied" ? "loc_required_title" : "loc_unavailable_title")}
          body={geo.status === "loading" ? null : t(geo.status === "denied" ? "loc_required_body" : "loc_unavailable_body")}
          hint={geo.status === "denied" ? t("loc_browser_hint") : null}
          actionLabel={geo.status === "loading" ? null : t(geo.status === "denied" ? "loc_allow" : "loc_retry")}
          onAction={geo.retry}
        />
      ) : (
      <>
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

      {/* Kolleksiyalar — mobil ilovadagi aylana belgili kategoriya qatori
          bilan bir xil ko'rinish (oldingi tekis pill-tugmalar o'rniga) */}
      {!isSearching && !(productsLoaded && products.length === 0) && (
        <div className="mb-6">
          <h2 className="mb-0.5 text-lg font-bold">{t("catalog_collections_title")}</h2>
          <p className="mb-3 text-sm" style={{ color: "var(--muted)" }}>
            {t("catalog_collections_subtitle")}
          </p>
          <div className="no-scrollbar flex gap-4 overflow-x-auto pb-1">
            <button
              className="flex flex-shrink-0 flex-col items-center gap-2"
              style={{ width: 78 }}
              onClick={() => setCat("")}
            >
              <span
                className="flex h-16 w-16 items-center justify-center rounded-full transition"
                style={
                  cat === ""
                    ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                    : { background: "var(--primary)", color: "var(--text)" }
                }
              >
                <Sofa size={26} />
              </span>
              <span className="text-center text-xs font-semibold leading-tight">{t("catalog_filter_all")}</span>
            </button>
            {categories.map((c) => (
              <button
                key={c.id}
                className="flex flex-shrink-0 flex-col items-center gap-2"
                style={{ width: 78 }}
                onClick={() => setCat(c.id)}
              >
                <span
                  className="flex h-16 w-16 items-center justify-center rounded-full transition"
                  style={
                    cat === c.id
                      ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                      : { background: "var(--primary)", color: "var(--text)" }
                  }
                >
                  {(() => {
                    const CatIcon = categoryIcon(c);
                    return <CatIcon size={26} />;
                  })()}
                </span>
                <span className="line-clamp-2 text-center text-xs font-semibold leading-tight">{c.name_uz}</span>
              </button>
            ))}
          </div>
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
      {shown.length === 0 && productsLoaded && !isSearching && !cat && products.length === 0 ? (
        <StateMessage icon={Store} title={t("loc_no_firms")} body={t("loc_no_firms_hint")} />
      ) : (
        shown.length === 0 && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>
            {imageResults ? t("catalog_no_similar") : t("catalog_no_products")}
          </p>
        )
      )}

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {shown.map((p) => (
          <Link
            to={`/products/${p.id}`}
            key={p.id}
            className="card group relative overflow-hidden transition hover:border-[var(--brand-secondary)] hover:shadow-md"
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
            <div className="relative">
              {(p.image_url || p.images?.[0]?.image_url) ? (
                <img
                  src={p.image_url || p.images[0].image_url}
                  alt={p.name_uz}
                  loading="lazy"
                  className="aspect-[4/3] w-full bg-white object-contain p-3"
                />
              ) : (
                <div
                  className="flex aspect-[4/3] w-full items-center justify-center"
                  style={{ background: "var(--primary)", color: "var(--disabled)" }}
                >
                  <Sofa size={36} />
                </div>
              )}
              {Number(p.available_quantity) > 0 && (
                <span
                  className="absolute bottom-2 left-2 inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-bold text-white shadow"
                  style={{ background: "var(--success)" }}
                >
                  <PackageCheck size={13} /> {p.available_quantity}{t("product_stock_available_suffix")}
                </span>
              )}
            </div>
            <div className="flex flex-col gap-1 p-4">
              <span className="line-clamp-2 text-sm font-semibold leading-snug">{p.name_uz}</span>
              {attributeSummary(p) && (
                <span className="text-xs font-medium" style={{ color: "var(--brand-secondary)" }}>
                  {attributeSummary(p)}
                </span>
              )}
              <span className="text-xs" style={{ color: "var(--muted)" }}>{p.company_name}</span>
              <PriceTag variant={p.variants[0]} />
            </div>
          </Link>
        ))}
      </div>
      </>
      )}
    </div>
  );
}

function StateMessage({ icon: Icon, title, body, hint, actionLabel, onAction }) {
  return (
    <div className="mx-auto flex max-w-md flex-col items-center gap-3 px-4 py-16 text-center">
      <div
        className="flex h-16 w-16 items-center justify-center rounded-full"
        style={{ background: "color-mix(in srgb, var(--primary) 35%, transparent)" }}
      >
        {Icon ? <Icon size={28} /> : <div className="h-7 w-7 animate-spin rounded-full border-2 border-current border-t-transparent opacity-60" />}
      </div>
      <h2 className="text-lg font-bold">{title}</h2>
      {body && <p className="text-sm" style={{ color: "var(--muted)" }}>{body}</p>}
      {hint && <p className="text-xs" style={{ color: "var(--muted)" }}>{hint}</p>}
      {actionLabel && (
        <button className="btn btn-brand mt-2" onClick={onAction}>
          {actionLabel}
        </button>
      )}
    </div>
  );
}
