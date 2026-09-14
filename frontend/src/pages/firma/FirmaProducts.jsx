import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Sofa, ChevronRight } from "lucide-react";
import { api } from "../../api";
import LoadMoreButton from "../../components/LoadMoreButton";

export default function FirmaProducts() {
  const [me, setMe] = useState(null);
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    Promise.all([api("/users/me/"), api("/products/"), api("/categories/")])
      .then(([m, ps, cats]) => {
        setMe(m);
        setProducts((ps.results || []).filter((p) => m.company && p.company === m.company.id));
        setNextPage(ps.next || null);
        setCategories(cats.results || []);
      })
      .catch((e) => setError(e.message));

  const loadMore = async () => {
    if (!nextPage || !me?.company) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setProducts((prev) => [...prev, ...(d.results || []).filter((p) => p.company === me.company.id)]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  };

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
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {products.map((p) => (
            <Link
              key={p.id}
              to={`/products/${p.id}`}
              className="card group flex flex-col overflow-hidden p-0 transition-all duration-200 hover:-translate-y-1 hover:shadow-lg"
              style={{ borderColor: "var(--border)" }}
            >
              <div className="relative aspect-square w-full overflow-hidden">
                {(p.image_url || p.images?.[0]?.image_url) ? (
                  <img
                    src={p.image_url || p.images[0].image_url}
                    alt=""
                    className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-110"
                  />
                ) : (
                  <div
                    className="flex h-full w-full items-center justify-center"
                    style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)" }}
                  >
                    <Sofa size={32} />
                  </div>
                )}
                <span
                  className={`absolute right-2 top-2 ${p.is_published ? "badge" : "badge badge-off"}`}
                  style={{ backdropFilter: "blur(4px)" }}
                >
                  {p.is_published ? "Sotuvda" : "Yashirin"}
                </span>
              </div>
              <div className="flex flex-1 items-center justify-between gap-2 p-3">
                <div className="min-w-0">
                  <div className="truncate font-semibold">{p.name_uz}</div>
                  <div className="text-xs" style={{ color: "var(--muted)" }}>
                    {p.variants.length} ta variant
                  </div>
                </div>
                <ChevronRight
                  size={16}
                  className="shrink-0 transition-transform duration-200 group-hover:translate-x-1"
                  style={{ color: "var(--muted)" }}
                />
              </div>
            </Link>
          ))}
        </div>
      )}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

function ProductForm({ categories, onDone }) {
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name_uz: "", category: "", description: "" });
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
      setForm({ name_uz: "", category: "", description: "" });
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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setOpen(false)}>
      <form
        className="card flex w-full max-w-lg flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 className="text-base font-semibold">Yangi mahsulot</h2>
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
    </div>
  );
}
