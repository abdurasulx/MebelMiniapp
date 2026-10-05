import { useEffect, useState } from "react";
import { Pencil, Plus, Smartphone } from "lucide-react";
import { api } from "../../api";

const STATUS = {
  active: { label: "Active", color: "var(--success)" },
  update_required: { label: "Update Required", color: "#f39c12" },
  blocked: { label: "Blocked", color: "var(--danger)" },
};
const PLATFORM = { android: "Android", ios: "iOS" };

const EMPTY = {
  version: "", platform: "android", status: "active", force_update: false,
  store_url: "", update_message: "", release_date: "",
};

// <input type="datetime-local"> qiymati (yyyy-MM-ddTHH:mm) <-> ISO
const toLocalInput = (iso) => (iso ? new Date(iso).toISOString().slice(0, 16) : "");

/// SuperAdmin → Versiya nazorati. Eski versiyalar o'chirilmaydi (tarix) —
/// faqat yaratish, tahrirlash va ko'rish (backend DELETE'ga 405 qaytaradi).
export default function AdminAppVersions() {
  const [rows, setRows] = useState([]);
  const [latest, setLatest] = useState({});
  const [error, setError] = useState("");
  const [filters, setFilters] = useState({ platform: "", status: "", version: "" });
  const [form, setForm] = useState(null); // null = yopiq, {id?...} = ochiq
  const [saving, setSaving] = useState(false);

  const load = () => {
    const qs = new URLSearchParams(Object.entries(filters).filter(([, v]) => v)).toString();
    return api(`/admin/app-versions/${qs ? `?${qs}` : ""}`)
      .then((d) => {
        setRows(d.results || []);
        setLatest(d.latest || {});
      })
      .catch((e) => setError(e.message));
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filters]);

  const save = async (e) => {
    e.preventDefault();
    setError("");
    setSaving(true);
    try {
      const body = {
        version: form.version.trim(),
        platform: form.platform,
        status: form.status,
        force_update: form.status === "blocked" ? true : form.force_update,
        store_url: form.store_url.trim(),
        update_message: form.update_message,
        release_date: form.release_date ? new Date(form.release_date).toISOString() : null,
      };
      if (form.id) await api(`/admin/app-versions/${form.id}/`, { method: "PATCH", body });
      else await api("/admin/app-versions/", { method: "POST", body });
      setForm(null);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const edit = (r) => {
    setError("");
    setForm({ ...r, release_date: toLocalInput(r.release_date) });
  };

  const set = (k) => (e) =>
    setForm({ ...form, [k]: e.target.type === "checkbox" ? e.target.checked : e.target.value });

  const blocked = rows.filter((r) => r.status === "blocked").length;
  const updateRequired = rows.filter((r) => r.status === "update_required").length;

  return (
    <div className="flex flex-col gap-4">
      <div className="card p-5">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
          <h2 className="inline-flex items-center gap-2 text-base font-semibold">
            <Smartphone size={17} /> Versiya nazorati
          </h2>
          <button className="btn inline-flex items-center gap-1" onClick={() => { setError(""); setForm({ ...EMPTY }); }}>
            <Plus size={15} /> Yangi versiya
          </button>
        </div>
        <div className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
          <div><div className="text-xs" style={{ color: "var(--muted)" }}>Android — oxirgi</div><b>{latest.android || "—"}</b></div>
          <div><div className="text-xs" style={{ color: "var(--muted)" }}>iOS — oxirgi</div><b>{latest.ios || "—"}</b></div>
          <div><div className="text-xs" style={{ color: "var(--muted)" }}>Blocked</div><b>{blocked}</b></div>
          <div><div className="text-xs" style={{ color: "var(--muted)" }}>Update Required</div><b>{updateRequired}</b></div>
        </div>
        <p className="mt-3 text-xs" style={{ color: "var(--muted)" }}>
          Android va iOS alohida boshqariladi. Eski versiyalar o'chirilmaydi — tarix saqlanadi. Ro'yxatda
          bo'lmagan versiya: eng yangisidan katta bo'lsa ruxsat, eng eski ruxsat etilganidan kichik bo'lsa
          Blocked, oralig'ida bo'lsa o'zidan pastroq eng yaqin yozuv holatini oladi.
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <select className="input !w-auto" value={filters.platform} onChange={(e) => setFilters({ ...filters, platform: e.target.value })}>
          <option value="">Barcha platformalar</option>
          <option value="android">Android</option>
          <option value="ios">iOS</option>
        </select>
        <select className="input !w-auto" value={filters.status} onChange={(e) => setFilters({ ...filters, status: e.target.value })}>
          <option value="">Barcha holatlar</option>
          {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
        </select>
        <input className="input !w-40" placeholder="Versiya (2.4)" value={filters.version}
          onChange={(e) => setFilters({ ...filters, version: e.target.value })} />
      </div>

      {error && !form && <div className="error">{error}</div>}

      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs" style={{ color: "var(--muted)" }}>
              <th className="p-3">Versiya</th><th className="p-3">Platforma</th><th className="p-3">Holat</th>
              <th className="p-3">Force update</th><th className="p-3">Release date</th><th className="p-3">Updated</th><th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr><td colSpan={7} className="p-4" style={{ color: "var(--muted)" }}>Hali versiya yo'q.</td></tr>
            )}
            {rows.map((r) => (
              <tr key={r.id} className="border-t" style={{ borderColor: "var(--border)" }}>
                <td className="p-3 font-semibold">{r.version}</td>
                <td className="p-3">{PLATFORM[r.platform]}</td>
                <td className="p-3">
                  <span className="rounded-full px-2 py-0.5 text-[11px] font-medium"
                    style={{ background: `color-mix(in srgb, ${STATUS[r.status].color} 16%, transparent)`, color: STATUS[r.status].color }}>
                    {STATUS[r.status].label}
                  </span>
                </td>
                <td className="p-3">{r.force_update ? "Ha" : "Yo'q"}</td>
                <td className="p-3">{r.release_date ? new Date(r.release_date).toLocaleDateString("uz-UZ") : "—"}</td>
                <td className="p-3">{new Date(r.updated_at).toLocaleString("uz-UZ")}</td>
                <td className="p-3 text-right">
                  <button className="btn-ghost !px-2 !py-1.5" title="Tahrirlash" onClick={() => edit(r)}><Pencil size={14} /></button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setForm(null)}>
          <form className="card flex w-full max-w-lg flex-col gap-3 p-6" onClick={(e) => e.stopPropagation()} onSubmit={save}>
            <h3 className="text-base font-semibold">{form.id ? "Versiyani tahrirlash" : "Yangi versiya"}</h3>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="label">Versiya *</label>
                <input className="input" placeholder="2.4.0" value={form.version} onChange={set("version")} required pattern="\d+\.\d+\.\d+" title="major.minor.patch, masalan 2.4.0" />
              </div>
              <div>
                <label className="label">Platforma *</label>
                <select className="input" value={form.platform} onChange={set("platform")}>
                  <option value="android">Android</option>
                  <option value="ios">iOS</option>
                </select>
              </div>
              <div>
                <label className="label">Holat</label>
                <select className="input" value={form.status} onChange={set("status")}>
                  {Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
                </select>
              </div>
              <div>
                <label className="label">Release date</label>
                <input className="input" type="datetime-local" value={form.release_date} onChange={set("release_date")} />
              </div>
            </div>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={form.status === "blocked" ? true : form.force_update}
                disabled={form.status === "blocked"} onChange={set("force_update")} />
              Majburiy yangilash (force update){form.status === "blocked" && " — Blocked uchun doim yoqiq"}
            </label>
            <div>
              <label className="label">Store URL ({form.platform === "ios" ? "App Store" : "Google Play"})</label>
              <input className="input" type="url" placeholder={form.platform === "ios" ? "https://apps.apple.com/app/id…" : "https://play.google.com/store/apps/details?id=…"}
                value={form.store_url} onChange={set("store_url")} />
            </div>
            <div>
              <label className="label">Yangilash xabari</label>
              <textarea className="input" rows={3} value={form.update_message} onChange={set("update_message")} />
            </div>
            {error && <div className="error">{error}</div>}
            <div className="flex gap-2">
              <button className="btn" type="submit" disabled={saving}>{saving ? "Saqlanmoqda…" : "Saqlash"}</button>
              <button className="btn-ghost" type="button" onClick={() => setForm(null)}>Bekor</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
