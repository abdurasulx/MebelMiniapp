import { useEffect, useState } from "react";
import { api } from "../../api";

const LANGS = [
  ["uz", "O'zbekcha"],
  ["en", "English"],
  ["ru", "Русский"],
  ["tg", "Тоҷикӣ"],
  ["tr", "Türkçe"],
  ["ky", "Кыргызча"],
  ["kk", "Қазақша"],
  ["de", "Deutsch"],
  ["az", "Azərbaycan"],
];

const EMPTY = {
  id: null,
  name: {},
  description: {},
  price_from: "",
  category: "",
  sort_order: 0,
  is_published: true,
  gallery: [],
  image_url: null,
};

const rows = (d) => (Array.isArray(d) ? d : d.results || []);

export default function AdminShowcase() {
  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState(null);
  const [mainImage, setMainImage] = useState(null);
  const [galleryFiles, setGalleryFiles] = useState([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const load = () =>
    api("/showcase/products/?lang=uz")
      .then((d) => setItems(rows(d)))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    api("/categories/")
      .then((d) => setCategories(rows(d)))
      .catch(() => {});
  }, []);

  const open = (item) => {
    setError("");
    setMainImage(null);
    setGalleryFiles([]);
    setForm(
      item
        ? {
            ...EMPTY,
            ...item,
            name: item.name_translations || {},
            description: item.description_translations || {},
            category: item.category || "",
            price_from: item.price_from ?? "",
          }
        : { ...EMPTY },
    );
  };

  const setLang = (field, lang, value) =>
    setForm((f) => ({ ...f, [field]: { ...f[field], [lang]: value } }));

  const clean = (obj) => Object.fromEntries(Object.entries(obj).filter(([, v]) => (v || "").trim()));

  const save = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const payload = {
        name_translations: clean(form.name),
        description_translations: clean(form.description),
        price_from: form.price_from === "" ? null : form.price_from,
        category: form.category || null,
        sort_order: Number(form.sort_order) || 0,
        is_published: form.is_published,
      };
      const saved = form.id
        ? await api(`/showcase/products/${form.id}/`, { method: "PATCH", body: payload })
        : await api("/showcase/products/", { method: "POST", body: payload });
      if (mainImage) {
        const fd = new FormData();
        fd.append("image", mainImage);
        await api(`/showcase/products/${saved.id}/`, { method: "PATCH", body: fd, isForm: true });
      }
      for (const file of galleryFiles) {
        const fd = new FormData();
        fd.append("product", saved.id);
        fd.append("image", file);
        await api("/showcase/images/", { method: "POST", body: fd, isForm: true });
      }
      setForm(null);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const removeGalleryImage = async (img) => {
    try {
      await api(`/showcase/images/${img.id}/`, { method: "DELETE" });
      setForm((f) => ({ ...f, gallery: f.gallery.filter((g) => g.id !== img.id) }));
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const remove = async (item) => {
    if (!confirm(`"${item.name}" vitrinadan o'chirilsinmi?`)) return;
    try {
      await api(`/showcase/products/${item.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="card flex flex-wrap items-center justify-between gap-3 p-5">
        <div>
          <div className="font-bold">Vitrina (demo mahsulotlar)</div>
          <div className="text-sm" style={{ color: "var(--muted)" }}>
            Faol firma yo'q hududdagi foydalanuvchilarga ko'rsatiladi. Firmaga bog'lanmagan, buyurtma berib bo'lmaydi.
          </div>
        </div>
        <button className="btn" onClick={() => open(null)}>+ Mahsulot qo'shish</button>
      </div>

      {error && <div className="error">{error}</div>}

      {form && (
        <form className="card flex flex-col gap-4 p-5" onSubmit={save}>
          <div className="font-bold">{form.id ? "Mahsulotni tahrirlash" : "Yangi vitrina mahsuloti"}</div>

          <div className="grid gap-3 sm:grid-cols-2">
            {LANGS.map(([code, label]) => (
              <div key={code} className="flex flex-col gap-2">
                <div>
                  <label className="label">
                    Nomi — {label}
                    {code === "uz" ? " *" : ""}
                  </label>
                  <input
                    className="input"
                    value={form.name[code] || ""}
                    required={code === "uz"}
                    onChange={(e) => setLang("name", code, e.target.value)}
                  />
                </div>
                <div>
                  <label className="label">Tavsif — {label}</label>
                  <textarea
                    className="input"
                    rows={2}
                    value={form.description[code] || ""}
                    onChange={(e) => setLang("description", code, e.target.value)}
                  />
                </div>
              </div>
            ))}
          </div>

          <div className="grid gap-3 sm:grid-cols-4">
            <div>
              <label className="label">Narx (dan), so'm</label>
              <input
                className="input"
                type="number"
                min="0"
                value={form.price_from}
                onChange={(e) => setForm({ ...form, price_from: e.target.value })}
              />
            </div>
            <div>
              <label className="label">Kategoriya</label>
              <select
                className="input"
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
              >
                <option value="">—</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name_uz}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Tartib raqami</label>
              <input
                className="input"
                type="number"
                value={form.sort_order}
                onChange={(e) => setForm({ ...form, sort_order: e.target.value })}
              />
            </div>
            <label className="flex items-end gap-2 pb-2 text-sm font-medium">
              <input
                type="checkbox"
                checked={form.is_published}
                onChange={(e) => setForm({ ...form, is_published: e.target.checked })}
              />
              Nashr qilingan
            </label>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <label className="label">Asosiy rasm</label>
              {form.image_url && !mainImage && (
                <img src={form.image_url} alt="" className="mb-2 h-24 rounded-lg object-contain" style={{ background: "var(--surface-muted)" }} />
              )}
              <input type="file" accept="image/*" onChange={(e) => setMainImage(e.target.files?.[0] || null)} />
            </div>
            <div>
              <label className="label">Qo'shimcha rasmlar</label>
              <div className="mb-2 flex flex-wrap gap-2">
                {form.gallery.map((g) => (
                  <div key={g.id} className="relative">
                    <img src={g.url} alt="" className="h-16 w-16 rounded-lg object-cover" />
                    <button
                      type="button"
                      className="absolute -right-1 -top-1 h-5 w-5 rounded-full text-xs"
                      style={{ background: "var(--danger)", color: "#fff" }}
                      onClick={() => removeGalleryImage(g)}
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
              <input
                type="file"
                accept="image/*"
                multiple
                onChange={(e) => setGalleryFiles(Array.from(e.target.files || []))}
              />
            </div>
          </div>

          <div className="flex gap-2">
            <button className="btn" type="submit" disabled={busy}>
              {busy ? "Saqlanmoqda…" : "Saqlash"}
            </button>
            <button className="btn-ghost" type="button" onClick={() => setForm(null)}>
              Bekor
            </button>
          </div>
        </form>
      )}

      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th></th>
              <th>Nomi</th>
              <th>Tillar</th>
              <th>Narx (dan)</th>
              <th>Holat</th>
              <th className="text-right">Amal</th>
            </tr>
          </thead>
          <tbody>
            {items.map((it) => (
              <tr key={it.id}>
                <td>
                  {it.image_url ? (
                    <img src={it.image_url} alt="" className="h-12 w-12 rounded-lg object-cover" />
                  ) : (
                    <div className="h-12 w-12 rounded-lg" style={{ background: "var(--surface-muted)" }} />
                  )}
                </td>
                <td className="font-medium">{it.name}</td>
                <td style={{ color: "var(--muted)" }}>
                  {Object.keys(it.name_translations || {}).length}/{LANGS.length}
                </td>
                <td>{it.price_from ? `${Number(it.price_from).toLocaleString("ru-RU")} so'm` : "—"}</td>
                <td>
                  <span className={`badge ${it.is_published ? "" : "badge-off"}`}>
                    {it.is_published ? "Nashr qilingan" : "Qoralama"}
                  </span>
                </td>
                <td className="text-right">
                  <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => open(it)}>
                    Tahrirlash
                  </button>{" "}
                  <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => remove(it)}>
                    O'chirish
                  </button>
                </td>
              </tr>
            ))}
            {items.length === 0 && (
              <tr>
                <td colSpan={6} style={{ color: "var(--muted)" }}>Vitrina mahsulotlari yo'q.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
