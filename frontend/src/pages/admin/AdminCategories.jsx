import { useEffect, useState } from "react";
import { api } from "../../api";

export default function AdminCategories() {
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState({ name_uz: "", name_ru: "" });
  const [error, setError] = useState("");

  const load = () =>
    api("/categories/")
      .then((d) => setCategories(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const add = async (e) => {
    e.preventDefault();
    setError("");
    try {
      await api("/categories/", { method: "POST", body: form });
      setForm({ name_uz: "", name_ru: "" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  const remove = async (c) => {
    if (!confirm(`"${c.name_uz}" kategoriyasi o'chirilsinmi?`)) return;
    try {
      await api(`/categories/${c.slug}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <form className="card flex flex-wrap items-end gap-3 p-5" onSubmit={add}>
        <div className="min-w-[180px] flex-1">
          <label className="label">Nomi (uz)</label>
          <input className="input" value={form.name_uz} onChange={(e) => setForm({ ...form, name_uz: e.target.value })} required />
        </div>
        <div className="min-w-[180px] flex-1">
          <label className="label">Nomi (ru)</label>
          <input className="input" value={form.name_ru} onChange={(e) => setForm({ ...form, name_ru: e.target.value })} />
        </div>
        <button className="btn" type="submit">+ Qo'shish</button>
      </form>
      {error && <div className="error">{error}</div>}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Nomi (uz)</th>
              <th>Nomi (ru)</th>
              <th>Slug</th>
              <th className="text-right">Amal</th>
            </tr>
          </thead>
          <tbody>
            {categories.map((c) => (
              <tr key={c.id}>
                <td className="font-medium">{c.name_uz}</td>
                <td>{c.name_ru || "—"}</td>
                <td style={{ color: "var(--muted)" }}>{c.slug}</td>
                <td className="text-right">
                  <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => remove(c)}>
                    O'chirish
                  </button>
                </td>
              </tr>
            ))}
            {categories.length === 0 && (
              <tr>
                <td colSpan={4} style={{ color: "var(--muted)" }}>Kategoriyalar yo'q.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
