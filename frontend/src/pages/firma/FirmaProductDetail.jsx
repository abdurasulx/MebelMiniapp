import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ArrowLeft, Box, Check, Images, Lock, Link2, Unlock, Workflow, Trash2, ArrowUp, ArrowDown, X } from "lucide-react";
import { api } from "../../api";
import ModelViewer from "../../components/ModelViewer";
import { POSITIONS } from "../../positions";

const PHOTO_REQUIREMENT = {
  required: "Majburiy",
  optional: "Ixtiyoriy",
  disabled: "Kerak emas",
};

/**
 * Bitta mahsulotni to'liq tahrirlash sahifasi — asosiy ma'lumot, galereya,
 * 3D model, variantlar va ishlab chiqarish jarayoni shu yerda, bitta joyda.
 * Ro'yxat sahifasi (`FirmaProducts`) endi faqat mahsulotlarni ko'rsatib,
 * shu yerga havola beradi — 100+ mahsulot bo'lganda ham boshqarish oson
 * bo'lishi uchun.
 */
export default function FirmaProductDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [categories, setCategories] = useState([]);
  const [error, setError] = useState("");

  const load = () =>
    Promise.all([api(`/products/${id}/`), api("/categories/")])
      .then(([p, cats]) => {
        setProduct(p);
        setCategories(cats.results || []);
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
      const updated = await api(`/products/${id}/`, {
        method: "PATCH",
        body: { is_published: !product.is_published },
      });
      setProduct(updated);
    } catch (err) {
      setError(err.message);
    }
  };

  if (error) return <div className="error">{error}</div>;
  if (!product) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="flex flex-col gap-6 pb-10">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Link to="/products" className="btn-ghost inline-flex items-center gap-1.5 !px-3 !py-1.5 text-sm">
          <ArrowLeft size={15} /> Mahsulotlar
        </Link>
        <div className="flex flex-wrap gap-2">
          <button className="btn !px-3 !py-1.5 text-xs" onClick={togglePublish}>
            {product.is_published ? "Yashirish" : "Sotuvga chiqarish"}
          </button>
          <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={remove}>
            O'chirish
          </button>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <h1 className="text-xl font-bold">{product.name_uz}</h1>
        <span className={product.is_published ? "badge" : "badge badge-off"}>
          {product.is_published ? "Sotuvda" : "Yashirin"}
        </span>
      </div>

      <BasicInfoForm product={product} categories={categories} onDone={load} />
      <GalleryForm product={product} onDone={load} />
      <div className="card p-5">
        <Model3DForm product={product} onDone={load} />
      </div>
      <VariantsSection product={product} onDone={load} />
      <div className="card p-5">
        <WorkflowEditor product={product} />
      </div>
    </div>
  );
}

function BasicInfoForm({ product, categories, onDone }) {
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
    <form className="card flex flex-col gap-4 p-5" onSubmit={submit}>
      <h2 className="text-base font-semibold">Asosiy ma'lumot</h2>
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
          <input className="input" value={form.video_url} onChange={set("video_url")} />
        </div>
        <div className="sm:col-span-2">
          <label className="label">Tavsif</label>
          <textarea className="input" rows={3} value={form.description} onChange={set("description")} />
        </div>
        <div className="sm:col-span-2">
          <label className="label">Asosiy rasm</label>
          <div className="flex items-center gap-3">
            {product.image_url && (
              <img src={product.image_url} alt="" className="h-14 w-14 rounded-xl object-cover" />
            )}
            <input className="input" type="file" accept="image/*" onChange={(e) => setImage(e.target.files[0])} />
          </div>
        </div>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="flex items-center gap-2">
        <button className="btn" type="submit" disabled={busy}>
          {busy ? "Saqlanmoqda…" : "Saqlash"}
        </button>
        {msg && <span className="badge">{msg}</span>}
      </div>
    </form>
  );
}

function GalleryForm({ product, onDone }) {
  const [file, setFile] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const upload = async (e) => {
    e.preventDefault();
    if (!file) return;
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      fd.append("image", file);
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
    <div className="card flex flex-col gap-3 p-5">
      <span className="inline-flex items-center gap-1.5 text-base font-semibold">
        <Images size={16} /> Qo'shimcha rasmlar
      </span>
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        Asosiy rasmdan tashqari bir nechta rasm qo'shishingiz mumkin (masalan loyiha
        mahsuloti uchun xonaning turli burchaklari).
      </p>

      {product.images?.length > 0 && (
        <div className="flex flex-wrap gap-3">
          {product.images.map((img) => (
            <div key={img.id} className="group relative">
              <img src={img.image_url} alt="" className="h-20 w-20 rounded-lg object-cover" />
              <button
                type="button"
                onClick={() => remove(img.id)}
                className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full"
                style={{ background: "#e74c3c", color: "#fff" }}
                title="O'chirish"
              >
                <X size={12} />
              </button>
            </div>
          ))}
        </div>
      )}

      <form className="flex items-end gap-3" onSubmit={upload}>
        <div className="flex-1">
          <label className="label">Yangi rasm</label>
          <input className="input" type="file" accept="image/*" onChange={(e) => setFile(e.target.files[0])} />
        </div>
        <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy || !file}>
          {busy ? "Yuklanmoqda…" : "Qo'shish"}
        </button>
      </form>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

function VariantsSection({ product: p, onDone }) {
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
    <div className="card flex flex-col gap-4 p-5">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-semibold">Variantlar</h2>
        <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => setShowVariant(!showVariant)}>
          + Variant
        </button>
      </div>

      {p.variants.length > 0 ? (
        <div className="flex flex-col gap-2">
          <div className="overflow-x-auto">
            <table className="table">
              <thead>
                <tr>
                  <th>Variant</th>
                  <th>Narx (m³)</th>
                  <th>Standart o'lcham</th>
                  <th>Rang / material</th>
                </tr>
              </thead>
              <tbody>
                {p.variants.map((v) => (
                  <tr key={v.id}>
                    <td className="font-medium">{v.name}</td>
                    <td>{Number(v.base_price).toLocaleString()} so'm</td>
                    <td>{v.width} × {v.height} × {v.depth} m</td>
                    <td>
                      <button
                        className="inline-flex items-center gap-2 rounded-lg px-2 py-1 text-xs transition hover:bg-black/5"
                        onClick={() => setEditColorFor(editColorFor === v.id ? null : v.id)}
                      >
                        <span
                          className="h-5 w-5 rounded-full"
                          style={{
                            background: v.texture_url ? `url(${v.texture_url}) center/cover` : v.color_hex || "var(--border)",
                            border: "1px solid var(--border)",
                          }}
                        />
                        {v.color_hex || "Tanlanmagan"}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {p.variants
            .filter((v) => v.id === editColorFor)
            .map((v) => (
              <VariantColorForm key={v.id} variant={v} onDone={onDone} />
            ))}
        </div>
      ) : (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali variant qo'shilmagan.</p>
      )}

      {showVariant && (
        <form className="flex flex-wrap items-end gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }} onSubmit={addVariant}>
          <div className="min-w-[150px]">
            <label className="label">Nomi (material)</label>
            <input className="input" value={variant.name} onChange={(e) => setVariant({ ...variant, name: e.target.value })} required />
          </div>
          <div className="min-w-[150px]">
            <label className="label">Narx (1 m³, so'm)</label>
            <input className="input" type="number" min="0" value={variant.base_price}
              onChange={(e) => setVariant({ ...variant, base_price: e.target.value })} required />
          </div>
          {[["width", "Eni"], ["height", "Bo'yi"], ["depth", "Chuquri"]].map(([k, label]) => (
            <div key={k} className="w-24">
              <label className="label">{label} (m)</label>
              <input className="input" type="number" step="0.1" min="0.1" value={variant[k]}
                onChange={(e) => setVariant({ ...variant, [k]: e.target.value })} />
            </div>
          ))}
          <button className="btn" type="submit">Qo'shish</button>
        </form>
      )}
      {error && <div className="error">{error}</div>}
    </div>
  );
}

const EMPTY_STEP = {
  name: "", role: "usta", estimated_hours: 1, cost: 0, required_materials: "", photo_requirement: "optional",
};

function WorkflowEditor({ product }) {
  const [steps, setSteps] = useState(null);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_STEP);

  const load = () =>
    api(`/products/${product.id}/workflow-steps/`)
      .then((d) => setSteps(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, [product.id]);

  const addStep = (e) => {
    e.preventDefault();
    setError("");
    api(`/products/${product.id}/workflow-steps/`, { method: "POST", body: form })
      .then(() => {
        setForm(EMPTY_STEP);
        setShowForm(false);
        load();
      })
      .catch((e) => setError(e.message));
  };

  const removeStep = (id) => {
    if (!confirm("Bosqich o'chirilsinmi?")) return;
    api(`/products/${product.id}/workflow-steps/${id}/`, { method: "DELETE" })
      .then(load)
      .catch((e) => setError(e.message));
  };

  const move = (step, direction) => {
    const idx = steps.findIndex((s) => s.id === step.id);
    const target = steps[idx + direction];
    if (!target) return;
    Promise.all([
      api(`/products/${product.id}/workflow-steps/${step.id}/`, {
        method: "PATCH",
        body: { order_index: target.order_index },
      }),
      api(`/products/${product.id}/workflow-steps/${target.id}/`, {
        method: "PATCH",
        body: { order_index: step.order_index },
      }),
    ])
      .then(load)
      .catch((e) => setError(e.message));
  };

  const totalCost = (steps || []).reduce((n, s) => n + Number(s.cost || 0), 0);
  const totalHours = (steps || []).reduce((n, s) => n + Number(s.estimated_hours || 0), 0);

  return (
    <div className="flex flex-col gap-3">
      <span className="inline-flex items-center gap-1.5 text-base font-semibold">
        <Workflow size={16} /> Ishlab chiqarish jarayoni
      </span>
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        Har mahsulot uchun ishlab chiqarish bosqichlari zanjiri — buyurtma tushganda shu
        zanjir nusxalanadi va har bosqich mustaqil kuzatiladi. Bosqich avtomatik ravishda
        oldingisiga bog'lanadi (ketma-ket zanjir); tarmoqlanish (DAG) keyingi bosqichda
        vizual muharrirga qo'shiladi.
      </p>

      {steps === null ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>
      ) : steps.length === 0 ? (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali bosqich qo'shilmagan.</p>
      ) : (
        <div className="flex flex-col gap-2">
          {steps.map((s, i) => {
            const Icon = POSITIONS[s.role]?.icon;
            return (
              <div key={s.id} className="card flex flex-wrap items-center gap-3 p-3">
                <span className="w-5 text-center text-xs font-bold" style={{ color: "var(--muted)" }}>{i + 1}</span>
                <div
                  className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  {Icon && <Icon size={16} />}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium">{s.name}</div>
                  <div className="text-xs" style={{ color: "var(--muted)" }}>
                    {POSITIONS[s.role]?.label || s.role} · {s.estimated_hours} soat · {Number(s.cost).toLocaleString()} so'm
                    {s.photo_requirement !== "optional" && ` · ${PHOTO_REQUIREMENT[s.photo_requirement]} rasm`}
                  </div>
                </div>
                <div className="flex items-center gap-1">
                  <button className="icon-btn" title="Yuqoriga" disabled={i === 0} onClick={() => move(s, -1)}>
                    <ArrowUp size={13} />
                  </button>
                  <button className="icon-btn" title="Pastga" disabled={i === steps.length - 1} onClick={() => move(s, 1)}>
                    <ArrowDown size={13} />
                  </button>
                  <button className="icon-btn" title="O'chirish" onClick={() => removeStep(s.id)}>
                    <Trash2 size={13} style={{ color: "#e74c3c" }} />
                  </button>
                </div>
              </div>
            );
          })}
          <div className="flex justify-end gap-4 px-3 text-xs" style={{ color: "var(--muted)" }}>
            <span>Jami vaqt: {totalHours} soat</span>
            <span>Jami xarajat: {totalCost.toLocaleString()} so'm</span>
          </div>
        </div>
      )}

      {error && <div className="error">{error}</div>}

      {showForm ? (
        <form className="flex flex-col gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }} onSubmit={addStep}>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="label">Bosqich nomi *</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Mas'ul rol</label>
              <select className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                {Object.entries(POSITIONS).map(([k, v]) => (
                  <option key={k} value={k}>{v.label}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Taxminiy vaqt (soat)</label>
              <input className="input" type="number" step="0.5" min="0" value={form.estimated_hours}
                onChange={(e) => setForm({ ...form, estimated_hours: e.target.value })} />
            </div>
            <div>
              <label className="label">Xarajat (so'm)</label>
              <input className="input" type="number" min="0" value={form.cost}
                onChange={(e) => setForm({ ...form, cost: e.target.value })} />
            </div>
            <div className="sm:col-span-2">
              <label className="label">Kerakli materiallar (ixtiyoriy)</label>
              <input className="input" value={form.required_materials}
                onChange={(e) => setForm({ ...form, required_materials: e.target.value })} />
            </div>
            <div>
              <label className="label">Rasm talabi</label>
              <select className="input" value={form.photo_requirement}
                onChange={(e) => setForm({ ...form, photo_requirement: e.target.value })}>
                <option value="required">Majburiy</option>
                <option value="optional">Ixtiyoriy</option>
                <option value="disabled">Kerak emas</option>
              </select>
            </div>
          </div>
          <div className="flex gap-2">
            <button className="btn !px-3 !py-1.5 text-xs" type="submit">Qo'shish</button>
            <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setShowForm(false)}>Bekor</button>
          </div>
        </form>
      ) : (
        <button className="btn-ghost self-start !px-3 !py-1.5 text-xs" onClick={() => setShowForm(true)}>
          + Bosqich qo'shish
        </button>
      )}
    </div>
  );
}

const GLB_SOURCE_EXTENSIONS = [".glb", ".gltf"];

function Model3DForm({ product, onDone }) {
  const [glb, setGlb] = useState(null);
  const [usdz, setUsdz] = useState(null);
  const [textureArchive, setTextureArchive] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const m = product.model3d;

  // GLB yuklanganda server fonda USDZ'ni avtomatik generatsiya qiladi
  // (Blender orqali) — shu vaqtda status "processing" bo'ladi, tayyor
  // bo'lgach avtomatik yangilanishi uchun bir necha soniyada qayta so'raymiz.
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
      await api(m ? `/models3d/${m.id}/` : "/models3d/", {
        method: m ? "PATCH" : "POST",
        body: fd,
        isForm: true,
      });
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

  return (
    <div>
      <div className="mb-3 flex items-center gap-2">
        <span className="inline-flex items-center gap-1.5 text-base font-semibold"><Box size={16} /> 3D model</span>
        {m && (
          <span className={m.status === "processing" ? "badge badge-off" : "badge"}>
            {m.status === "processing" ? "Fayl qayta ishlanmoqda…" : m.status_display}
          </span>
        )}
      </div>
      <p className="mb-3 text-xs" style={{ color: "var(--muted)" }}>
        Bitta 3D model butun mahsulotga tegishli — har rang variant o'z rangini
        variantlar jadvalidan oladi, alohida model yuklash shart emas.
      </p>

      {m?.glb_url && m.status !== "processing" && (
        <div className="mb-3 max-w-sm">
          <ModelViewer glb={m.glb_url} usdz={m.usdz_url} poster={product.image_url} style={{ height: "220px" }} />
        </div>
      )}

      <form className="flex flex-col gap-3" onSubmit={submit}>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div>
            <label className="label">3D fayl (GLB yoki FBX/OBJ) *</label>
            <input className="input" type="file" accept=".glb,.gltf,.fbx,.obj" onChange={(e) => setGlb(e.target.files[0])} />
            {m?.glb_url && <span className="text-xs" style={{ color: "var(--muted)" }}>Mavjud — almashtirish uchun tanlang</span>}
          </div>
          <div>
            <label className="label">USDZ fayl (iOS AR) — qo'lda ustunlik berish, ixtiyoriy</label>
            <input className="input" type="file" accept=".usdz" onChange={(e) => setUsdz(e.target.files[0])} />
            {!usdz && (
              <span className="text-xs" style={{ color: "var(--muted)" }}>
                Bo'sh qoldirsangiz, GLB'dan server avtomatik USDZ yasaydi
              </span>
            )}
          </div>
          <div className="sm:col-span-2">
            <label className="label">Tekstura arxivi (.zip yoki .rar) — FBX/OBJ bilan birga, ixtiyoriy</label>
            <input
              className="input"
              type="file"
              accept=".zip,.rar"
              onChange={(e) => setTextureArchive(e.target.files[0])}
            />
            <span className="text-xs" style={{ color: "var(--muted)" }}>
              {glb && GLB_SOURCE_EXTENSIONS.some((ext) => glb.name.toLowerCase().endsWith(ext))
                ? "GLB fayl tanlandi — bu maydon shu safar ta'sir qilmaydi (faqat FBX/OBJ bilan ishlaydi)"
                : "FBX/OBJ fayl tekstura rasmlariga faqat havola saqlaydi — haqiqiy rasmlarni (.zip qilib) yuqoridagi 3D fayl bilan bir vaqtda shu yerga qo'shsangiz, server ularni fayl nomi bo'yicha avtomatik moslashtirib ulaydi"}
            </span>
          </div>
        </div>
        {error && <div className="error">{error}</div>}
        <div className="flex gap-2">
          <button className="btn" type="submit" disabled={busy}>
            {busy ? "Yuklanmoqda…" : m ? "Yangilash" : "Yuklash"}
          </button>
          {m && (
            <button type="button" className="btn-danger" onClick={remove}>
              3D ni o'chirish
            </button>
          )}
        </div>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          GLB, FBX yoki OBJ formatida yuklashingiz mumkin — FBX/OBJ bo'lsa server
          avtomatik GLB'ga aylantiradi, so'ng iOS AR uchun kerak bo'ladigan USDZ
          faylni ham o'zi yasaydi (bir necha soniya). USDZ'ni qo'lda yuklasangiz,
          avtomatik generatsiya o'rniga o'sha fayl ishlatiladi.
        </p>
      </form>

      {m && <ShareSettings model={m} onDone={onDone} />}
    </div>
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
      await api(`/products/${variant.product}/variants/${variant.id}/`, {
        method: "PATCH",
        body: fd,
        isForm: true,
      });
      setTexture(null);
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      className="flex flex-wrap items-end gap-3 rounded-xl p-4"
      style={{ border: "1px dashed var(--border)", background: "color-mix(in srgb, var(--primary) 8%, transparent)" }}
      onSubmit={submit}
    >
      <div>
        <label className="label">{variant.name} — rang</label>
        <input className="input !w-16 !p-1" type="color" value={colorHex} onChange={(e) => setColorHex(e.target.value)} />
      </div>
      <div>
        <label className="label">Yog'och naqshi surati (ixtiyoriy)</label>
        <input className="input" type="file" accept="image/*" onChange={(e) => setTexture(e.target.files[0])} />
        {variant.texture_url && !texture && (
          <span className="text-xs" style={{ color: "var(--muted)" }}>Mavjud — almashtirish uchun tanlang</span>
        )}
      </div>
      {error && <div className="error">{error}</div>}
      <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
        {busy ? "Saqlanmoqda…" : "Saqlash"}
      </button>
      <p className="w-full text-xs" style={{ color: "var(--muted)" }}>
        Bu rang/naqsh yuqoridagi bitta 3D modelga runtime'da qo'llanadi — alohida model
        yuklash shart emas.
      </p>
    </form>
  );
}

const VISIBILITY_OPTIONS = [
  { value: "private", label: "Yopiq — faqat firma a'zolari", icon: Lock },
  { value: "restricted", label: "Cheklangan — faqat ro'yxatdagi shaxslar", icon: Link2 },
  { value: "public", label: "Ochiq — havola bilan hamma", icon: Unlock },
];

function ShareSettings({ model, onDone }) {
  const [visibility, setVisibility] = useState(model.visibility);
  const [emailsText, setEmailsText] = useState((model.allowed_emails || []).join(", "));
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [busy, setBusy] = useState(false);

  const shareUrl = `${window.location.protocol}//${window.location.host}/viewer/${model.share_token}/`;

  const save = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const allowed_emails = emailsText
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      await api(`/models3d/${model.id}/`, {
        method: "PATCH",
        body: { visibility, allowed_emails },
      });
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

  return (
    <form
      className="mt-4 flex flex-col gap-3 border-t pt-4"
      style={{ borderColor: "var(--border)" }}
      onSubmit={save}
    >
      <span className="inline-flex items-center gap-1.5 text-sm font-semibold"><Link2 size={15} /> Ulashish sozlamalari</span>
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-[240px] flex-1">
          <label className="label">Kim ko'ra oladi</label>
          <select className="input" value={visibility} onChange={(e) => setVisibility(e.target.value)}>
            {VISIBILITY_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>
        <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
          {busy ? "Saqlanmoqda…" : "Saqlash"}
        </button>
      </div>
      {visibility === "restricted" && (
        <div>
          <label className="label">Ruxsat etilgan emaillar (vergul bilan ajrating)</label>
          <input
            className="input"
            value={emailsText}
            onChange={(e) => setEmailsText(e.target.value)}
            placeholder="mijoz1@mail.com, mijoz2@mail.com"
          />
        </div>
      )}
      <div className="flex items-center gap-2 rounded-lg p-2" style={{ background: "var(--bg)" }}>
        <code className="flex-1 truncate text-xs" style={{ color: "var(--muted)" }}>{shareUrl}</code>
        <button type="button" className="btn-ghost !px-3 !py-1 text-xs" onClick={copyLink}>
          Nusxalash
        </button>
      </div>
      {error && <div className="error">{error}</div>}
      {msg && <span className="badge self-start">{msg}</span>}
    </form>
  );
}
