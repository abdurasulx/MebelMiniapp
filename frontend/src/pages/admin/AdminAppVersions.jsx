import { useEffect, useState } from "react";
import { Check, Pencil, Plus, Smartphone, X } from "lucide-react";
import { api } from "../../api";
import PlatformIcon, { PLATFORMS, PLATFORM_KEYS } from "../../components/PlatformIcon";

const STATUS = {
  active: { label: "Active", color: "var(--success)" },
  update_required: { label: "Update Required", color: "#f39c12" },
  blocked: { label: "Blocked", color: "var(--danger)" },
};


const EMPTY = {
  id: null, version: "", platforms: [], status: "active", force_update: false, orders_enabled: true,
  update_message: "", release_date: "",
};

const toLocalInput = (iso) => {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

/// Platforma tugmasi: logotip + nom. Tanlangan (active) — rangli ramka, tick
/// va to'liq yorug'lik; tanlanmagan (inactive) — xira va kulrang.
function PlatformToggle({ platform, active, onClick, caption, disabled }) {
  const p = PLATFORMS[platform];
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={active}
      className="relative flex min-w-[8.5rem] flex-1 items-center gap-3 rounded-2xl p-3 text-left transition"
      style={{
        border: `2px solid ${active ? "var(--brand-cta-bg)" : "var(--border)"}`,
        background: active ? "color-mix(in srgb, var(--brand-cta-bg) 8%, var(--card))" : "var(--card)",
        opacity: active ? 1 : 0.6,
        filter: active ? "none" : "grayscale(1)",
        cursor: disabled ? "default" : "pointer",
      }}
    >
      <span
        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl"
        style={{ background: "color-mix(in srgb, var(--text) 6%, transparent)" }}
      >
        <PlatformIcon platform={platform} size={22} />
      </span>
      <span className="min-w-0">
        <span className="block text-sm font-semibold">{p.label}</span>
        {caption && <span className="block truncate text-xs" style={{ color: "var(--muted)" }}>{caption}</span>}
      </span>
      {active && (
        <span
          className="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full"
          style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
        >
          <Check size={12} strokeWidth={3} />
        </span>
      )}
    </button>
  );
}

function StatusButtons({ value, onChange, allowAll }) {
  const items = allowAll ? [["", { label: "Barchasi", color: "var(--muted)" }], ...Object.entries(STATUS)] : Object.entries(STATUS);
  return (
    <div className="flex flex-wrap gap-2">
      {items.map(([k, v]) => {
        const on = value === k;
        return (
          <button
            key={k || "all"}
            type="button"
            onClick={() => onChange(k)}
            aria-pressed={on}
            className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={
              on
                ? { background: `color-mix(in srgb, ${v.color} 16%, transparent)`, color: v.color, border: `1.5px solid ${v.color}` }
                : { border: "1.5px solid var(--border)", color: "var(--muted)", background: "var(--card)" }
            }
          >
            <span className="inline-block h-2 w-2 rounded-full" style={{ background: v.color }} />
            {v.label}
          </button>
        );
      })}
    </div>
  );
}

/// SuperAdmin → Versiya nazorati. Eski versiyalar o'chirilmaydi (tarix) —
/// backend DELETE'ga 405 qaytaradi.
export default function AdminAppVersions() {
  const [rows, setRows] = useState([]);
  const [latest, setLatest] = useState({});
  const [error, setError] = useState("");
  const [platformFilter, setPlatformFilter] = useState([]); // bo'sh = hammasi
  const [statusFilter, setStatusFilter] = useState("");
  const [versionFilter, setVersionFilter] = useState("");
  const [form, setForm] = useState(null);
  const [saving, setSaving] = useState(false);

  const [links, setLinks] = useState({ android: "", ios: "", web: "" });
  const [linkMsg, setLinkMsg] = useState("");

  useEffect(() => {
    api("/admin/app-versions/links/").then(setLinks).catch(() => {});
  }, []);

  const saveLinks = async () => {
    setLinkMsg("");
    try {
      setLinks(await api("/admin/app-versions/links/", { method: "PUT", body: links }));
      setLinkMsg("Saqlandi");
    } catch (err) {
      setLinkMsg(err.message);
    }
  };

  const load = () =>
    api("/admin/app-versions/")
      .then((d) => {
        setRows(d.results || []);
        setLatest(d.latest || {});
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const shown = rows.filter(
    (r) =>
      (platformFilter.length === 0 || platformFilter.includes(r.platform)) &&
      (!statusFilter || r.status === statusFilter) &&
      (!versionFilter || r.version.includes(versionFilter.trim())),
  );

  // Bir xil versiya/holat/sozlamali qatorlar (masalan 1.0.0 — web, iOS, Android)
  // bitta guruhga birlashtiriladi; tahrirlash esa baribir platforma bo'yicha.
  const groups = [];
  const byKey = new Map();
  shown.forEach((r) => {
    const key = [r.version, r.status, r.force_update, r.orders_enabled !== false, r.release_date, r.update_message].join("|");
    let g = byKey.get(key);
    if (!g) {
      g = { key, rows: [], first: r };
      byKey.set(key, g);
      groups.push(g);
    }
    g.rows.push(r);
  });

  const countFor = (platform, status) => rows.filter((r) => r.platform === platform && r.status === status).length;

  const togglePlatformFilter = (p) =>
    setPlatformFilter((cur) => (cur.includes(p) ? cur.filter((x) => x !== p) : [...cur, p]));

  const openCreate = () => { setError(""); setForm({ ...EMPTY }); };
  // `group` — bir xil versiya/sozlamali qatorlar; bitta tahrirlash hammasiga tegadi.
  const openEdit = (group) => {
    const r = group[0];
    setError("");
    setForm({
      ...EMPTY, id: r.id, version: r.version, platform: r.platform, platforms: group.map((x) => x.platform),
      groupIds: Object.fromEntries(group.map((x) => [x.platform, x.id])), status: r.status,
      force_update: r.force_update, orders_enabled: r.orders_enabled !== false,
      update_message: r.update_message, release_date: toLocalInput(r.release_date),
    });
  };

  const togglePlatform = (p) =>
    setForm((f) => ({
      ...f,
      platforms: f.platforms.includes(p) ? f.platforms.filter((x) => x !== p) : [...f.platforms, p],
    }));

  const save = async (e) => {
    e.preventDefault();
    setError("");
    if (form.platforms.length === 0) {
      setError("Kamida bitta platformani tanlang");
      return;
    }
    setSaving(true);
    const common = {
      version: form.version.trim(),
      status: form.status,
      force_update: form.status === "blocked" ? true : form.force_update,
      orders_enabled: form.orders_enabled,
      update_message: form.update_message,
      release_date: form.release_date ? new Date(form.release_date).toISOString() : null,
    };
    try {
      if (form.id) {
        // Tanlangan har bir platforma uchun: bor bo'lsa yangilanadi, yo'q bo'lsa yaratiladi
        const errs = [];
        for (const platform of form.platforms) {
          const existing = form.groupIds?.[platform]
            ? { id: form.groupIds[platform] }
            : rows.find((r) => r.platform === platform && r.version === common.version);
          try {
            if (existing) {
              await api(`/admin/app-versions/${existing.id}/`, { method: "PATCH", body: common });
            } else {
              await api("/admin/app-versions/", { method: "POST", body: { ...common, platform } });
            }
          } catch (err) {
            errs.push(`${PLATFORMS[platform]?.label || platform}: ${err.message}`);
          }
        }
        if (errs.length) throw new Error(errs.join(" · "));
      } else {
        await api("/admin/app-versions/bulk/", {
          method: "POST",
          body: { ...common, platforms: form.platforms },
        });
      }
      setForm(null);
      await load();
    } catch (err) {
      const pe = err.body?.platform_errors;
      if (pe) {
        setError(
          Object.entries(pe)
            .map(([p, errs]) => `${PLATFORMS[p]?.label || p}: ${Object.values(errs).flat().join(", ")}`)
            .join(" · "),
        );
      } else {
        setError(err.message);
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="card p-5">
        <div className="mb-1 flex flex-wrap items-center justify-between gap-2">
          <h2 className="inline-flex items-center gap-2 text-base font-semibold">
            <Smartphone size={17} /> Versiya nazorati
          </h2>
          <button className="btn inline-flex items-center gap-1" onClick={openCreate}>
            <Plus size={15} /> Yangi versiya
          </button>
        </div>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          Platformani bosib ro'yxatni filtrlang. Eski versiyalar o'chirilmaydi — tarix saqlanadi. Ro'yxatda
          bo'lmagan versiya: eng yangisidan katta bo'lsa ruxsat, eng eski ruxsat etilganidan kichik bo'lsa
          Blocked, oralig'ida bo'lsa o'zidan pastroq eng yaqin yozuv holatini oladi.
        </p>
      </div>

      <div className="card flex flex-col gap-2 p-5">
        <h3 className="text-sm font-semibold">Yuklab olish havolalari (har platforma uchun bitta)</h3>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          Yangilash ekranida foydalanuvchi shu havola orqali ilovani yuklab oladi. Versiyalar uchun alohida URL kerak emas.
        </p>
        {PLATFORM_KEYS.map((p) => (
          <div key={p} className="flex items-center gap-2">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg" style={{ background: "color-mix(in srgb, var(--text) 6%, transparent)" }}>
              <PlatformIcon platform={p} size={18} />
            </span>
            <input
              className="input" type="url"
              placeholder={{ android: "https://play.google.com/store/apps/details?id=...", ios: "https://apps.apple.com/app/id...", web: "https://qrbite.uz" }[p]}
              value={links[p] || ""}
              onChange={(e) => setLinks({ ...links, [p]: e.target.value })}
            />
          </div>
        ))}
        <div className="flex items-center gap-3">
          <button className="btn" type="button" onClick={saveLinks}>Saqlash</button>
          {linkMsg && <span className="text-xs" style={{ color: "var(--muted)" }}>{linkMsg}</span>}
        </div>
      </div>

      <div className="flex flex-wrap gap-3">
        {PLATFORM_KEYS.map((p) => (
          <PlatformToggle
            key={p}
            platform={p}
            active={platformFilter.length === 0 || platformFilter.includes(p)}
            onClick={() => togglePlatformFilter(p)}
            caption={
              latest[p]
                ? `oxirgi ${latest[p]} · ${countFor(p, "blocked")} blocked · ${countFor(p, "update_required")} update`
                : "versiya yo'q"
            }
          />
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <StatusButtons allowAll value={statusFilter} onChange={setStatusFilter} />
        <input
          className="input !w-40"
          placeholder="Versiya (2.4)"
          value={versionFilter}
          onChange={(e) => setVersionFilter(e.target.value)}
        />
      </div>

      {error && !form && <div className="error">{error}</div>}

      <div className="card overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-xs" style={{ color: "var(--muted)" }}>
              <th className="p-3">Versiya</th><th className="p-3">Platforma</th><th className="p-3">Holat</th>
              <th className="p-3">Force update</th><th className="p-3">Release date</th>
              <th className="p-3">Updated</th><th className="p-3" />
            </tr>
          </thead>
          <tbody>
            {groups.length === 0 && (
              <tr><td colSpan={7} className="p-4" style={{ color: "var(--muted)" }}>Versiya topilmadi.</td></tr>
            )}
            {groups.map(({ key, rows: gRows, first: r }) => (
              <tr key={key} className="border-t" style={{ borderColor: "var(--border)" }}>
                <td className="p-3 font-semibold">{r.version}</td>
                <td className="p-3">
                  <span className="inline-flex flex-wrap items-center gap-x-4 gap-y-1">
                    {gRows.map((x) => (
                      <span key={x.id} className="inline-flex items-center gap-2">
                        <PlatformIcon platform={x.platform} size={18} /> {PLATFORMS[x.platform]?.label}
                      </span>
                    ))}
                  </span>
                </td>
                <td className="p-3">
                  <span
                    className="rounded-full px-2 py-0.5 text-[11px] font-medium"
                    style={{
                      background: `color-mix(in srgb, ${STATUS[r.status].color} 16%, transparent)`,
                      color: STATUS[r.status].color,
                    }}
                  >
                    {STATUS[r.status].label}
                    {r.orders_enabled === false && " · buyurtma yopiq"}
                  </span>
                </td>
                <td className="p-3">{r.force_update ? "Ha" : "Yo'q"}</td>
                <td className="p-3">{r.release_date ? new Date(r.release_date).toLocaleDateString("uz-UZ") : "—"}</td>
                <td className="p-3">
                  {new Date(Math.max(...gRows.map((x) => new Date(x.updated_at).getTime()))).toLocaleString("uz-UZ")}
                </td>
                <td className="p-3 text-right">
                  <button className="btn-ghost !px-2 !py-1.5" title="Tahrirlash" onClick={() => openEdit(gRows)}>
                    <Pencil size={14} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setForm(null)}>
          <form
            className="card flex max-h-[92vh] w-full max-w-xl flex-col gap-4 overflow-y-auto p-6"
            onClick={(e) => e.stopPropagation()}
            onSubmit={save}
          >
            <div className="flex items-center justify-between">
              <h3 className="text-base font-semibold">{form.id ? "Versiyani tahrirlash" : "Yangi versiya"}</h3>
              <button type="button" className="btn-ghost !p-1.5" onClick={() => setForm(null)} aria-label="Yopish">
                <X size={16} />
              </button>
            </div>

            <div>
              <label className="label">
                Platformalar (bir nechtasini tanlash mumkin)
              </label>
              <div className="flex flex-wrap gap-3">
                {PLATFORM_KEYS.map((p) => (
                  <PlatformToggle
                    key={p}
                    platform={p}
                    active={form.platforms.includes(p)}
                    onClick={() => togglePlatform(p)}
                  />
                ))}
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="label">Versiya *</label>
                <input
                  className="input" placeholder="2.4.0" required pattern="\d+\.\d+\.\d+"
                  title="major.minor.patch, masalan 2.4.0"
                  value={form.version} onChange={(e) => setForm({ ...form, version: e.target.value })}
                />
              </div>
              <div>
                <label className="label">Release date (ixtiyoriy)</label>
                <input
                  className="input" type="datetime-local"
                  value={form.release_date} onChange={(e) => setForm({ ...form, release_date: e.target.value })}
                />
              </div>
            </div>

            <div>
              <label className="label">Holat</label>
              <StatusButtons value={form.status} onChange={(s) => setForm({ ...form, status: s })} />
            </div>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={form.status === "blocked" ? true : form.force_update}
                disabled={form.status === "blocked"}
                onChange={(e) => setForm({ ...form, force_update: e.target.checked })}
              />
              Majburiy yangilash (force update){form.status === "blocked" && " — Blocked uchun doim yoqiq"}
            </label>

            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={!form.orders_enabled}
                onChange={(e) => setForm({ ...form, orders_enabled: !e.target.checked })}
              />
              Buyurtma berishni cheklash (bu versiyada buyurtma yaratib bo'lmaydi)
            </label>

            <div>
              <label className="label">Yangilash xabari</label>
              <textarea
                className="input" rows={3}
                value={form.update_message} onChange={(e) => setForm({ ...form, update_message: e.target.value })}
              />
            </div>

            {error && <div className="error">{error}</div>}
            <div className="flex gap-2">
              <button className="btn" type="submit" disabled={saving}>
                {saving ? "Saqlanmoqda…" : `${form.id ? "Saqlash" : "Yaratish"}${form.platforms.length > 1 ? ` (${form.platforms.length} platforma)` : ""}`}
              </button>
              <button className="btn-ghost" type="button" onClick={() => setForm(null)}>Bekor</button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
