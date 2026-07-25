import { useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  ArrowLeft, ArrowUp, ArrowDown, Boxes, Check, CheckCircle2,
  Circle, Eye, ExternalLink, FileBox, Image as ImageIcon, Images, Link2,
  Lock, MoreHorizontal, Palette, Share2, Sparkles, Trash2, Unlock, Upload,
  Workflow,
} from "lucide-react";
import { api } from "../../api";
import { portalURLFor } from "../../portal";
import ModelViewer from "../../components/ModelViewer";
import { POSITIONS } from "../../positions";

// Bu sahifa o'z ichida mustaqil "enterprise" rang tizimidan foydalanadi —
// platformaning umumiy amber brendi (sidebar, boshqa sahifalar) o'zgarishsiz
// qoladi. CSS custom property'larni shu sahifa ildizida qayta belgilab,
// mavjud .btn/.input/.card/.label util klasslarining o'zini qayta ishlatamiz
// (ular allaqachon shu o'zgaruvchilarga bog'langan) — global uslubga tegmasdan.
const ENT = {
  bg: "#F7F8FA",
  card: "#FFFFFF",
  border: "#E5E7EB",
  primary: "#2563EB",
  success: "#16A34A",
  warning: "#F59E0B",
  danger: "#DC2626",
  text: "#111827",
  muted: "#6B7280",
};

const ENT_VARS = {
  "--bg": ENT.bg,
  "--card": ENT.card,
  "--border": ENT.border,
  "--text": ENT.text,
  "--muted": ENT.muted,
  "--secondary": ENT.primary,
  "--primary": ENT.primary,
  "--primary-deep": "#FFFFFF",
  "--brand-cta-bg": ENT.primary,
  "--brand-cta-text": "#FFFFFF",
  "--shadow": "0 1px 2px rgba(16,24,40,0.04)",
};

const PHOTO_REQUIREMENT = {
  required: "Majburiy",
  optional: "Ixtiyoriy",
  disabled: "Kerak emas",
};

const TABS = [
  { key: "general", label: "Umumiy", icon: FileBox },
  { key: "media", label: "Media", icon: ImageIcon },
  { key: "model", label: "3D model", icon: Boxes },
  { key: "variants", label: "Variantlar", icon: Palette },
  { key: "production", label: "Ishlab chiqarish", icon: Workflow },
  { key: "sharing", label: "Ulashish", icon: Share2 },
];

function formatDate(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("uz-UZ", { year: "numeric", month: "short", day: "numeric" });
}

function computeCompleteness(product, steps) {
  const items = [
    { key: "general", label: "Umumiy ma'lumot", done: !!(product.name_uz && product.category) },
    { key: "images", label: "Rasmlar", done: !!product.image_url },
    { key: "variants", label: "Variantlar", done: product.variants.length > 0 },
    { key: "model", label: "3D model", done: product.model3d?.status === "ready" },
    { key: "production", label: "Ishlab chiqarish bosqichlari", done: (steps || []).length > 0 },
    { key: "video", label: "Video", done: !!product.video_url },
  ];
  const done = items.filter((i) => i.done).length;
  return { items, done, total: items.length, percent: Math.round((done / items.length) * 100) };
}

/**
 * Bitta mahsulotni to'liq tahrirlash sahifasi — enterprise ERP uslubida:
 * sticky hero header, tab-navigatsiya (bitta bo'lim bir vaqtda ko'rinadi) va
 * ikki ustunli joylashuv (chapda tahrirlanadigan formalar, o'ngda doim
 * ko'rinadigan qisqa ma'lumot paneli). Uzoq bitta-varaq forma o'rniga.
 */
export default function FirmaProductDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [categories, setCategories] = useState([]);
  const [steps, setSteps] = useState(null);
  const [error, setError] = useState("");
  const [tab, setTab] = useState("general");
  const [menuOpen, setMenuOpen] = useState(false);

  const load = () =>
    Promise.all([
      api(`/products/${id}/`),
      api("/categories/"),
      api(`/products/${id}/workflow-steps/`).catch(() => ({ results: [] })),
    ])
      .then(([p, cats, wf]) => {
        setProduct(p);
        setCategories(cats.results || []);
        setSteps(wf.results || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  const remove = async () => {
    if (!confirm(`"${product.name_uz}" o'chirilsinmi?`)) return;
    try {
      await api(`/products/${id}/`, { method: "DELETE" });
      navigate("/products");
    } catch (err) {
      setError(err.message);
    }
  };

  const togglePublish = async () => {
    try {
      const updated = await api(`/products/${id}/`, { method: "PATCH", body: { is_published: !product.is_published } });
      setProduct(updated);
    } catch (err) {
      setError(err.message);
    }
  };

  if (error) return <div className="error">{error}</div>;
  if (!product) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  const completeness = computeCompleteness(product, steps);

  return (
    <div style={{ ...ENT_VARS, background: ENT.bg, margin: "-24px", minHeight: "100%" }}>
      <HeroHeader
        product={product}
        completeness={completeness}
        menuOpen={menuOpen}
        setMenuOpen={setMenuOpen}
        onTogglePublish={togglePublish}
        onDelete={remove}
      />

      <TabsNav tab={tab} setTab={setTab} product={product} steps={steps} />

      <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: 20, padding: "20px 24px 60px", maxWidth: 1400, margin: "0 auto" }} className="ent-grid">
        <div style={{ display: "flex", flexDirection: "column", gap: 16, minWidth: 0 }}>
          {tab === "general" && <GeneralTab product={product} categories={categories} onDone={load} />}
          {tab === "media" && <MediaTab product={product} onDone={load} />}
          {tab === "model" && <ModelTab product={product} onDone={load} />}
          {tab === "variants" && <VariantsTab product={product} onDone={load} />}
          {tab === "production" && <ProductionTab product={product} steps={steps} onStepsChange={load} />}
          {tab === "sharing" && <SharingTab product={product} onDone={load} />}
        </div>
        <RightPanel product={product} completeness={completeness} />
      </div>

      <style>{`
        @media (min-width: 1080px) {
          .ent-grid { grid-template-columns: 1fr 320px !important; align-items: start; }
        }
        @keyframes ent-indeterminate {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(250%); }
        }
      `}</style>
    </div>
  );
}

// ============================== Bo'sh yordamchi komponentlar ==============================

function Pill({ tone = "muted", children, icon: Icon }) {
  const map = {
    success: { bg: "rgba(22,163,74,0.1)", fg: ENT.success },
    warning: { bg: "rgba(245,158,11,0.12)", fg: ENT.warning },
    danger: { bg: "rgba(220,38,38,0.1)", fg: ENT.danger },
    primary: { bg: "rgba(37,99,235,0.1)", fg: ENT.primary },
    muted: { bg: "#F1F2F4", fg: ENT.muted },
  };
  const c = map[tone] || map.muted;
  return (
    <span
      style={{
        display: "inline-flex", alignItems: "center", gap: 4, padding: "3px 9px",
        borderRadius: 999, fontSize: 12, fontWeight: 600, background: c.bg, color: c.fg, whiteSpace: "nowrap",
      }}
    >
      {Icon && <Icon size={11} />} {children}
    </span>
  );
}

function Card({ title, description, icon: Icon, children, actions }) {
  return (
    <section style={{ background: ENT.card, border: `1px solid ${ENT.border}`, borderRadius: 14 }}>
      {(title || actions) && (
        <div
          style={{
            padding: "16px 20px", borderBottom: `1px solid ${ENT.border}`,
            display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 12, flexWrap: "wrap",
          }}
        >
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              {Icon && <Icon size={16} style={{ color: ENT.muted }} />}
              <h3 style={{ margin: 0, fontSize: 14, fontWeight: 600, color: ENT.text }}>{title}</h3>
            </div>
            {description && <p style={{ margin: "4px 0 0", fontSize: 12.5, color: ENT.muted, maxWidth: 560 }}>{description}</p>}
          </div>
          {actions}
        </div>
      )}
      <div style={{ padding: 20 }}>{children}</div>
    </section>
  );
}

function EntButton({ children, variant = "primary", onClick, type = "button", disabled, small }) {
  const base = {
    display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 6,
    borderRadius: 8, fontWeight: 600, cursor: disabled ? "default" : "pointer",
    fontSize: small ? 12.5 : 13.5, padding: small ? "6px 10px" : "8px 14px",
    opacity: disabled ? 0.55 : 1, transition: "filter .1s", border: "1px solid transparent",
  };
  const styles = {
    primary: { ...base, background: ENT.primary, color: "#fff" },
    ghost: { ...base, background: "#fff", color: ENT.text, border: `1px solid ${ENT.border}` },
    danger: { ...base, background: "#fff", color: ENT.danger, border: `1px solid #FCA5A5` },
  };
  return (
    <button type={type} disabled={disabled} onClick={onClick} style={styles[variant]}
      onMouseEnter={(e) => !disabled && (e.currentTarget.style.filter = "brightness(0.96)")}
      onMouseLeave={(e) => (e.currentTarget.style.filter = "none")}
    >
      {children}
    </button>
  );
}

function ProgressBar({ percent, height = 6 }) {
  return (
    <div style={{ width: "100%", height, borderRadius: height / 2, background: ENT.border, overflow: "hidden" }}>
      <div style={{ width: `${percent}%`, height: "100%", background: ENT.primary, borderRadius: height / 2, transition: "width .2s" }} />
    </div>
  );
}

function Dropzone({ hint, accept, onFile, previewUrl, currentLabel, busy }) {
  const [dragOver, setDragOver] = useState(false);
  const [localFile, setLocalFile] = useState(null);
  const inputRef = useRef(null);

  const handleFiles = (files) => {
    const f = files?.[0];
    if (!f) return;
    setLocalFile(f);
    onFile(f);
  };

  return (
    <div>
      <div
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => { e.preventDefault(); setDragOver(false); handleFiles(e.dataTransfer.files); }}
        style={{
          border: `1.5px dashed ${dragOver ? ENT.primary : ENT.border}`,
          background: dragOver ? "rgba(37,99,235,0.04)" : "#FAFBFC",
          borderRadius: 12, padding: "22px 16px", cursor: "pointer", textAlign: "center", transition: "all .12s",
        }}
      >
        <input ref={inputRef} type="file" accept={accept} className="hidden" onChange={(e) => handleFiles(e.target.files)} />
        {localFile ? (
          <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8, fontSize: 13, color: ENT.text }}>
            <FileBox size={16} style={{ color: ENT.primary }} />
            <span style={{ fontWeight: 600 }}>{localFile.name}</span>
            <span style={{ color: ENT.muted }}>({(localFile.size / 1024 / 1024).toFixed(2)} MB)</span>
          </div>
        ) : previewUrl ? (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
            <img src={previewUrl} alt="" style={{ height: 56, width: 56, borderRadius: 10, objectFit: "cover" }} />
            <span style={{ fontSize: 12, color: ENT.muted }}>{currentLabel || "Almashtirish uchun bosing yoki sudrab tashlang"}</span>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
            <Upload size={18} style={{ color: ENT.muted }} />
            <span style={{ fontSize: 13, fontWeight: 600, color: ENT.text }}>Faylni shu yerga tashlang yoki bosing</span>
            {hint && <span style={{ fontSize: 11.5, color: ENT.muted }}>{hint}</span>}
          </div>
        )}
      </div>
      {busy && (
        <div style={{ marginTop: 8, height: 4, borderRadius: 2, background: ENT.border, overflow: "hidden", position: "relative" }}>
          <div style={{ position: "absolute", inset: 0, width: "40%", background: ENT.primary, borderRadius: 2, animation: "ent-indeterminate 1s ease-in-out infinite" }} />
        </div>
      )}
    </div>
  );
}

// ============================== Header / Nav / Right panel ==============================

function HeroHeader({ product, completeness, menuOpen, setMenuOpen, onTogglePublish, onDelete }) {
  const m = product.model3d;
  const arReady = !!(m?.usdz_url && m?.status === "ready");
  const marketOrigin = portalURLFor("market");
  const previewHref = marketOrigin ? `${marketOrigin}/products/${product.id}` : `/products/${product.id}?portal=market`;

  return (
    <div style={{ position: "sticky", top: 0, zIndex: 30, background: ENT.card, borderBottom: `1px solid ${ENT.border}` }}>
      <div style={{ display: "flex", alignItems: "center", gap: 14, padding: "14px 24px", flexWrap: "wrap" }}>
        <Link
          to="/products"
          style={{
            display: "flex", alignItems: "center", justifyContent: "center", width: 32, height: 32,
            borderRadius: 8, border: `1px solid ${ENT.border}`, color: ENT.muted, flexShrink: 0,
          }}
        >
          <ArrowLeft size={16} />
        </Link>

        {product.image_url ? (
          <img src={product.image_url} alt="" style={{ width: 42, height: 42, borderRadius: 10, objectFit: "cover", flexShrink: 0, border: `1px solid ${ENT.border}` }} />
        ) : (
          <div style={{ width: 42, height: 42, borderRadius: 10, background: ENT.bg, border: `1px solid ${ENT.border}`, flexShrink: 0 }} />
        )}

        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
            <h1 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: ENT.text }}>{product.name_uz}</h1>
            <Pill tone={product.is_published ? "success" : "muted"}>{product.is_published ? "Sotuvda" : "Yashirin"}</Pill>
            {arReady && <Pill tone="primary" icon={Sparkles}>AR tayyor</Pill>}
          </div>
          <div style={{ display: "flex", gap: 14, marginTop: 4, fontSize: 12, color: ENT.muted, flexWrap: "wrap" }}>
            <span>Slug: {product.slug}</span>
            <span>{product.variants.length} ta variant</span>
            <span>{(product.images?.length || 0) + (product.image_url ? 1 : 0)} ta rasm</span>
            <span>3D: {m ? m.status_display : "Yo'q"}</span>
            <span>Yaratilgan: {formatDate(product.created_at)}</span>
          </div>
        </div>

        <div style={{ display: "flex", alignItems: "center", gap: 10, flexShrink: 0 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginRight: 4 }}>
            <div style={{ width: 64 }}><ProgressBar percent={completeness.percent} /></div>
            <span style={{ fontSize: 11.5, color: ENT.muted, fontWeight: 700 }}>{completeness.percent}%</span>
          </div>
          <a
            href={previewHref} target="_blank" rel="noreferrer"
            style={{
              display: "inline-flex", alignItems: "center", gap: 6, borderRadius: 8, border: `1px solid ${ENT.border}`,
              padding: "8px 14px", fontSize: 13.5, fontWeight: 600, color: ENT.text, background: "#fff",
            }}
          >
            <Eye size={14} /> Ko'rish
          </a>
          <EntButton onClick={onTogglePublish}>
            {product.is_published ? "Yashirish" : "Sotuvga chiqarish"}
          </EntButton>
          <div style={{ position: "relative" }}>
            <button
              onClick={() => setMenuOpen((v) => !v)}
              style={{
                display: "flex", alignItems: "center", justifyContent: "center", width: 34, height: 34,
                borderRadius: 8, border: `1px solid ${ENT.border}`, color: ENT.muted, background: "#fff", cursor: "pointer",
              }}
            >
              <MoreHorizontal size={16} />
            </button>
            {menuOpen && (
              <div
                style={{
                  position: "absolute", top: "calc(100% + 6px)", right: 0, background: "#fff",
                  border: `1px solid ${ENT.border}`, borderRadius: 10, padding: 4, minWidth: 170,
                  boxShadow: "0 8px 24px rgba(16,24,40,0.12)", zIndex: 10,
                }}
              >
                <button
                  onClick={() => { setMenuOpen(false); onDelete(); }}
                  style={{
                    display: "flex", alignItems: "center", gap: 8, width: "100%", padding: "8px 10px",
                    background: "transparent", border: "none", borderRadius: 6, fontSize: 13, color: ENT.danger, cursor: "pointer", textAlign: "left",
                  }}
                >
                  <Trash2 size={14} /> Mahsulotni o'chirish
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function TabsNav({ tab, setTab, product, steps }) {
  const m = product.model3d;
  const counts = {
    variants: product.variants.length,
    media: (product.images?.length || 0) + (product.image_url ? 1 : 0),
    production: (steps || []).length,
  };
  return (
    <div style={{ background: ENT.card, borderBottom: `1px solid ${ENT.border}`, position: "sticky", top: 73, zIndex: 25 }}>
      <div style={{ display: "flex", gap: 4, padding: "0 20px", overflowX: "auto" }}>
        {TABS.map((t) => {
          const active = t.key === tab;
          const count = counts[t.key];
          return (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              style={{
                display: "flex", alignItems: "center", gap: 6, padding: "12px 12px", background: "transparent",
                border: "none", borderBottom: `2px solid ${active ? ENT.primary : "transparent"}`,
                color: active ? ENT.primary : ENT.muted, fontSize: 13.5, fontWeight: 600, cursor: "pointer", whiteSpace: "nowrap",
              }}
            >
              <t.icon size={15} />
              {t.label}
              {typeof count === "number" && count > 0 && (
                <span style={{ fontSize: 11, fontWeight: 700, color: active ? ENT.primary : ENT.muted, background: active ? "rgba(37,99,235,0.1)" : "#F1F2F4", borderRadius: 999, padding: "1px 6px" }}>
                  {count}
                </span>
              )}
              {t.key === "model" && m?.status === "ready" && <CheckCircle2 size={13} style={{ color: ENT.success }} />}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function RightPanel({ product, completeness }) {
  const m = product.model3d;
  const arReady = !!(m?.usdz_url && m?.status === "ready");
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16, position: "sticky", top: 130 }}>
      <Card title="Mahsulot ko'rinishi">
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {product.image_url ? (
            <img src={product.image_url} alt="" style={{ width: "100%", aspectRatio: "4/3", borderRadius: 10, objectFit: "cover", border: `1px solid ${ENT.border}` }} />
          ) : (
            <div style={{ width: "100%", aspectRatio: "4/3", borderRadius: 10, background: ENT.bg, border: `1px dashed ${ENT.border}`, display: "flex", alignItems: "center", justifyContent: "center", color: ENT.muted }}>
              <ImageIcon size={22} />
            </div>
          )}

          <Row label="Holat"><Pill tone={product.is_published ? "success" : "muted"}>{product.is_published ? "Sotuvda" : "Yashirin"}</Pill></Row>
          <Row label="Variantlar"><span style={{ fontWeight: 600, color: ENT.text }}>{product.variants.length}</span></Row>
          <Row label="3D model">
            {m ? <Pill tone={m.status === "ready" ? "success" : m.status === "failed" ? "danger" : "warning"}>{m.status_display}</Pill> : <Pill>Yo'q</Pill>}
          </Row>
          <Row label="AR (iOS)"><Pill tone={arReady ? "success" : "muted"} icon={arReady ? Sparkles : undefined}>{arReady ? "Tayyor" : "Yo'q"}</Pill></Row>
          <Row label="Yaratilgan"><span style={{ color: ENT.text }}>{formatDate(product.created_at)}</span></Row>
        </div>
      </Card>

      {m?.glb_url && m.status !== "processing" && (
        <Card title="3D oldindan ko'rish">
          <ModelViewer glb={m.glb_url} usdz={m.usdz_url} poster={product.image_url} style={{ height: "160px" }} />
        </Card>
      )}

      <Card title="Mahsulot to'liqligi" description={`${completeness.done}/${completeness.total} bosqich bajarilgan`}>
        <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
          {completeness.items.map((it) => (
            <div key={it.key} style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 13 }}>
              {it.done ? <CheckCircle2 size={15} style={{ color: ENT.success, flexShrink: 0 }} /> : <Circle size={15} style={{ color: ENT.border, flexShrink: 0 }} />}
              <span style={{ color: it.done ? ENT.text : ENT.muted }}>{it.label}</span>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

function Row({ label, children }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: 12.5 }}>
      <span style={{ color: ENT.muted }}>{label}</span>
      {children}
    </div>
  );
}

// ============================== Umumiy (General) ==============================

function GeneralTab({ product, categories, onDone }) {
  const [form, setForm] = useState({
    name_uz: product.name_uz,
    name_ru: product.name_ru || "",
    category: product.category || "",
    description: product.description || "",
    video_url: product.video_url || "",
  });
  const [image, setImage] = useState(null);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      if (image) fd.append("image", image);
      await api(`/products/${product.id}/`, { method: "PATCH", body: fd, isForm: true });
      setImage(null);
      setMsg("Saqlandi");
      setTimeout(() => setMsg(""), 2500);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit}>
      <Card title="Umumiy ma'lumot" description="Mahsulot nomi, kategoriyasi va tavsifi — katalogda shu ma'lumot ko'rsatiladi.">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Nomi (uz) *</label>
            <input className="input" value={form.name_uz} onChange={set("name_uz")} required />
          </div>
          <div>
            <label className="label">Nomi (ru)</label>
            <input className="input" value={form.name_ru} onChange={set("name_ru")} />
          </div>
          <div>
            <label className="label">Kategoriya *</label>
            <select className="input" value={form.category} onChange={set("category")} required>
              <option value="">Tanlang…</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>{c.name_uz}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Video URL (YouTube)</label>
            <input className="input" value={form.video_url} onChange={set("video_url")} placeholder="https://youtube.com/…" />
          </div>
          <div className="sm:col-span-2">
            <label className="label">Tavsif</label>
            <textarea className="input" rows={4} value={form.description} onChange={set("description")} />
          </div>
          <div className="sm:col-span-2">
            <label className="label">Asosiy rasm</label>
            <div style={{ maxWidth: 320 }}>
              <Dropzone accept="image/*" onFile={setImage} previewUrl={image ? URL.createObjectURL(image) : product.image_url} hint="PNG, JPG — katalog kartochkasida ko'rinadi" />
            </div>
          </div>
        </div>

        {error && <div className="error" style={{ marginTop: 14 }}>{error}</div>}
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 16 }}>
          <EntButton type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</EntButton>
          {msg && <Pill tone="success" icon={Check}>{msg}</Pill>}
        </div>
      </Card>
    </form>
  );
}

// ============================== Media (Gallery) ==============================

function MediaTab({ product, onDone }) {
  const [file, setFile] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const upload = async (f) => {
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      fd.append("image", f);
      fd.append("sort_order", product.images?.length || 0);
      await api(`/products/${product.id}/images/`, { method: "POST", body: fd, isForm: true });
      setFile(null);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const remove = async (imageId) => {
    try {
      await api(`/products/${product.id}/images/${imageId}/`, { method: "DELETE" });
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <Card
      title="Galereya"
      description="Asosiy rasmdan tashqari qo'shimcha rasmlar — mahsulot sahifasida sudrab ko'rish (swipe) uchun ishlatiladi."
      icon={Images}
    >
      {product.image_url && (
        <div style={{ marginBottom: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: ENT.muted, marginBottom: 8 }}>Asosiy rasm</div>
          <div style={{ position: "relative", width: 96 }}>
            <img src={product.image_url} alt="" style={{ width: 96, height: 96, borderRadius: 10, objectFit: "cover", border: `1px solid ${ENT.border}` }} />
            <div style={{ position: "absolute", top: 6, left: 6 }}><Pill tone="primary">Asosiy</Pill></div>
          </div>
          <p style={{ fontSize: 11.5, color: ENT.muted, marginTop: 6 }}>Asosiy rasmni "Umumiy" bo'limidan almashtiring.</p>
        </div>
      )}

      {product.images?.length > 0 && (
        <div style={{ marginBottom: 16 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: ENT.muted, marginBottom: 8 }}>Qo'shimcha rasmlar ({product.images.length})</div>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(96px, 1fr))", gap: 10 }}>
            {product.images.map((img) => (
              <div key={img.id} className="group" style={{ position: "relative", aspectRatio: "1/1", borderRadius: 10, overflow: "hidden", border: `1px solid ${ENT.border}` }}>
                <img src={img.image_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                <div
                  className="opacity-0 group-hover:opacity-100"
                  style={{ position: "absolute", inset: 0, background: "rgba(17,24,39,0.45)", display: "flex", alignItems: "center", justifyContent: "center", transition: "opacity .12s" }}
                >
                  <button
                    onClick={() => remove(img.id)}
                    title="O'chirish"
                    style={{ width: 30, height: 30, borderRadius: 8, background: "#fff", border: "none", color: ENT.danger, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div style={{ maxWidth: 340 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: ENT.muted, marginBottom: 8 }}>Yangi rasm qo'shish</div>
        <Dropzone accept="image/*" onFile={upload} hint="PNG, JPG — bir nechta marta yuklashingiz mumkin" busy={busy} />
      </div>
      {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}
    </Card>
  );
}

// ============================== 3D model ==============================

const GLB_SOURCE_EXTENSIONS = [".glb", ".gltf"];

function ModelTab({ product, onDone }) {
  const [glb, setGlb] = useState(null);
  const [usdz, setUsdz] = useState(null);
  const [textureArchive, setTextureArchive] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const m = product.model3d;

  useEffect(() => {
    if (m?.status !== "processing") return;
    const timer = setInterval(onDone, 3000);
    return () => clearInterval(timer);
  }, [m?.status, onDone]);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (!glb && !usdz && !m) {
      setError("Kamida 3D fayl tanlang");
      return;
    }
    setBusy(true);
    try {
      const fd = new FormData();
      if (!m) fd.append("product", product.id);
      if (glb) fd.append("glb_file", glb);
      if (usdz) fd.append("usdz_file", usdz);
      if (textureArchive) fd.append("texture_archive", textureArchive);
      await api(m ? `/models3d/${m.id}/` : "/models3d/", { method: m ? "PATCH" : "POST", body: fd, isForm: true });
      setGlb(null);
      setUsdz(null);
      setTextureArchive(null);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!confirm("3D model o'chirilsinmi?")) return;
    try {
      await api(`/models3d/${m.id}/`, { method: "DELETE" });
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  const isGlbSource = glb && GLB_SOURCE_EXTENSIONS.some((ext) => glb.name.toLowerCase().endsWith(ext));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <Card
        title="3D model"
        description="Bitta 3D model butun mahsulotga tegishli — har rang variant o'z rangini variantlar jadvalidan oladi."
        icon={Boxes}
        actions={m && <Pill tone={m.status === "ready" ? "success" : m.status === "failed" ? "danger" : "warning"}>{m.status === "processing" ? "Qayta ishlanmoqda…" : m.status_display}</Pill>}
      >
        {m?.glb_url && m.status !== "processing" && (
          <div style={{ marginBottom: 16, maxWidth: 360 }}>
            <ModelViewer glb={m.glb_url} usdz={m.usdz_url} poster={product.image_url} style={{ height: "220px" }} />
          </div>
        )}

        <form onSubmit={submit} style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <div className="label">3D fayl (GLB, FBX/OBJ yoki .zip/.rar) *</div>
              <Dropzone
                accept=".glb,.gltf,.fbx,.obj,.zip,.rar"
                onFile={setGlb}
                previewUrl={!glb && m?.glb_url ? product.image_url : null}
                currentLabel="Mavjud — almashtirish uchun bosing"
                hint="Marketplace arxivini (.rar) ochmasdan to'g'ridan-to'g'ri tashlang"
              />
            </div>
            <div>
              <div className="label">USDZ fayl (iOS AR) — qo'lda ustunlik berish, ixtiyoriy</div>
              <Dropzone accept=".usdz" onFile={setUsdz} hint="Bo'sh qoldirsangiz, GLB'dan server avtomatik yasaydi" />
            </div>
            <div className="sm:col-span-2">
              <div className="label">Tekstura arxivi (.zip yoki .rar) — alohida yuklangan bo'lsa, ixtiyoriy</div>
              <div style={{ maxWidth: 360 }}>
                <Dropzone accept=".zip,.rar" onFile={setTextureArchive} hint={isGlbSource ? "GLB tanlandi — bu safar ta'sir qilmaydi" : "Faqat FBX/OBJ bilan bir vaqtda yuklaganda ishlaydi"} />
              </div>
            </div>
          </div>

          {error && <div className="error">{error}</div>}
          <div style={{ display: "flex", gap: 10 }}>
            <EntButton type="submit" disabled={busy}>{busy ? "Yuklanmoqda…" : m ? "Yangilash" : "Yuklash"}</EntButton>
            {m && <EntButton variant="danger" onClick={remove}>3D ni o'chirish</EntButton>}
          </div>
          <p style={{ fontSize: 12, color: ENT.muted, margin: 0 }}>
            GLB, FBX, OBJ yoki shularni o'z ichiga olgan arxiv yuklashingiz mumkin — server FBX/OBJ bo'lsa avtomatik
            GLB'ga aylantiradi, so'ng iOS AR uchun USDZ faylni ham o'zi yasaydi (bir necha soniya).
          </p>
        </form>
      </Card>

      {m && <SharingTab product={product} onDone={onDone} embedded />}
    </div>
  );
}

// ============================== Variantlar ==============================

function VariantsTab({ product: p, onDone }) {
  const [error, setError] = useState("");
  const [variant, setVariant] = useState({ name: "", base_price: "", width: 1, height: 1, depth: 1 });
  const [showVariant, setShowVariant] = useState(false);
  const [editColorFor, setEditColorFor] = useState(null);

  const call = async (fn) => {
    try {
      setError("");
      await fn();
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  const addVariant = (e) => {
    e.preventDefault();
    call(() => api(`/products/${p.id}/variants/`, { method: "POST", body: variant })).then(() => {
      setVariant({ name: "", base_price: "", width: 1, height: 1, depth: 1 });
      setShowVariant(false);
    });
  };

  return (
    <Card
      title="Variantlar"
      description="Har xil rang/material variantlari — narx va standart o'lcham har birida alohida bo'ladi."
      icon={Palette}
      actions={<EntButton small onClick={() => setShowVariant((v) => !v)}>+ Variant</EntButton>}
    >
      {p.variants.length > 0 ? (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))", gap: 12 }}>
          {p.variants.map((v) => (
            <div key={v.id}>
              <div style={{ border: `1px solid ${ENT.border}`, borderRadius: 12, padding: 14, display: "flex", flexDirection: "column", gap: 10 }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <span style={{ fontSize: 14, fontWeight: 700, color: ENT.text }}>{v.name}</span>
                  <button
                    onClick={() => setEditColorFor(editColorFor === v.id ? null : v.id)}
                    title="Rangni tahrirlash"
                    style={{
                      width: 26, height: 26, borderRadius: "50%", cursor: "pointer",
                      background: v.texture_url ? `url(${v.texture_url}) center/cover` : v.color_hex || ENT.border,
                      border: `1px solid ${ENT.border}`,
                    }}
                  />
                </div>
                <Row label="Narx (m³)"><span style={{ fontWeight: 600, color: ENT.text }}>{Number(v.base_price).toLocaleString()} so'm</span></Row>
                <Row label="O'lcham"><span style={{ color: ENT.text }}>{v.width} × {v.height} × {v.depth} m</span></Row>
                <Row label="Rang / material"><span style={{ color: ENT.text }}>{v.color_hex || "Tanlanmagan"}</span></Row>
              </div>
              {editColorFor === v.id && <div style={{ marginTop: 8 }}><VariantColorForm variant={v} onDone={onDone} /></div>}
            </div>
          ))}
        </div>
      ) : (
        <p style={{ fontSize: 13, color: ENT.muted }}>Hali variant qo'shilmagan.</p>
      )}

      {showVariant && (
        <form onSubmit={addVariant} style={{ marginTop: 16, paddingTop: 16, borderTop: `1px solid ${ENT.border}`, display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 12 }}>
          <div style={{ minWidth: 150 }}>
            <label className="label">Nomi (material)</label>
            <input className="input" value={variant.name} onChange={(e) => setVariant({ ...variant, name: e.target.value })} required />
          </div>
          <div style={{ minWidth: 150 }}>
            <label className="label">Narx (1 m³, so'm)</label>
            <input className="input" type="number" min="0" value={variant.base_price} onChange={(e) => setVariant({ ...variant, base_price: e.target.value })} required />
          </div>
          {[["width", "Eni"], ["height", "Bo'yi"], ["depth", "Chuquri"]].map(([k, label]) => (
            <div key={k} style={{ width: 96 }}>
              <label className="label">{label} (m)</label>
              <input className="input" type="number" step="0.1" min="0.1" value={variant[k]} onChange={(e) => setVariant({ ...variant, [k]: e.target.value })} />
            </div>
          ))}
          <EntButton type="submit">Qo'shish</EntButton>
        </form>
      )}
      {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}
    </Card>
  );
}

function VariantColorForm({ variant, onDone }) {
  const [colorHex, setColorHex] = useState(variant.color_hex || "#8B5A2B");
  const [texture, setTexture] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      fd.append("color_hex", colorHex);
      if (texture) fd.append("texture", texture);
      await api(`/products/${variant.product}/variants/${variant.id}/`, { method: "PATCH", body: fd, isForm: true });
      setTexture(null);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} style={{ border: `1px dashed ${ENT.border}`, borderRadius: 10, padding: 12, background: ENT.bg, display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 10 }}>
      <div>
        <label className="label">Rang</label>
        <input className="input !w-14 !p-1" type="color" value={colorHex} onChange={(e) => setColorHex(e.target.value)} />
      </div>
      <div>
        <label className="label">Naqsh surati (ixtiyoriy)</label>
        <input className="input" type="file" accept="image/*" onChange={(e) => setTexture(e.target.files[0])} />
      </div>
      {error && <div className="error">{error}</div>}
      <EntButton small type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</EntButton>
    </form>
  );
}

// ============================== Ishlab chiqarish ==============================

const EMPTY_STEP = { name: "", role: "usta", estimated_hours: 1, cost: 0, required_materials: "", photo_requirement: "optional" };

function ProductionTab({ product, steps, onStepsChange }) {
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_STEP);

  const addStep = (e) => {
    e.preventDefault();
    setError("");
    api(`/products/${product.id}/workflow-steps/`, { method: "POST", body: form })
      .then(() => { setForm(EMPTY_STEP); setShowForm(false); onStepsChange(); })
      .catch((e) => setError(e.message));
  };

  const removeStep = (id) => {
    if (!confirm("Bosqich o'chirilsinmi?")) return;
    api(`/products/${product.id}/workflow-steps/${id}/`, { method: "DELETE" }).then(onStepsChange).catch((e) => setError(e.message));
  };

  const move = (step, direction) => {
    const idx = steps.findIndex((s) => s.id === step.id);
    const target = steps[idx + direction];
    if (!target) return;
    Promise.all([
      api(`/products/${product.id}/workflow-steps/${step.id}/`, { method: "PATCH", body: { order_index: target.order_index } }),
      api(`/products/${product.id}/workflow-steps/${target.id}/`, { method: "PATCH", body: { order_index: step.order_index } }),
    ]).then(onStepsChange).catch((e) => setError(e.message));
  };

  const totalCost = (steps || []).reduce((n, s) => n + Number(s.cost || 0), 0);
  const totalHours = (steps || []).reduce((n, s) => n + Number(s.estimated_hours || 0), 0);

  return (
    <Card
      title="Ishlab chiqarish jarayoni"
      description="Bosqichlar ketma-ket zanjir sifatida ishlaydi — buyurtma tushganda shu zanjir nusxalanadi va har bosqich mustaqil kuzatiladi."
      icon={Workflow}
      actions={<EntButton small onClick={() => setShowForm((v) => !v)}>+ Bosqich</EntButton>}
    >
      {steps === null ? (
        <p style={{ fontSize: 13, color: ENT.muted }}>Yuklanmoqda…</p>
      ) : steps.length === 0 ? (
        <p style={{ fontSize: 13, color: ENT.muted }}>Hali bosqich qo'shilmagan.</p>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
          {steps.map((s, i) => {
            const Icon = POSITIONS[s.role]?.icon;
            const isLast = i === steps.length - 1;
            return (
              <div key={s.id} style={{ display: "flex", gap: 12 }}>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", width: 32 }}>
                  <div style={{ width: 32, height: 32, borderRadius: 9, background: "rgba(37,99,235,0.1)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    {Icon ? <Icon size={15} style={{ color: ENT.primary }} /> : <span style={{ fontSize: 12, fontWeight: 700, color: ENT.primary }}>{i + 1}</span>}
                  </div>
                  {!isLast && <div style={{ width: 2, flex: 1, background: ENT.border, minHeight: 22 }} />}
                </div>
                <div style={{ flex: 1, paddingBottom: isLast ? 0 : 18 }}>
                  <div style={{ border: `1px solid ${ENT.border}`, borderRadius: 10, padding: "10px 14px", display: "flex", alignItems: "center", gap: 10, flexWrap: "wrap" }}>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ fontSize: 13.5, fontWeight: 600, color: ENT.text }}>{s.name}</div>
                      <div style={{ fontSize: 12, color: ENT.muted, marginTop: 2 }}>
                        {POSITIONS[s.role]?.label || s.role} · {s.estimated_hours} soat · {Number(s.cost).toLocaleString()} so'm
                        {s.photo_requirement !== "optional" && ` · ${PHOTO_REQUIREMENT[s.photo_requirement]} rasm`}
                      </div>
                    </div>
                    <div style={{ display: "flex", gap: 4 }}>
                      <IconBtn title="Yuqoriga" disabled={i === 0} onClick={() => move(s, -1)}><ArrowUp size={13} /></IconBtn>
                      <IconBtn title="Pastga" disabled={isLast} onClick={() => move(s, 1)}><ArrowDown size={13} /></IconBtn>
                      <IconBtn title="O'chirish" onClick={() => removeStep(s.id)} danger><Trash2 size={13} /></IconBtn>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
          <div style={{ display: "flex", justifyContent: "flex-end", gap: 16, fontSize: 12.5, color: ENT.muted, marginTop: 8, paddingRight: 4 }}>
            <span>Jami vaqt: <b style={{ color: ENT.text }}>{totalHours} soat</b></span>
            <span>Jami xarajat: <b style={{ color: ENT.text }}>{totalCost.toLocaleString()} so'm</b></span>
          </div>
        </div>
      )}

      {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}

      {showForm && (
        <form onSubmit={addStep} style={{ marginTop: 16, paddingTop: 16, borderTop: `1px solid ${ENT.border}`, display: "flex", flexDirection: "column", gap: 12 }}>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="label">Bosqich nomi *</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Mas'ul rol</label>
              <select className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                {Object.entries(POSITIONS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Taxminiy vaqt (soat)</label>
              <input className="input" type="number" step="0.5" min="0" value={form.estimated_hours} onChange={(e) => setForm({ ...form, estimated_hours: e.target.value })} />
            </div>
            <div>
              <label className="label">Xarajat (so'm)</label>
              <input className="input" type="number" min="0" value={form.cost} onChange={(e) => setForm({ ...form, cost: e.target.value })} />
            </div>
            <div className="sm:col-span-2">
              <label className="label">Kerakli materiallar (ixtiyoriy)</label>
              <input className="input" value={form.required_materials} onChange={(e) => setForm({ ...form, required_materials: e.target.value })} />
            </div>
            <div>
              <label className="label">Rasm talabi</label>
              <select className="input" value={form.photo_requirement} onChange={(e) => setForm({ ...form, photo_requirement: e.target.value })}>
                <option value="required">Majburiy</option>
                <option value="optional">Ixtiyoriy</option>
                <option value="disabled">Kerak emas</option>
              </select>
            </div>
          </div>
          <div style={{ display: "flex", gap: 10 }}>
            <EntButton small type="submit">Qo'shish</EntButton>
            <EntButton small variant="ghost" onClick={() => setShowForm(false)}>Bekor</EntButton>
          </div>
        </form>
      )}
    </Card>
  );
}

function IconBtn({ children, title, onClick, disabled, danger }) {
  return (
    <button
      title={title} disabled={disabled} onClick={onClick}
      style={{
        width: 26, height: 26, borderRadius: 7, border: `1px solid ${ENT.border}`, background: "#fff",
        color: disabled ? "#D1D5DB" : danger ? ENT.danger : ENT.muted,
        display: "flex", alignItems: "center", justifyContent: "center", cursor: disabled ? "default" : "pointer",
      }}
    >
      {children}
    </button>
  );
}

// ============================== Ulashish ==============================

const VISIBILITY_OPTIONS = [
  { value: "private", label: "Yopiq — faqat firma a'zolari", icon: Lock },
  { value: "restricted", label: "Cheklangan — faqat ro'yxatdagi shaxslar", icon: Link2 },
  { value: "public", label: "Ochiq — havola bilan hamma", icon: Unlock },
];

function SharingTab({ product, onDone, embedded }) {
  const model = product.model3d;
  const [visibility, setVisibility] = useState(model?.visibility || "private");
  const [emailsText, setEmailsText] = useState((model?.allowed_emails || []).join(", "));
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  if (!model) {
    const body = <p style={{ fontSize: 13, color: ENT.muted }}>Ulashish sozlamalari mavjud bo'lishi uchun avval 3D model yuklang.</p>;
    return embedded ? null : <Card title="Ulashish" icon={Share2}>{body}</Card>;
  }

  const shareUrl = `${window.location.protocol}//${window.location.host}/viewer/${model.share_token}/`;

  const save = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const allowed_emails = emailsText.split(",").map((s) => s.trim()).filter(Boolean);
      await api(`/models3d/${model.id}/`, { method: "PATCH", body: { visibility, allowed_emails } });
      setMsg("Saqlandi");
      setTimeout(() => setMsg(""), 2500);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const copyLink = () => {
    navigator.clipboard?.writeText(shareUrl);
    setMsg("Havola nusxalandi");
    setTimeout(() => setMsg(""), 2500);
  };

  const content = (
    <form onSubmit={save} style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 12 }}>
        <div style={{ minWidth: 260, flex: 1 }}>
          <label className="label">Kim ko'ra oladi</label>
          <select className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
            {VISIBILITY_OPTIONS.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
        </div>
        <EntButton small type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</EntButton>
      </div>
      {visibility === "restricted" && (
        <div>
          <label className="label">Ruxsat etilgan emaillar (vergul bilan ajrating)</label>
          <input className="input" value={emailsText} onChange={(e) => setEmailsText(e.target.value)} placeholder="mijoz1@mail.com, mijoz2@mail.com" />
        </div>
      )}
      <div style={{ display: "flex", alignItems: "center", gap: 8, borderRadius: 8, padding: "8px 10px", background: ENT.bg, border: `1px solid ${ENT.border}` }}>
        <code style={{ flex: 1, fontSize: 12, color: ENT.muted, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{shareUrl}</code>
        <button type="button" onClick={copyLink} style={{ background: "transparent", border: "none", color: ENT.primary, fontSize: 12.5, fontWeight: 600, cursor: "pointer", display: "flex", alignItems: "center", gap: 4 }}>
          Nusxalash
        </button>
        <a href={shareUrl} target="_blank" rel="noreferrer" style={{ color: ENT.muted, display: "flex" }}><ExternalLink size={14} /></a>
      </div>
      {error && <div className="error">{error}</div>}
      {msg && <Pill tone="success" icon={Check}>{msg}</Pill>}
    </form>
  );

  return embedded ? (
    <Card title="Ulashish sozlamalari" description="3D modelni tashqi havola orqali ulashish." icon={Share2}>{content}</Card>
  ) : (
    <Card title="Ulashish" description="3D modelni tashqi havola orqali ulashish." icon={Share2}>{content}</Card>
  );
}
