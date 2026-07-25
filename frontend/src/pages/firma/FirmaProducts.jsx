import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Sofa, ChevronRight } from "lucide-react";
import { api } from "../../api";

export default function FirmaProducts() {
  const [me, setMe] = useState(null);
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [error, setError] = useState("");

  const load = () =>
    Promise.all([api("/users/me/"), api("/products/"), api("/categories/")])
      .then(([m, ps, cats]) => {
        setMe(m);
        setProducts((ps.results || []).filter((p) => m.company && p.company === m.company.id));
        setCategories(cats.results || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  if (error) return <div className="error">{error}</div>;
  if (!me) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;
  if (!me.company)
    return (
      <div className="card mx-auto max-w-md p-6 text-center">
        <p className="mb-3 text-sm" style={{ color: "var(--muted)" }}>
          Mahsulot joylash uchun avval kompaniya yarating.
        </p>
        <Link to="/settings" className="btn">Kompaniya yaratish</Link>
      </div>
    );

  return (
    <div className="flex flex-col gap-4">
      <ProductForm categories={categories} onDone={load} />
      {products.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Hali mahsulot yo'q.</p>
      )}
      {products.length > 0 && (
        <div className="card flex flex-col divide-y" style={{ borderColor: "var(--border)" }}>
          {products.map((p) => (
            <Link
              key={p.id}
              to={`/products/${p.id}`}
              className="flex items-center gap-3 p-4 transition hover:bg-black/5"
              style={{ borderColor: "var(--border)" }}
            >
              {(p.image_url || p.images?.[0]?.image_url) ? (
                <img src={p.image_url || p.images[0].image_url} alt="" className="h-12 w-12 shrink-0 rounded-lg object-cover" />
              ) : (
                <div
                  className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg"
                  style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)" }}
                >
                  <Sofa size={18} />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="truncate font-semibold">{p.name_uz}</span>
                  <span className={p.is_published ? "badge" : "badge badge-off"}>
                    {p.is_published ? "Sotuvda" : "Yashirin"}
                  </span>
                </div>
                <div className="text-xs" style={{ color: "var(--muted)" }}>
                  {p.variants.length} ta variant
                </div>
              </div>
              <ChevronRight size={18} style={{ color: "var(--muted)" }} />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

function ProductForm({ categories, onDone }) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name_uz: "", name_ru: "", category: "", description: "", video_url: "" });
  const [image, setImage] = useState(null);
  const [error, setError] = useState("");
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => v && fd.append(k, v));
      if (image) fd.append("image", image);
      await api("/products/", { method: "POST", body: fd, isForm: true });
      setForm({ name_uz: "", name_ru: "", category: "", description: "", video_url: "" });
      setImage(null);
      setOpen(false);
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  if (!open)
    return (
      <div>
        <button className="btn" onClick={() => setOpen(true)}>+ Yangi mahsulot</button>
      </div>
    );

  return (
    <form className="card flex flex-col gap-4 p-5" onSubmit={submit}>
      <h2 className="text-base font-semibold">Yangi mahsulot</h2>
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
          <textarea className="input" rows={2} value={form.description} onChange={set("description")} />
        </div>
        <div className="sm:col-span-2">
          <label className="label">Asosiy rasm</label>
          <input type="file" accept="image/*" className="input" onChange={(e) => setImage(e.target.files[0])} />
        </div>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="flex gap-2">
        <button className="btn" type="submit">Saqlash</button>
        <button className="btn-ghost" type="button" onClick={() => setOpen(false)}>Bekor</button>
      </div>
    </form>
  );
}
