import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Heart, Factory, Sofa, Image, Box, Sparkles, ShoppingBag, ArrowRight, PackageCheck } from "lucide-react";
import { api } from "../api";
import { addToCart } from "../cart";
import VerifiedCheck from "../components/VerifiedCheck";
import ImageLightbox from "../components/ImageLightbox";
import ModelViewer from "../components/ModelViewer";
import CompanyBadge from "../components/CompanyBadge";
import { useAuth } from "../auth";
import { useLocale } from "../locale";

const slugify = (v) =>
  String(v || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

/** Server render qilgan rasmlar guruhidan tanlangan variantga mosini topadi. */
function pickRenderGroup(renders, variant) {
  if (!renders?.length) return null;
  if (variant) {
    return (
      renders.find((g) => g.variant_id === variant.id) ||
      renders.find((g) => g.slug === slugify(variant.name)) ||
      renders[0]
    );
  }
  return renders[0];
}

const SHOT_ORDER = ["hero", "front", "side", "back", "top"];

const srcSetFor = (sets, fmt) =>
  sets
    ? ["400", "800", "1600"].filter((w) => sets[w]?.[fmt]).map((w) => `${sets[w][fmt]} ${w}w`).join(", ")
    : undefined;

// MUHIM: komponent modul darajasida — render ichida e'lon qilinsa har safar yangi tur
// bo'lib, rasm elementi qayta yaratiladi va har almashishda "reload" kabi miltillaydi.
function Picture({ item, className, sizes, eager = false, alt = "" }) {
  const common = { src: item.src, alt, className, decoding: "async", loading: eager ? "eager" : "lazy" };
  if (!item.sets) return <img {...common} />;
  return (
    <picture>
      <source type="image/avif" srcSet={srcSetFor(item.sets, "avif")} sizes={sizes} />
      <source type="image/webp" srcSet={srcSetFor(item.sets, "webp")} sizes={sizes} />
      <img {...common} />
    </picture>
  );
}

/** Mobil ilovadagi kabi: chapga/o'ngga surib o'tiladigan galereya (scroll-snap), nuqtalar va strelkalar. */
// Mobil ilovadagi kabi izometrik quti: eni / bo'yi / chuqurligi + hajm.
// Avval modelning haqiqiy o'lchami (bbox), bo'lmasa variantniki; 1×1×1 — "kiritilmagan".
function resolveDims(model, variant) {
  let w = parseFloat(model?.bbox_width);
  let h = parseFloat(model?.bbox_height);
  let d = parseFloat(model?.bbox_depth);
  if (![w, h, d].every(Number.isFinite)) {
    if (!variant) return null;
    w = parseFloat(variant.width);
    h = parseFloat(variant.height);
    d = parseFloat(variant.depth);
    if (w === 1 && h === 1 && d === 1) return null;
  }
  return [w, h, d].every((n) => Number.isFinite(n) && n > 0) ? { w, h, d } : null;
}

function DimensionBox({ dims, t }) {
  if (!dims) return null;
  const { w, h, d } = dims;
  const cm = (m) => Math.round(m * 100 * 10) / 10;
  const volume = Math.round(w * h * d * 1000) / 1000;
  // Qutini nisbatan chizamiz (eng uzun tomon ~120px).
  const k = 120 / Math.max(w, h, d);
  const bw = Math.max(w * k, 30);
  const bh = Math.max(h * k, 30);
  const bd = Math.max(d * k * 0.6, 20);
  const ox = 90;
  const oy = 30 + bd;
  const front = `${ox},${oy} ${ox + bw},${oy} ${ox + bw},${oy + bh} ${ox},${oy + bh}`;
  const top = `${ox},${oy} ${ox + bd},${oy - bd} ${ox + bw + bd},${oy - bd} ${ox + bw},${oy}`;
  const side = `${ox + bw},${oy} ${ox + bw + bd},${oy - bd} ${ox + bw + bd},${oy + bh - bd} ${ox + bw},${oy + bh}`;
  const vbW = ox + bw + bd + 90;
  const vbH = oy + bh + 40;
  const stroke = "var(--brand-cta-bg)";
  return (
    <div>
      <label className="label">{t("dim_title")}</label>
      <div className="rounded-xl p-3" style={{ border: "1px solid var(--border)", background: "var(--card)" }}>
        <svg viewBox={`0 0 ${vbW} ${vbH}`} className="mx-auto block w-full max-w-xs" role="img" aria-label={t("dim_title")}>
          <polygon points={top} fill="var(--bg)" stroke={stroke} strokeWidth="1.5" strokeLinejoin="round" />
          <polygon points={side} fill="color-mix(in srgb, var(--muted) 25%, transparent)" stroke={stroke} strokeWidth="1.5" strokeLinejoin="round" />
          <polygon points={front} fill="var(--card)" stroke={stroke} strokeWidth="1.5" strokeLinejoin="round" />
          <text x={ox + bw / 2} y={oy + bh + 22} textAnchor="middle" fontSize="11" fontWeight="600" fill="var(--text)">
            {t("dim_width")} {cm(w)} sm
          </text>
          <text
            x={ox - 12}
            y={oy + bh / 2}
            textAnchor="middle"
            fontSize="11"
            fontWeight="600"
            fill="var(--text)"
            transform={`rotate(-90 ${ox - 12} ${oy + bh / 2})`}
          >
            {t("dim_height")} {cm(h)} sm
          </text>
          <text x={ox + bw + bd + 8} y={oy - bd / 2} fontSize="11" fontWeight="600" fill="var(--text)">
            {t("dim_depth")} {cm(d)} sm
          </text>
        </svg>
        <div className="mt-1 text-center text-xs font-semibold" style={{ color: "var(--muted)" }}>
          {t("dim_volume")}: {volume} m³
        </div>
      </div>
    </div>
  );
}

function GalleryCarousel({ items, index, onIndexChange, onOpen, alt, realLabel, openLabel }) {
  const trackRef = useRef(null);
  const programmatic = useRef(false);

  // Tashqaridan (miniatyura/variant) indeks o'zgarsa — shu slaydga o'tamiz.
  useEffect(() => {
    const el = trackRef.current;
    if (!el || !el.clientWidth) return;
    const current = Math.round(el.scrollLeft / el.clientWidth);
    if (current === index) return;
    programmatic.current = true;
    el.scrollTo({ left: index * el.clientWidth, behavior: index === 0 ? "auto" : "smooth" });
    const t = setTimeout(() => {
      programmatic.current = false;
    }, 450);
    return () => clearTimeout(t);
  }, [index, items.length]);

  const onScroll = () => {
    const el = trackRef.current;
    if (!el || programmatic.current || !el.clientWidth) return;
    const i = Math.round(el.scrollLeft / el.clientWidth);
    if (i !== index && i >= 0 && i < items.length) onIndexChange(i);
  };

  const go = (d) => {
    const next = Math.min(items.length - 1, Math.max(0, index + d));
    if (next !== index) onIndexChange(next);
  };

  return (
    <div className="relative" style={{ background: "var(--card)", borderRadius: 16, border: "1px solid var(--border)" }}>
      <div
        ref={trackRef}
        onScroll={onScroll}
        className="no-scrollbar flex snap-x snap-mandatory overflow-x-auto"
        style={{ scrollbarWidth: "none", borderRadius: 16 }}
      >
        {items.map((item, i) => (
          <button
            key={item.key + i}
            type="button"
            onClick={onOpen}
            aria-label={openLabel}
            className="relative block w-full shrink-0 cursor-zoom-in snap-center"
            style={{ aspectRatio: "1 / 1", background: "var(--card)" }}
          >
            <Picture
              item={item}
              alt={alt}
              sizes="(min-width: 1024px) 600px, 100vw"
              eager={i === 0}
              className={`h-full w-full ${item.real ? "object-cover" : "object-contain"}`}
            />
            {item.real && (
              <span
                className="absolute left-2 top-2 rounded-full px-2.5 py-1 text-xs font-semibold"
                style={{ background: "var(--accent)", color: "var(--on-accent)" }}
              >
                {realLabel}
              </span>
            )}
          </button>
        ))}
      </div>

      {items.length > 1 && (
        <>
          {index > 0 && (
            <button
              type="button"
              aria-label="Oldingi rasm"
              onClick={() => go(-1)}
              className="absolute left-2 top-1/2 hidden h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full md:flex"
              style={{ background: "var(--card)", border: "1px solid var(--border)" }}
            >
              ‹
            </button>
          )}
          {index < items.length - 1 && (
            <button
              type="button"
              aria-label="Keyingi rasm"
              onClick={() => go(1)}
              className="absolute right-2 top-1/2 hidden h-9 w-9 -translate-y-1/2 items-center justify-center rounded-full md:flex"
              style={{ background: "var(--card)", border: "1px solid var(--border)" }}
            >
              ›
            </button>
          )}
          <div className="pointer-events-none absolute bottom-3 left-0 right-0 flex justify-center gap-1.5">
            {items.map((_, i) => (
              <span
                key={i}
                style={{
                  width: i === index ? 18 : 6,
                  height: 6,
                  borderRadius: 999,
                  background: i === index ? "var(--brand-cta-bg)" : "var(--border)",
                  transition: "width .2s ease",
                }}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

export default function ProductDetail() {
  const { id } = useParams();
  const { user } = useAuth();
  const { t } = useLocale();
  const [p, setP] = useState(null);
  const [error, setError] = useState("");
  const [variantId, setVariantId] = useState("");
  const [qty, setQtyState] = useState(1);
  const [added, setAdded] = useState(false);
  // "photo" | "3d" — AR endi alohida, o'ziga xos boshqariladigan holat
  // (pastdagi viewerRef/activateAR), "3d" ko'rinishning ichiga
  // "yashiringan" emas (qarang ModelViewer.jsx — buning sababi).
  const [viewMode, setViewMode] = useState("photo");
  const [modelReady, setModelReady] = useState(false);
  const [arSupported, setArSupported] = useState(null); // null = hali noma'lum
  const [arError, setArError] = useState("");
  const viewerRef = useRef(null);
  // Rasm galereyasi: asosiy rasm + qo'shimcha rasmlar (takrorlarsiz). `imgIdx`
  // sahifadagi joriy rasm — to'liq ekranli galereya ichida almashtirilsa
  // shu ham yangilanadi.
  const [imgIdx, setImgIdx] = useState(0);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [liked, setLiked] = useState(false);
  const [likeBusy, setLikeBusy] = useState(false);
  const [likeError, setLikeError] = useState("");
  const [companyTier, setCompanyTier] = useState(null);

  useEffect(() => {
    api(`/products/${id}/`)
      .then((d) => {
        setP(d);
        setLiked(!!d.is_liked);
        if (d.variants[0]) {
          const wanted = new URLSearchParams(window.location.search).get("variant");
          const match = wanted
            ? d.variants.find((v) => v.id === wanted || slugify(v.name) === wanted)
            : null;
          setVariantId((match || d.variants[0]).id);
        }
        if (d.company_slug) {
          api(`/companies/${d.company_slug}/`)
            .then((c) => setCompanyTier(c.tier))
            .catch(() => {});
        }
      })
      .catch((e) => setError(e.message));
  }, [id]);

  const variant = p?.variants.find((v) => v.id === variantId);
  // Ko'p materialli mahsulotlarda variant o'zining alohida 3D faylini olishi
  // mumkin (masalan eshikli shkaf) — bo'lsa o'sha ishlatiladi, aks holda
  // mahsulotning umumiy modeliga runtime rang/tekstura tint qo'llanadi.
  const hasOwnModel = variant?.model3d?.glb_url && variant.model3d.status === "ready";
  const activeModel3d = hasOwnModel ? variant.model3d : p?.model3d;

  // Variant almashtirilganda 3D ko'rinishi mos model mavjud bo'lmasa yopiladi
  useEffect(() => {
    if (!activeModel3d?.glb_url) setViewMode("photo");
    setModelReady(false);
    setArSupported(null);
    setArError("");
  }, [variantId]);

  // AR tugmasi model TO'LIQ yuklanmaguncha (modelReady) o'chirilgan turadi
  // (qarang pastdagi <button disabled={!modelReady}>) — shu bois bosilgan
  // payt activateAR() har doim SHU o'sha click hodisasi ichida, kechiktirmay
  // chaqiriladi. Bu muhim: Safari'da AR Quick Look (USDZ) faqat haqiqiy
  // foydalanuvchi bosishining o'zi (sinxron chaqiruv) bilan ochiladi — avval
  // (effekt/keyinroq) chaqirilsa, Safari buni oddiy sahifa navigatsiyasi deb
  // qabul qilib, .usdz faylini yuklab (progress-bar bilan) ilova holatini
  // "buzib" qo'yardi. ModelViewer endi Photo rejimida ham DOMdan olib
  // tashlanmaydi (faqat CSS bilan yashiriladi — qarang pastdagi JSX), shuning
  // uchun model fonoda oldindan yuklanib ulguradi va AR tugmasi tezda yoqiladi.
  const startAR = () => {
    setArError("");
    if (arSupported === false) {
      setArError(t("product_ar_unsupported"));
      return;
    }
    setViewMode("3d");
    viewerRef.current?.activateAR();
  };

  // O'lcham endi mijoz tomonidan kiritilmaydi — variantning o'zida
  // saqlangan standart o'lcham (odatda 1x1x1) ishlatiladi, narx shu bilan
  // qat'iy (variant narxi) bo'lib qoladi, mijoz uchun "hajmga qarab
  // hisoblash" tushunchasi umuman ko'rinmaydi.
  const price = useMemo(() => {
    if (!variant) return null;
    const unit = variant.discount_active ? parseFloat(variant.effective_base_price) : parseFloat(variant.base_price);
    return Math.round(unit * variant.width * variant.height * variant.depth);
  }, [variant]);

  // Chegirmasiz narx — faqat chegirma faol bo'lganda chizib ko'rsatish uchun.
  const originalPrice = useMemo(() => {
    if (!variant || !variant.discount_active) return null;
    return Math.round(parseFloat(variant.base_price) * variant.width * variant.height * variant.depth);
  }, [variant]);

  const toggleLike = async () => {
    setLikeError("");
    if (!user) {
      setLikeError(t("product_like_login_required"));
      return;
    }
    setLikeBusy(true);
    try {
      const res = await api("/likes/toggle/", { method: "POST", body: { product: p.id } });
      setLiked(res.liked);
    } catch (e) {
      setLikeError(e.message);
    } finally {
      setLikeBusy(false);
    }
  };

  // Galereya: avval server render (hero -> front -> side -> back -> top), keyin sotuvchining haqiqiy fotolari.
  const renderGroup = pickRenderGroup(p?.renders, variant);
  const renderItems = (renderGroup?.shots || [])
    .slice()
    .sort((a, b) => SHOT_ORDER.indexOf(a.key) - SHOT_ORDER.indexOf(b.key))
    .map((sh) => ({
      key: sh.key,
      src: sh.urls?.["1600"]?.webp,
      sets: sh.urls,
      real: false,
    }))
    .filter((it) => it.src);
  const realItems = [...new Set([p?.image_url, ...(p?.images || []).map((im) => im.image_url)].filter(Boolean))]
    // render hero avtomatik Product.image ga ham yoziladi — takrorlanmasin
    .filter((src) => !renderItems.length || src !== p?.image_url)
    .map((src) => ({ key: src, src, sets: null, real: true }));
  const items = [...renderItems, ...realItems];
  const gallery = items.map((it) => it.src);

  // Variant almashganda galereya shu variantning birinchi rasmidan boshlansin.
  useEffect(() => {
    setImgIdx(0);
  }, [variantId]);

  // URL'ni tanlangan variant bilan sinxronlash (?variant=slug), sahifani qayta yuklamasdan.
  useEffect(() => {
    if (!variant) return;
    const url = new URL(window.location.href);
    const slug = slugify(variant.name);
    if (url.searchParams.get("variant") === slug) return;
    url.searchParams.set("variant", slug);
    window.history.replaceState(null, "", url);
  }, [variant]);

  // Keyingi rasmlarni oldindan yuklaymiz — almashganda "qayta yuklanish" miltillashi bo'lmasin.
  useEffect(() => {
    gallery.forEach((src) => {
      const im = new window.Image();
      im.src = src;
    });
  }, [gallery.join("|")]); // eslint-disable-line react-hooks/exhaustive-deps

  if (error && !p)
    return (
      <div className="mx-auto max-w-6xl px-4 py-8">
        <div className="error">{error}</div>
      </div>
    );
  if (!p)
    return (
      <div className="mx-auto max-w-6xl px-4 py-8" style={{ color: "var(--muted)" }}>
        {t("product_loading")}
      </div>
    );

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <div className="mb-1 flex items-start justify-between gap-3">
        <h1 className="text-2xl font-bold">{p.name_uz}</h1>
        <button
          onClick={toggleLike}
          disabled={likeBusy}
          className="shrink-0 rounded-full p-2 text-xl transition"
          style={{ border: "1px solid var(--border)", background: "var(--card)" }}
          title={liked ? t("product_like_remove") : t("product_like_add")}
        >
          <Heart size={18} fill={liked ? "currentColor" : "none"} style={{ color: liked ? "var(--danger)" : "var(--muted)" }} />
        </button>
      </div>
      {likeError && <div className="error mb-4">{likeError}</div>}
      <Link
        to={`/shop/${p.company_slug}`}
        className="card mb-6 flex items-center gap-3 !p-3 transition hover:shadow-md"
      >
        <div
          className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
          style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
        >
          <Factory size={18} />
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <span className="inline-flex items-center gap-1 text-sm font-semibold">
              {p.company_name}
              <VerifiedCheck verified={p.company_is_verified} />
            </span>
            <CompanyBadge tier={companyTier} size="sm" />
          </div>
          <span className="inline-flex items-center gap-0.5 text-xs" style={{ color: "var(--secondary)" }}>
            {t("product_view_shop")} <ArrowRight size={12} />
          </span>
        </div>
      </Link>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        {/* Rasm / 3D */}
        <div style={{ position: "relative" }}>
          {activeModel3d?.glb_url && (
            // `display:none` bilan yashirish o'lchami 0x0 qilib qo'yadi —
            // ba'zi mobil brauzerlarda bu model-viewer'ning (o'lchamsiz
            // canvas'ga) hech qachon to'liq yuklanmay qolishiga sabab bo'ldi
            // ("AR tayyorlanmoqda" cheksiz turib qolishi). Shuning uchun
            // o'lchamini (360px balandlik) saqlab, faqat `visibility` bilan
            // ko'rinmas qilinadi va sahifa oqimidan `position:absolute`
            // orqali chiqarib qo'yiladi (bo'sh joy qoldirmasligi uchun).
            <div
              style={
                viewMode === "3d"
                  ? { position: "relative" }
                  : { position: "absolute", top: 0, left: 0, right: 0, visibility: "hidden", pointerEvents: "none" }
              }
            >
              <ModelViewer
                ref={viewerRef}
                glb={activeModel3d.glb_url}
                usdz={activeModel3d.usdz_url}
                alt={`${p.name_uz} — ${variant.name}`}
                poster={p.image_url}
                colorHex={hasOwnModel ? null : variant.color_hex}
                textureUrl={hasOwnModel ? null : variant.texture_url}
                onReadyChange={setModelReady}
                onArSupportedChange={setArSupported}
              />
            </div>
          )}
          {!(activeModel3d?.glb_url && viewMode === "3d") && (
            gallery.length > 0 ? (
              <GalleryCarousel
                items={items}
                index={Math.min(imgIdx, items.length - 1)}
                onIndexChange={setImgIdx}
                onOpen={() => setLightboxOpen(true)}
                alt={p.name_uz}
                realLabel={t("product_real_photo")}
                openLabel={t("gallery_open")}
              />
            ) : (
              <div
                className="card flex h-72 w-full items-center justify-center"
                style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
              >
                <Sofa size={48} />
              </div>
            )
          )}

          {activeModel3d?.glb_url && (
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                className={viewMode !== "3d" ? "btn btn-brand inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                onClick={() => setViewMode("photo")}
              >
                <Image size={13} /> {t("product_photo_tab")}
              </button>
              <button
                className={viewMode === "3d" ? "btn btn-brand inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                onClick={() => setViewMode("3d")}
              >
                <Box size={13} /> 3D
              </button>
              {arSupported !== false && (
                <button
                  className="btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                  disabled={!modelReady}
                  onClick={startAR}
                >
                  <Sparkles size={13} />
                  {modelReady ? "AR" : t("product_ar_loading")}
                </button>
              )}
            </div>
          )}
          {arError && <div className="error mt-2">{arError}</div>}

          {lightboxOpen && gallery.length > 0 && (
            <ImageLightbox
              images={gallery}
              index={Math.min(imgIdx, gallery.length - 1)}
              onIndexChange={setImgIdx}
              onClose={() => setLightboxOpen(false)}
              alt={p.name_uz}
            />
          )}
        </div>

        {/* Kalkulyator */}
        <div className="card flex h-fit flex-col gap-4 p-6">
          {p.variants.length > 0 ? (
            <>
              <div>
                <label className="label">{t("product_variant_field_label")}</label>
                <div className="flex flex-wrap gap-2" role="radiogroup" aria-label={t("product_variant_field_label")}>
                  {p.variants.map((v) => {
                    const selected = v.id === variantId;
                    return (
                      <button
                        key={v.id}
                        type="button"
                        role="radio"
                        aria-checked={selected}
                        onClick={() => setVariantId(v.id)}
                        className="inline-flex items-center gap-2 rounded-full px-3.5 py-2 text-sm font-semibold transition"
                        style={{
                          background: selected ? "var(--brand-cta-bg)" : "var(--card)",
                          color: selected ? "var(--brand-cta-text)" : "var(--text)",
                          border: `1px solid ${selected ? "var(--brand-cta-bg)" : "var(--border)"}`,
                        }}
                      >
                        {(v.texture_url || v.color_hex) && (
                          <span
                            className="h-4 w-4 rounded-full"
                            style={{
                              background: v.texture_url ? `url(${v.texture_url}) center/cover` : v.color_hex,
                              border: "1px solid var(--border)",
                            }}
                          />
                        )}
                        {v.name}
                      </button>
                    );
                  })}
                </div>
                {variant && (
                  variant.available_quantity > 0 ? (
                    <span
                      className="mt-2 inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold text-white"
                      style={{ background: "var(--success)" }}
                    >
                      <PackageCheck size={14} /> {variant.available_quantity}{t("product_stock_available_suffix")}
                    </span>
                  ) : (
                    <p className="mt-1.5 text-xs" style={{ color: "var(--muted)" }}>
                      {t("product_stock_unavailable")}
                    </p>
                  )
                )}
              </div>
              <DimensionBox dims={resolveDims(activeModel3d, variant)} t={t} />
              {p.description && <p className="text-sm">{p.description}</p>}
              <div>
                <label className="label">{t("product_qty_label")}</label>
                <input
                  className="input !w-24"
                  type="number"
                  min="1"
                  value={qty}
                  onChange={(e) => setQtyState(Math.max(1, parseInt(e.target.value) || 1))}
                />
              </div>
              {price !== null && (
                <div
                  className="rounded-xl p-4"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  <div className="flex items-center gap-2">
                    <div className="text-xs" style={{ color: "var(--muted)" }}>{t("product_approx_price")}</div>
                    {variant.discount_active && (
                      <span className="badge" style={{ background: "var(--accent)", color: "var(--on-accent)" }}>
                        -{Number(variant.discount_percent)}%
                      </span>
                    )}
                  </div>
                  <div className="flex items-baseline gap-2">
                    {originalPrice !== null && (
                      <span className="text-base line-through" style={{ color: "var(--muted)" }}>
                        {(originalPrice * qty).toLocaleString()} so'm
                      </span>
                    )}
                    <div className="text-2xl font-bold">{(price * qty).toLocaleString()} so'm</div>
                  </div>
                  {variant.discount_active && (
                    <div className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
                      {t("product_discount_prefix")}{new Date(variant.discount_ends_at).toLocaleString("uz-UZ")}{t("product_discount_suffix")}
                    </div>
                  )}
                </div>
              )}
              {added ? (
                <div className="flex gap-2">
                  <Link to="/cart" className="btn btn-brand inline-flex flex-1 items-center justify-center gap-1.5">
                    <ShoppingBag size={15} /> {t("product_go_to_cart")}
                  </Link>
                  <button className="btn-ghost" onClick={() => setAdded(false)}>{t("product_add_more")}</button>
                </div>
              ) : (
                <button
                  className="btn btn-brand inline-flex items-center justify-center gap-1.5"
                  disabled={price === null}
                  onClick={() => {
                    addToCart({
                      productId: p.id,
                      productName: p.name_uz,
                      companyId: p.company,
                      companyName: p.company_name,
                      image: p.image_url || p.images?.[0]?.image_url,
                      variantId: variant.id,
                      variantName: variant.name,
                      isCustomSize: false,
                      m3Price: variant.discount_active ? parseFloat(variant.effective_base_price) : parseFloat(variant.base_price),
                      m3OriginalPrice: variant.discount_active ? parseFloat(variant.base_price) : null,
                      discountPercent: variant.discount_active ? Number(variant.discount_percent) : null,
                      width: variant.width,
                      height: variant.height,
                      depth: variant.depth,
                      qty,
                    });
                    setAdded(true);
                  }}
                >
                  <ShoppingBag size={15} /> {t("product_add_to_cart")}
                </button>
              )}
              {error && <div className="error">{error}</div>}
            </>
          ) : (
            <p className="text-sm" style={{ color: "var(--muted)" }}>{t("product_no_variants")}</p>
          )}
        </div>
      </div>
    </div>
  );
}
