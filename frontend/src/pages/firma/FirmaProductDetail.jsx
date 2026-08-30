import { useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import {
  ArrowLeft, ArrowUp, ArrowDown, Check, CheckCircle2,
  Circle, Eye, ExternalLink, FileBox, Image as ImageIcon, Images, Layers, Link2,
  Lock, MoreHorizontal, Palette, Pencil, Share2, Sparkles, Tag, TrendingUp, Trash2, Unlock, Upload,
  Workflow,
} from "lucide-react";
import { api } from "../../api";
import { portalURLFor } from "../../portal";
import { POSITIONS } from "../../positions";
import Model3DPartPicker from "../../components/Model3DPartPicker";

// Bu sahifa o'z ichida mustaqil "enterprise" rang tizimidan foydalanadi —
// platformaning umumiy amber brendi (sidebar, boshqa sahifalar) o'zgarishsiz
// qoladi. Har bir rang CSS custom property'ga ISHORA (masalan "var(--ent-bg)")
// sifatida yozilgan, o'zi emas — haqiqiy qiymatlar pastdagi <style> blokida
// ".ent-root"/".dark-mode .ent-root" orqali belgilanadi. Shu tufayli tungi
// rejim shu sahifa ichida ham ishlaydi (avval qiymatlar to'g'ridan-to'g'ri
// hex bo'lib, tungi rejimni butunlay e'tiborsiz qoldirar edi), va ~30+ joyda
// `ENT.text` kabi ishlatilgan barcha komponentlarni o'zgartirish shart emas.
const ENT = {
  bg: "var(--ent-bg)",
  card: "var(--ent-card)",
  border: "var(--ent-border)",
  primary: "var(--ent-primary)",
  success: "var(--ent-success)",
  warning: "var(--ent-warning)",
  danger: "var(--ent-danger)",
  text: "var(--ent-text)",
  muted: "var(--ent-muted)",
};

const ENT_VARS = {
  "--bg": ENT.bg,
  "--card": ENT.card,
  "--border": ENT.border,
  "--text": ENT.text,
  "--muted": ENT.muted,
  "--secondary": ENT.primary,
  "--primary": ENT.primary,
  "--primary-deep": "var(--ent-primary-deep)",
  "--brand-cta-bg": ENT.primary,
  "--brand-cta-text": "var(--ent-primary-deep)",
  "--shadow": "0 1px 2px rgba(16,24,40,0.04)",
};

const PHOTO_REQUIREMENT = {
  required: "Majburiy",
  optional: "Ixtiyoriy",
  disabled: "Kerak emas",
};

const TABS = [
  { key: "general", label: "Umumiy", icon: FileBox },
  { key: "variants", label: "Variantlar", icon: Palette },
  { key: "production", label: "Ishlab chiqarish", icon: Workflow },
  { key: "sharing", label: "Ulashish", icon: Share2 },
];

function formatDate(iso) {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("uz-UZ", { year: "numeric", month: "short", day: "numeric" });
}

function hasReadyModel3d(product) {
  return product.model3d?.status === "ready" || product.variants.some((v) => v.model3d?.status === "ready");
}

function computeCompleteness(product, steps) {
  const items = [
    { key: "general", label: "Umumiy ma'lumot", done: !!(product.name_uz && product.category) },
    { key: "images", label: "Rasmlar", done: !!product.image_url },
    { key: "variants", label: "Variantlar", done: product.variants.length > 0 },
    { key: "model", label: "3D model", done: hasReadyModel3d(product) },
    { key: "production", label: "Ishlab chiqarish bosqichlari", done: (steps || []).length > 0 },
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
    <div className="ent-root" style={{ ...ENT_VARS, background: ENT.bg, margin: "-24px", minHeight: "100%" }}>
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
          {tab === "variants" && <VariantsTab product={product} onDone={load} />}
          {tab === "production" && (
            <>
              <ProductionTab product={product} steps={steps} onStepsChange={load} />
              <BomTab product={product} />
              <ManufacturedUnitsTab product={product} />
            </>
          )}
          {tab === "sharing" && <SharingTab product={product} onDone={load} />}
        </div>
        <RightPanel product={product} completeness={completeness} />
      </div>

      <style>{`
        .ent-root {
          --ent-bg: #F7F8FA;
          --ent-card: #FFFFFF;
          --ent-border: #E5E7EB;
          --ent-primary: #2563EB;
          --ent-primary-deep: #FFFFFF;
          --ent-success: #16A34A;
          --ent-warning: #F59E0B;
          --ent-danger: #DC2626;
          --ent-text: #111827;
          --ent-muted: #6B7280;
        }
        .dark-mode .ent-root {
          --ent-bg: #0f1115;
          --ent-card: #1a1c22;
          --ent-border: rgba(255,255,255,0.1);
          --ent-primary: #3b82f6;
          --ent-primary-deep: #FFFFFF;
          --ent-success: #22c55e;
          --ent-warning: #f59e0b;
          --ent-danger: #f87171;
          --ent-text: #e5e7eb;
          --ent-muted: #9ca3af;
        }
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
  const readyVariantModels = product.variants.filter((v) => v.model3d?.status === "ready");
  const modelReady = hasReadyModel3d(product);
  const arReady = !!(product.model3d?.usdz_url && product.model3d?.status === "ready") || readyVariantModels.some((v) => v.model3d?.usdz_url);
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
            <span>3D: {modelReady ? "Tayyor" : "Yo'q"}</span>
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
  const counts = {
    variants: product.variants.length,
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
            </button>
          );
        })}
      </div>
    </div>
  );
}

function RightPanel({ product, completeness }) {
  const readyVariantModels = product.variants.filter((v) => v.model3d?.status === "ready");
  const modelReady = hasReadyModel3d(product);
  const arReady = !!(product.model3d?.usdz_url && product.model3d?.status === "ready") || readyVariantModels.some((v) => v.model3d?.usdz_url);
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
            <Pill tone={modelReady ? "success" : "muted"}>{modelReady ? `Tayyor (${readyVariantModels.length || 1} ta)` : "Yo'q"}</Pill>
          </Row>
          <Row label="AR (iOS)"><Pill tone={arReady ? "success" : "muted"} icon={arReady ? Sparkles : undefined}>{arReady ? "Tayyor" : "Yo'q"}</Pill></Row>
          <Row label="Yaratilgan"><span style={{ color: ENT.text }}>{formatDate(product.created_at)}</span></Row>
        </div>
      </Card>

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
    category: product.category || "",
    description: product.description || "",
  });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(`/products/${product.id}/`, { method: "PATCH", body: form });
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
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <form onSubmit={submit}>
        <Card title="Umumiy ma'lumot" description="Mahsulot nomi, kategoriyasi va tavsifi — katalogda shu ma'lumot ko'rsatiladi.">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="label">Nomi (uz) *</label>
              <input className="input" value={form.name_uz} onChange={set("name_uz")} required />
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
            <div className="sm:col-span-2">
              <label className="label">Tavsif</label>
              <textarea className="input" rows={4} value={form.description} onChange={set("description")} />
            </div>
          </div>

          {error && <div className="error" style={{ marginTop: 14 }}>{error}</div>}
          <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 16 }}>
            <EntButton type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</EntButton>
            {msg && <Pill tone="success" icon={Check}>{msg}</Pill>}
          </div>
        </Card>
      </form>

      <ImagesCard product={product} onDone={onDone} />
    </div>
  );
}

function ImagesCard({ product, onDone }) {
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

  const makePrimary = async (imageId) => {
    setError("");
    try {
      await api(`/products/${product.id}/set-primary-image/`, { method: "POST", body: { image: imageId } });
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <Card
      title="Rasmlar"
      description="Yuklangan rasmlardan istalganini asosiy rasm sifatida belgilashingiz mumkin — u katalog kartochkasida ko'rsatiladi."
      icon={Images}
    >
      {product.images?.length > 0 ? (
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(110px, 1fr))", gap: 10, marginBottom: 16 }}>
          {product.images.map((img) => {
            // Asosiy rasm serverda alohida faylga nusxalanadi (boshqa
            // upload_to papkaga) — to'liq URL hech qachon mos kelmaydi,
            // shuning uchun taqqoslash fayl nomi (oxirgi segment) bo'yicha.
            const isPrimary = product.image_url && img.image_url?.split("/").pop() === product.image_url.split("/").pop();
            return (
              <div key={img.id} className="group" style={{ position: "relative", aspectRatio: "1/1", borderRadius: 10, overflow: "hidden", border: `1px solid ${isPrimary ? ENT.primary : ENT.border}` }}>
                <img src={img.image_url} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                {isPrimary && <div style={{ position: "absolute", top: 6, left: 6 }}><Pill tone="primary">Asosiy</Pill></div>}
                <div
                  className="opacity-0 group-hover:opacity-100"
                  style={{ position: "absolute", inset: 0, background: "rgba(17,24,39,0.5)", display: "flex", alignItems: "center", justifyContent: "center", gap: 6, transition: "opacity .12s" }}
                >
                  {!isPrimary && (
                    <button
                      onClick={() => makePrimary(img.id)}
                      title="Asosiy qilish"
                      style={{ width: 30, height: 30, borderRadius: 8, background: "#fff", border: "none", color: ENT.primary, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
                    >
                      <Check size={14} />
                    </button>
                  )}
                  <button
                    onClick={() => remove(img.id)}
                    title="O'chirish"
                    style={{ width: 30, height: 30, borderRadius: 8, background: "#fff", border: "none", color: ENT.danger, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <p style={{ fontSize: 13, color: ENT.muted, marginBottom: 16 }}>Hali rasm yuklanmagan.</p>
      )}

      <div style={{ maxWidth: 340 }}>
        <div style={{ fontSize: 12, fontWeight: 600, color: ENT.muted, marginBottom: 8 }}>Yangi rasm qo'shish</div>
        <Dropzone accept="image/*" onFile={upload} hint="PNG, JPG — bir nechta marta yuklashingiz mumkin" busy={busy} />
      </div>
      {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}
    </Card>
  );
}

// ============================== Variantlar ==============================

function VariantsTab({ product: p, onDone }) {
  const [error, setError] = useState("");
  const [variant, setVariant] = useState({ name: "", base_price: "", width: 1, height: 1, depth: 1 });
  const [modelFile, setModelFile] = useState(null);
  const [showVariant, setShowVariant] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [busy, setBusy] = useState(false);

  // Konvertatsiya (Blender) fonda ishlaydi — biror variant "processing"
  // holatida bo'lsa, tayyor bo'lganda ko'rinishi uchun avtomatik yangilab
  // turamiz (aks holda foydalanuvchi qo'lda sahifani yangilamaguncha
  // "Qayta ishlanmoqda..." abadiy osilib qolganday ko'rinadi).
  const isProcessing = p.variants.some((v) => v.model3d?.status === "processing");
  useEffect(() => {
    if (!isProcessing) return;
    const timer = setInterval(onDone, 3000);
    return () => clearInterval(timer);
  }, [isProcessing, onDone]);

  const call = async (fn) => {
    try {
      setError("");
      await fn();
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  const addVariant = async (e) => {
    e.preventDefault();
    if (!modelFile) {
      setError("3D fayl majburiy — variant uchun model tanlang");
      return;
    }
    setError("");
    setBusy(true);
    let created = null;
    try {
      created = await api(`/products/${p.id}/variants/`, { method: "POST", body: variant });
      const fd = new FormData();
      fd.append("variant", created.id);
      fd.append("glb_file", modelFile);
      await api("/models3d/", { method: "POST", body: fd, isForm: true });
      setVariant({ name: "", base_price: "", width: 1, height: 1, depth: 1 });
      setModelFile(null);
      setShowVariant(false);
      onDone();
    } catch (err) {
      // Model yuklash muvaffaqiyatsiz bo'lsa — 3D faylsiz variant qolib
      // ketmasligi uchun (majburiy talab) endigina yaratilgan variantni
      // ham bekor qilamiz.
      if (created) {
        await api(`/products/${p.id}/variants/${created.id}/`, { method: "DELETE" }).catch(() => {});
      }
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const removeVariant = (v) => {
    if (!confirm(`"${v.name}" varianti o'chirilsinmi?`)) return;
    call(() => api(`/products/${p.id}/variants/${v.id}/`, { method: "DELETE" }));
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
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span
                      style={{
                        width: 20, height: 20, borderRadius: "50%", flexShrink: 0,
                        background: v.texture_url ? `url(${v.texture_url}) center/cover` : v.color_hex || ENT.border,
                        border: `1px solid ${ENT.border}`,
                      }}
                    />
                    <span style={{ fontSize: 14, fontWeight: 700, color: ENT.text }}>{v.name}</span>
                  </div>
                  <div style={{ display: "flex", gap: 4 }}>
                    <button
                      onClick={() => setEditingId(editingId === v.id ? null : v.id)}
                      title="Tahrirlash"
                      style={{ background: "transparent", border: "none", color: ENT.muted, cursor: "pointer", display: "flex", padding: 4 }}
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      onClick={() => removeVariant(v)}
                      title="O'chirish"
                      style={{ background: "transparent", border: "none", color: ENT.danger, cursor: "pointer", display: "flex", padding: 4 }}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
                <Row label="Narx (m³)"><span style={{ fontWeight: 600, color: ENT.text }}>{Number(v.base_price).toLocaleString()} so'm</span></Row>
                <Row label="O'lcham"><span style={{ color: ENT.text }}>{v.width} × {v.height} × {v.depth} m</span></Row>
                <Row label="Rang / material"><span style={{ color: ENT.text }}>{v.color_hex || "Tanlanmagan"}</span></Row>
                <Row label="3D model">
                  {v.model3d ? (
                    <Pill tone={v.model3d.status === "ready" ? "success" : v.model3d.status === "failed" ? "danger" : "warning"}>
                      {v.model3d.status === "processing" ? "Qayta ishlanmoqda…" : v.model3d.status_display}
                    </Pill>
                  ) : (
                    <Pill tone="danger">3D fayl yo'q</Pill>
                  )}
                </Row>
              </div>
              {editingId === v.id && (
                <div style={{ marginTop: 8 }}>
                  <VariantEditForm productId={p.id} variant={v} onDone={onDone} onClose={() => setEditingId(null)} />
                </div>
              )}
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
          <div style={{ minWidth: 220 }}>
            <label className="label">3D fayl (GLB/FBX/OBJ/DAE yoki .zip/.rar) *</label>
            <input
              className="input"
              type="file"
              accept=".glb,.gltf,.fbx,.obj,.dae,.zip,.rar"
              onChange={(e) => setModelFile(e.target.files[0])}
              required
            />
          </div>
          <EntButton type="submit" disabled={busy}>{busy ? "Yaratilmoqda…" : "Qo'shish"}</EntButton>
        </form>
      )}
      {error && <div className="error" style={{ marginTop: 12 }}>{error}</div>}
    </Card>
  );
}

function VariantEditForm({ productId, variant, onDone, onClose }) {
  const [form, setForm] = useState({
    name: variant.name,
    base_price: variant.base_price,
    width: variant.width,
    height: variant.height,
    depth: variant.depth,
  });
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
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      fd.append("color_hex", colorHex);
      if (texture) fd.append("texture", texture);
      await api(`/products/${productId}/variants/${variant.id}/`, { method: "PATCH", body: fd, isForm: true });
      setTexture(null);
      onDone();
      onClose();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form onSubmit={submit} style={{ border: `1px dashed ${ENT.border}`, borderRadius: 10, padding: 12, background: ENT.bg, display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 10 }}>
      <div style={{ minWidth: 130 }}>
        <label className="label">Nomi</label>
        <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
      </div>
      <div style={{ minWidth: 130 }}>
        <label className="label">Narx (1 m³, so'm)</label>
        <input className="input" type="number" min="0" value={form.base_price} onChange={(e) => setForm({ ...form, base_price: e.target.value })} required />
      </div>
      {[["width", "Eni"], ["height", "Bo'yi"], ["depth", "Chuquri"]].map(([k, label]) => (
        <div key={k} style={{ width: 88 }}>
          <label className="label">{label} (m)</label>
          <input className="input" type="number" step="0.1" min="0.1" value={form[k]} onChange={(e) => setForm({ ...form, [k]: e.target.value })} />
        </div>
      ))}
      <div>
        <label className="label">Rang</label>
        <input className="input !w-14 !p-1" type="color" value={colorHex} onChange={(e) => setColorHex(e.target.value)} />
      </div>
      <div>
        <label className="label">Naqsh surati (ixtiyoriy)</label>
        <input className="input" type="file" accept="image/*" onChange={(e) => setTexture(e.target.files[0])} />
      </div>
      {error && <div className="error">{error}</div>}
      <div style={{ display: "flex", gap: 8 }}>
        <EntButton small type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</EntButton>
        <EntButton small variant="ghost" type="button" onClick={onClose}>Bekor</EntButton>
      </div>
      <div style={{ width: "100%", marginTop: 4, paddingTop: 10, borderTop: `1px solid ${ENT.border}` }}>
        <VariantModelSection variant={variant} onDone={onDone} />
      </div>
    </form>
  );
}

function VariantModelSection({ variant, onDone }) {
  const [file, setFile] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const m = variant.model3d;

  const upload = async (e) => {
    e.preventDefault();
    if (!file) return;
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      fd.append("variant", variant.id);
      fd.append("glb_file", file);
      await api(m ? `/models3d/${m.id}/` : "/models3d/", { method: m ? "PATCH" : "POST", body: fd, isForm: true });
      setFile(null);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div style={{ display: "flex", flexWrap: "wrap", alignItems: "flex-end", gap: 10 }}>
      <div style={{ flex: "1 1 260px" }}>
        <label className="label">
          3D fayl (majburiy)
          {m ? (
            <Pill tone={m.status === "ready" ? "success" : m.status === "failed" ? "danger" : "warning"}>{m.status === "processing" ? "Qayta ishlanmoqda…" : m.status_display}</Pill>
          ) : (
            <Pill tone="danger">Yo'q</Pill>
          )}
        </label>
        <input className="input" type="file" accept=".glb,.gltf,.fbx,.obj,.dae,.zip,.rar" onChange={(e) => setFile(e.target.files[0])} />
        <p style={{ fontSize: 11, color: ENT.muted, margin: "4px 0 0" }}>
          Har bir variant o'zining alohida 3D faylini oladi — bu ko'p materialli mahsulotlarda (masalan
          eshikli shkaf) rang almashtirish barcha qismlarga (tutqich, temir qismlarga ham) bir xilda
          ta'sir qilib qo'yishining oldini oladi. Faylni faqat almashtirish mumkin, o'chirib bo'lmaydi.
        </p>
      </div>
      <div style={{ display: "flex", gap: 8 }}>
        <EntButton small onClick={upload} disabled={busy || !file}>{busy ? "Yuklanmoqda…" : m ? "Yangilash" : "Yuklash"}</EntButton>
      </div>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

// ============================== Ishlab chiqarish ==============================

const EMPTY_STEP = {
  name: "", role: "usta", estimated_hours: 1, cost: 0, required_materials: "",
  photo_requirement: "optional", comment_requirement: "optional", work_type: "", quantity: 1, raw_material: "",
  cut_piece_length: "", cut_piece_width: "", cut_piece_count: "", cut_note: "",
};

function ProductionTab({ product, steps, onStepsChange }) {
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_STEP);
  const [workTypes, setWorkTypes] = useState([]);
  const [materials, setMaterials] = useState([]);

  useEffect(() => {
    api("/work-types/").then((d) => setWorkTypes(d.results || [])).catch(() => {});
    api("/materials/").then((d) => setMaterials(d.results || [])).catch(() => {});
  }, []);

  const selectedWorkType = workTypes.find((w) => w.id === form.work_type);
  const computedCost = selectedWorkType ? Number(form.quantity || 0) * Number(selectedWorkType.price_per_unit) : null;

  const addStep = (e) => {
    e.preventDefault();
    setError("");
    const body = { ...form };
    if (!body.work_type) delete body.work_type;
    if (!body.raw_material) {
      delete body.raw_material;
      delete body.cut_piece_length;
      delete body.cut_piece_width;
      delete body.cut_piece_count;
      delete body.cut_note;
    } else {
      if (!body.cut_piece_length) delete body.cut_piece_length;
      if (!body.cut_piece_width) delete body.cut_piece_width;
      if (!body.cut_piece_count) delete body.cut_piece_count;
    }
    if (!body.work_type && !body.raw_material) delete body.quantity;
    api(`/products/${product.id}/workflow-steps/`, { method: "POST", body })
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
                        {s.work_type_name && ` (${s.quantity} ${s.work_type_unit_display} × ${s.work_type_name})`}
                        {s.cutting_instruction
                          ? ` · ${s.cutting_instruction}`
                          : s.raw_material_name && ` · ${s.quantity} ${s.raw_material_unit} ${s.raw_material_name} sarflanadi`}
                        {s.photo_requirement !== "optional" && ` · ${PHOTO_REQUIREMENT[s.photo_requirement]} rasm`}
                        {s.comment_requirement !== "optional" && ` · ${PHOTO_REQUIREMENT[s.comment_requirement]} izoh`}
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
              <label className="label">Ish turi (ixtiyoriy)</label>
              <select
                className="input"
                value={form.work_type}
                onChange={(e) => {
                  const wt = workTypes.find((w) => w.id === e.target.value);
                  setForm({ ...form, work_type: e.target.value, role: wt ? wt.required_role || form.role : form.role });
                }}
              >
                <option value="">Qo'lda kiritish</option>
                {workTypes.map((w) => (
                  <option key={w.id} value={w.id}>{w.name} ({w.price_per_unit} so'm/{w.unit_display})</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Mas'ul rol</label>
              <select
                className="input" value={form.role} disabled={!!selectedWorkType}
                onChange={(e) => setForm({ ...form, role: e.target.value })}
              >
                {Object.entries(POSITIONS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Taxminiy vaqt (soat)</label>
              <input className="input" type="number" step="0.5" min="0" value={form.estimated_hours} onChange={(e) => setForm({ ...form, estimated_hours: e.target.value })} />
            </div>
            {selectedWorkType ? (
              <div>
                <label className="label">Miqdor ({selectedWorkType.unit_display})</label>
                <input className="input" type="number" min="0" step="0.001" value={form.quantity}
                  onChange={(e) => setForm({ ...form, quantity: e.target.value })} />
                <p style={{ fontSize: 11, color: ENT.muted, marginTop: 4 }}>
                  Xarajat avtomatik: {computedCost?.toLocaleString()} so'm
                </p>
              </div>
            ) : (
              <div>
                <label className="label">Xarajat (so'm)</label>
                <input className="input" type="number" min="0" value={form.cost} onChange={(e) => setForm({ ...form, cost: e.target.value })} />
              </div>
            )}
            <div>
              <label className="label">Xom ashyo (ixtiyoriy — ombordan avtomatik ayiriladi)</label>
              <select className="input" value={form.raw_material} onChange={(e) => setForm({ ...form, raw_material: e.target.value })}>
                <option value="">Yo'q</option>
                {materials.map((m) => (
                  <option key={m.id} value={m.id}>{m.name} ({m.unit})</option>
                ))}
              </select>
            </div>
            {form.raw_material && !selectedWorkType && (
              <div>
                <label className="label">Sarflanadigan miqdor</label>
                <input className="input" type="number" min="0" step="0.001" value={form.quantity}
                  onChange={(e) => setForm({ ...form, quantity: e.target.value })} />
              </div>
            )}
            {form.raw_material && (
              <>
                <div>
                  <label className="label">Bo'lak uzunligi, m (ixtiyoriy)</label>
                  <input className="input" type="number" min="0" step="0.001" value={form.cut_piece_length}
                    onChange={(e) => setForm({ ...form, cut_piece_length: e.target.value })} />
                </div>
                <div>
                  <label className="label">Bo'lak kengligi, m (ixtiyoriy)</label>
                  <input className="input" type="number" min="0" step="0.001" value={form.cut_piece_width}
                    onChange={(e) => setForm({ ...form, cut_piece_width: e.target.value })} />
                </div>
                <div>
                  <label className="label">Bo'laklar soni (ixtiyoriy)</label>
                  <input className="input" type="number" min="0" step="1" value={form.cut_piece_count}
                    onChange={(e) => setForm({ ...form, cut_piece_count: e.target.value })} />
                </div>
                <div>
                  <label className="label">Kesish izohi (ixtiyoriy)</label>
                  <input className="input" placeholder="masalan: stol oyoqlari uchun" value={form.cut_note}
                    onChange={(e) => setForm({ ...form, cut_note: e.target.value })} />
                </div>
              </>
            )}
            <div className="sm:col-span-2">
              <label className="label">Kerakli materiallar (izoh, ixtiyoriy)</label>
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
            <div>
              <label className="label">Izoh talabi</label>
              <select className="input" value={form.comment_requirement} onChange={(e) => setForm({ ...form, comment_requirement: e.target.value })}>
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

function BomTab({ product }) {
  const [lines, setLines] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [showPartPicker, setShowPartPicker] = useState(false);
  const [form, setForm] = useState({ material: "", quantity_per_unit: "", cut_length: "", cut_width: "", part_name: "" });
  const glbUrl = product.model3d?.glb_url;

  const load = () =>
    Promise.all([
      api(`/products/${product.id}/bill-of-materials/`),
      api("/materials/"),
    ])
      .then(([bom, mat]) => {
        setLines(bom.results || []);
        setMaterials(mat.results || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [product.id]);

  const addLine = async (e) => {
    e.preventDefault();
    setError("");
    try {
      const material = materials.find((m) => m.id === form.material);
      const isSheet = material?.dimension_type === "sheet";
      const isLinear = material?.dimension_type === "linear" && material?.stock_unit_length;
      await api(`/products/${product.id}/bill-of-materials/`, {
        method: "POST",
        body: {
          ...form,
          cut_length: isSheet || isLinear ? (form.cut_length || null) : null,
          cut_width: isSheet ? (form.cut_width || null) : null,
        },
      });
      setForm({ material: "", quantity_per_unit: "", cut_length: "", cut_width: "", part_name: "" });
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const removeLine = async (id) => {
    if (!confirm("Retsept qatori o'chirilsinmi?")) return;
    try {
      await api(`/products/${product.id}/bill-of-materials/${id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const selectedMaterial = materials.find((m) => m.id === form.material);
  const lineCost = (l) => {
    if (l.cut_width) return Number(l.quantity_per_unit) * Number(l.cut_width) * Number(l.cut_length) * Number(l.material_unit_cost);
    if (l.cut_length) return Number(l.quantity_per_unit) * Number(l.cut_length) * Number(l.material_unit_cost);
    return Number(l.quantity_per_unit) * Number(l.material_unit_cost);
  };
  const totalCost = lines.reduce((n, l) => n + lineCost(l), 0);

  return (
    <Card
      title="Retsept (Bill of Materials)"
      description="1 dona mahsulot ishlab chiqarish uchun kerakli xom ashyo — shundan avtomatik material tannarxi hisoblanadi."
      icon={Layers}
      actions={<EntButton small onClick={() => setShowForm((v) => !v)}>+ Material</EntButton>}
    >
      {showForm && (
        <form onSubmit={addLine} style={{ display: "flex", gap: 12, alignItems: "flex-end", marginBottom: 16, flexWrap: "wrap" }}>
          <div>
            <label className="label">Material</label>
            <select className="input" value={form.material} onChange={(e) => setForm({ ...form, material: e.target.value })} required>
              <option value="">Tanlang…</option>
              {materials.map((m) => (
                <option key={m.id} value={m.id}>{m.name} ({m.unit_display})</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">
              {selectedMaterial?.dimension_type === "sheet" || selectedMaterial?.stock_unit_length
                ? "1 dona uchun bo'laklar soni" : "1 dona uchun miqdor"}
            </label>
            <input className="input" type="number" step={selectedMaterial?.dimension_type === "sheet" || selectedMaterial?.stock_unit_length ? "1" : "0.0001"} min="0" value={form.quantity_per_unit}
              onChange={(e) => setForm({ ...form, quantity_per_unit: e.target.value })} required />
          </div>
          <div>
            <label className="label">3D qism (ixtiyoriy)</label>
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <input className="input" style={{ width: 140 }} readOnly value={form.part_name} placeholder="Belgilanmagan" />
              {glbUrl && (
                <EntButton small type="button" onClick={() => setShowPartPicker(true)}>
                  3D'dan tanlash
                </EntButton>
              )}
              {form.part_name && (
                <button type="button" onClick={() => setForm({ ...form, part_name: "" })}
                  style={{ background: "transparent", border: "none", color: ENT.danger, cursor: "pointer", fontSize: 12 }}>
                  Tozalash
                </button>
              )}
            </div>
          </div>
          {selectedMaterial?.dimension_type === "sheet" ? (
            <>
              <div>
                <label className="label">Har bir bo'lak eni (m)</label>
                <input className="input" type="number" step="0.001" min="0"
                  value={form.cut_width} onChange={(e) => setForm({ ...form, cut_width: e.target.value })} required />
              </div>
              <div>
                <label className="label">Har bir bo'lak bo'yi (m)</label>
                <input className="input" type="number" step="0.001" min="0"
                  value={form.cut_length} onChange={(e) => setForm({ ...form, cut_length: e.target.value })} required />
              </div>
            </>
          ) : selectedMaterial?.stock_unit_length && (
            <div>
              <label className="label">Har bir bo'lak uzunligi (m)</label>
              <input className="input" type="number" step="0.001" min="0" placeholder={`max ${selectedMaterial.stock_unit_length}`}
                value={form.cut_length} onChange={(e) => setForm({ ...form, cut_length: e.target.value })} required />
            </div>
          )}
          <EntButton small type="submit">Qo'shish</EntButton>
        </form>
      )}
      {showPartPicker && glbUrl && (
        <Model3DPartPicker
          glbUrl={glbUrl}
          onClose={() => setShowPartPicker(false)}
          onSelect={(name) => {
            setForm({ ...form, part_name: name });
            setShowPartPicker(false);
          }}
        />
      )}
      {error && <div className="error">{error}</div>}
      {lines.length === 0 ? (
        <p style={{ fontSize: 13, color: ENT.muted }}>
          Hali retsept belgilanmagan — ishlab chiqarish uchun kamida bitta material qo'shing.
        </p>
      ) : (
        <>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {lines.map((l) => (
              <div key={l.id} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "8px 12px", border: `1px solid ${ENT.border}`, borderRadius: 8 }}>
                <span style={{ fontSize: 13, color: ENT.text }}>
                  {l.part_name && (
                    <span style={{ color: ENT.muted, fontSize: 11, marginRight: 6 }}>[{l.part_name}]</span>
                  )}
                  {l.cut_width
                    ? `${l.material_name} — ${l.quantity_per_unit} dona x ${l.cut_width}x${l.cut_length}${l.material_unit}`
                    : l.cut_length
                      ? `${l.material_name} — ${l.quantity_per_unit} dona x ${l.cut_length}${l.material_unit}`
                      : `${l.material_name} — ${l.quantity_per_unit} ${l.material_unit}`}
                </span>
                <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                  <span style={{ fontSize: 12, color: ENT.muted }}>
                    {lineCost(l).toLocaleString()} so'm
                  </span>
                  <button onClick={() => removeLine(l.id)} style={{ background: "transparent", border: "none", color: ENT.danger, cursor: "pointer", display: "flex" }}>
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12, fontSize: 13, fontWeight: 700, color: ENT.text, textAlign: "right" }}>
            Jami material tannarxi (1 dona): {totalCost.toLocaleString()} so'm
          </div>
        </>
      )}
    </Card>
  );
}

function ManufacturedUnitsTab({ product }) {
  const [units, setUnits] = useState([]);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [showSell, setShowSell] = useState(false);
  const [sellForm, setSellForm] = useState({ quantity: "", sale_price_per_unit: "" });
  const [statusFilter, setStatusFilter] = useState("in_stock");

  const load = () =>
    api(`/products/${product.id}/manufactured-units/?status=${statusFilter}`)
      .then((d) => setUnits(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [product.id, statusFilter]);

  const sell = async (e) => {
    e.preventDefault();
    setError("");
    try {
      const resp = await api(`/products/${product.id}/sell-units/`, { method: "POST", body: sellForm });
      setMsg(`Sotildi — sof foyda: ${Number(resp.total_profit).toLocaleString()} so'm`);
      setTimeout(() => setMsg(""), 4000);
      setSellForm({ quantity: "", sale_price_per_unit: "" });
      setShowSell(false);
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <Card
      title="Ishlab chiqarilgan donalar"
      description="Har bir dona o'zining haqiqiy tannarxi bilan alohida kuzatiladi — sotilganda sof foyda aynan shu tannarxdan hisoblanadi (o'rtacha emas)."
      icon={Tag}
      actions={<EntButton small onClick={() => setShowSell((v) => !v)}>Sotish</EntButton>}
    >
      {showSell && (
        <form onSubmit={sell} style={{ display: "flex", gap: 12, alignItems: "flex-end", marginBottom: 16, flexWrap: "wrap" }}>
          <div>
            <label className="label">Soni</label>
            <input className="input" type="number" min="1" value={sellForm.quantity}
              onChange={(e) => setSellForm({ ...sellForm, quantity: e.target.value })} required />
          </div>
          <div>
            <label className="label">Dona narxi (sotuv, so'm)</label>
            <input className="input" type="number" min="0" value={sellForm.sale_price_per_unit}
              onChange={(e) => setSellForm({ ...sellForm, sale_price_per_unit: e.target.value })} required />
          </div>
          <EntButton small type="submit">Tasdiqlash</EntButton>
        </form>
      )}
      {error && <div className="error">{error}</div>}
      {msg && <div style={{ marginBottom: 12 }}><Pill tone="success" icon={TrendingUp}>{msg}</Pill></div>}

      <div style={{ display: "flex", gap: 6, marginBottom: 12 }}>
        {[["in_stock", "Omborda"], ["sold", "Sotilgan"]].map(([k, label]) => (
          <button
            key={k}
            onClick={() => setStatusFilter(k)}
            style={{
              padding: "5px 12px", borderRadius: 999, fontSize: 12.5, fontWeight: 600, cursor: "pointer",
              border: `1px solid ${ENT.border}`,
              background: statusFilter === k ? ENT.primary : "#fff",
              color: statusFilter === k ? "#fff" : ENT.muted,
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {units.length === 0 ? (
        <p style={{ fontSize: 13, color: ENT.muted }}>Bu holatda dona yo'q.</p>
      ) : (
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Seriya</th>
                <th>Tannarx</th>
                {statusFilter === "sold" && <th>Sotuv narxi</th>}
                {statusFilter === "sold" && <th>Sof foyda</th>}
                <th>Sana</th>
              </tr>
            </thead>
            <tbody>
              {units.map((u) => (
                <tr key={u.id}>
                  <td className="font-medium">{u.serial_number}</td>
                  <td>{Number(u.total_cost).toLocaleString()} so'm</td>
                  {statusFilter === "sold" && <td>{Number(u.sale_price).toLocaleString()} so'm</td>}
                  {statusFilter === "sold" && (
                    <td style={{ color: u.profit >= 0 ? ENT.success : ENT.danger, fontWeight: 600 }}>
                      {Number(u.profit).toLocaleString()} so'm
                    </td>
                  )}
                  <td style={{ color: "var(--muted)" }}>{new Date(u.sold_at || u.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
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
