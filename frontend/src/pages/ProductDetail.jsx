import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Heart, Factory, Sofa, Image, Box, ShoppingBasket, ArrowRight } from "lucide-react";
import { api } from "../api";
import { addToCart } from "../cart";
import ModelViewer from "../components/ModelViewer";
import CompanyBadge from "../components/CompanyBadge";
import { useAuth } from "../auth";
import { useLocale } from "../locale";

export default function ProductDetail() {
  const { id } = useParams();
  const { user } = useAuth();
  const { t } = useLocale();
  const [p, setP] = useState(null);
  const [error, setError] = useState("");
  const [variantId, setVariantId] = useState("");
  const [qty, setQtyState] = useState(1);
  const [added, setAdded] = useState(false);
  const [show3d, setShow3d] = useState(false);
  const [liked, setLiked] = useState(false);
  const [likeBusy, setLikeBusy] = useState(false);
  const [likeError, setLikeError] = useState("");
  const [companyTier, setCompanyTier] = useState(null);

  useEffect(() => {
    api(`/products/${id}/`)
      .then((d) => {
        setP(d);
        setLiked(!!d.is_liked);
        if (d.variants[0]) setVariantId(d.variants[0].id);
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

  // Variant almashtirilganda AR ko'rinishi mos model mavjud bo'lmasa yopiladi
  useEffect(() => {
    if (!activeModel3d?.glb_url) setShow3d(false);
  }, [variantId]);

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
            <span className="text-sm font-semibold">{p.company_name}</span>
            <CompanyBadge tier={companyTier} size="sm" />
          </div>
          <span className="inline-flex items-center gap-0.5 text-xs" style={{ color: "var(--secondary)" }}>
            {t("product_view_shop")} <ArrowRight size={12} />
          </span>
        </div>
      </Link>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        {/* Rasm / 3D */}
        <div>
          {show3d && activeModel3d?.glb_url ? (
            <ModelViewer
              glb={activeModel3d.glb_url}
              usdz={activeModel3d.usdz_url}
              alt={`${p.name_uz} — ${variant.name}`}
              poster={p.image_url}
              colorHex={hasOwnModel ? null : variant.color_hex}
              textureUrl={hasOwnModel ? null : variant.texture_url}
            />
          ) : (p.image_url || p.images?.[0]?.image_url) ? (
            <img src={p.image_url || p.images[0].image_url} alt={p.name_uz} className="card w-full object-cover" />
          ) : (
            <div
              className="card flex h-72 w-full items-center justify-center"
              style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
            >
              <Sofa size={48} />
            </div>
          )}

          {activeModel3d?.glb_url && (
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                className={show3d ? "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn btn-brand inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                onClick={() => setShow3d(false)}
              >
                <Image size={13} /> {t("product_photo_tab")}
              </button>
              <button
                className={show3d ? "btn btn-brand inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" : "btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"}
                onClick={() => setShow3d(true)}
              >
                <Box size={13} /> {variant.name}{t("product_view_3d_ar_suffix")}
              </button>
            </div>
          )}

          {p.images.length > 0 && (
            <div className="mt-3 flex flex-wrap gap-2">
              {p.images.map((im) => (
                <img key={im.id} src={im.image_url} alt="" className="h-20 w-20 rounded-xl object-cover" />
              ))}
            </div>
          )}
        </div>

        {/* Kalkulyator */}
        <div className="card flex h-fit flex-col gap-4 p-6">
          {p.description && <p className="text-sm">{p.description}</p>}
          {p.variants.length > 0 ? (
            <>
              <div>
                <label className="label">{t("product_variant_field_label")}</label>
                <div className="flex items-center gap-2">
                  {variant?.color_hex && (
                    <span
                      className="h-8 w-8 shrink-0 rounded-lg"
                      style={{ background: variant.texture_url ? `url(${variant.texture_url}) center/cover` : variant.color_hex, border: "1px solid var(--border)" }}
                      title={variant.name}
                    />
                  )}
                  <select className="input" value={variantId} onChange={(e) => setVariantId(e.target.value)}>
                    {p.variants.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.name} — {v.discount_active
                          ? `${Number(v.effective_base_price).toLocaleString()} so'm (-${Number(v.discount_percent)}%)`
                          : `${Number(v.base_price).toLocaleString()} so'm`}
                        {(v.model3d?.glb_url || p.model3d?.glb_url) ? " · AR" : ""}
                      </option>
                    ))}
                  </select>
                </div>
                {variant && (
                  <p className="mt-1.5 text-xs" style={{ color: variant.available_quantity > 0 ? "var(--success)" : "var(--muted)" }}>
                    {variant.available_quantity > 0
                      ? `${variant.available_quantity}${t("product_stock_available_suffix")}`
                      : t("product_stock_unavailable")}
                  </p>
                )}
              </div>
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
                      <span className="badge" style={{ background: "var(--danger)", color: "#fff" }}>
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
                    <ShoppingBasket size={15} /> {t("product_go_to_cart")}
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
                  <ShoppingBasket size={15} /> {t("product_add_to_cart")}
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
