import { useEffect, useState } from "react";
import { Building2, MapPin, AtSign, Send, Link as LinkIcon, Globe, Hammer, Trash2 } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";
import { TASK_STAGE } from "../../taskStage";

const VILOYATLAR = [
  ["toshkent_shahri", "Toshkent shahri"],
  ["toshkent_viloyati", "Toshkent viloyati"],
  ["andijon", "Andijon"],
  ["buxoro", "Buxoro"],
  ["fargona", "Farg'ona"],
  ["jizzax", "Jizzax"],
  ["xorazm", "Xorazm"],
  ["namangan", "Namangan"],
  ["navoiy", "Navoiy"],
  ["qashqadaryo", "Qashqadaryo"],
  ["qoraqalpogiston", "Qoraqalpog'iston Respublikasi"],
  ["samarqand", "Samarqand"],
  ["sirdaryo", "Sirdaryo"],
  ["surxondaryo", "Surxondaryo"],
];

export default function FirmaSettings() {
  const { user } = useAuth();
  const [company, setCompany] = useState(null);
  const [loaded, setLoaded] = useState(false);
  const [form, setForm] = useState({
    name: "", phone: "", address: "", viloyat: "", description: "", employment_contract_template: "",
    latitude: "", longitude: "", service_radius_km: "",
    instagram_url: "", telegram_url: "", facebook_url: "", website_url: "",
  });
  const [logo, setLogo] = useState(null);
  const [error, setError] = useState("");
  const [msg, setMsg] = useState("");
  const [locating, setLocating] = useState(false);

  const load = () =>
    api("/users/me/")
      .then((me) =>
        me.company ? api(`/companies/${me.company.slug}/`) : null
      )
      .then((c) => {
        if (c) {
          setCompany(c);
          setForm({
            name: c.name || "",
            phone: c.phone || "",
            address: c.address || "",
            viloyat: c.viloyat || "",
            description: c.description || "",
            employment_contract_template: c.employment_contract_template || "",
            latitude: c.latitude ?? "",
            longitude: c.longitude ?? "",
            service_radius_km: c.service_radius_km ?? "",
            instagram_url: c.instagram_url || "",
            telegram_url: c.telegram_url || "",
            facebook_url: c.facebook_url || "",
            website_url: c.website_url || "",
          });
        }
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));

  useEffect(() => {
    load();
  }, []);

  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });
  const isOwner = user?.role === "company_owner";

  const detectLocation = () => {
    if (!navigator.geolocation) {
      setError("Brauzeringiz joylashuvni aniqlashni qo'llab-quvvatlamaydi");
      return;
    }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setForm((f) => ({
          ...f,
          latitude: pos.coords.latitude.toFixed(6),
          longitude: pos.coords.longitude.toFixed(6),
        }));
        setLocating(false);
      },
      (err) => {
        // code 1 = PERMISSION_DENIED (foydalanuvchi rad etgan yoki sahifa
        // iframe/ruxsat siyosati tufayli bloklangan).
        setError(
          err.code === 1
            ? "Brauzer joylashuvga ruxsat bermadi. Manzil satridagi qulf belgisi orqali \"Joylashuv\"ni yoqing " +
              "(va sahifa boshqa ilova ichida emas, to'g'ridan-to'g'ri brauzerda ochilganini tekshiring) " +
              "yoki koordinatalarni qo'lda kiriting."
            : "Joylashuvni aniqlab bo'lmadi: " + err.message
        );
        setLocating(false);
      },
    );
  };

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => {
        // Bo'sh raqamli maydonlarni yubormaymiz — aks holda backend "valid
        // number kerak" deb rad etadi (lat/lng/radius ixtiyoriy).
        if (["latitude", "longitude", "service_radius_km"].includes(k) && v === "") return;
        fd.append(k, v);
      });
      if (logo) fd.append("logo", logo);
      if (company) {
        await api(`/companies/${company.slug}/`, { method: "PATCH", body: fd, isForm: true });
        setMsg("Saqlandi");
        setLogo(null);
        load();
      } else {
        await api("/companies/", { method: "POST", body: fd, isForm: true });
        setMsg("Kompaniya yaratildi");
        window.location.reload();
      }
      setTimeout(() => setMsg(""), 3000);
    } catch (err) {
      setError(err.message);
    }
  };

  if (!loaded) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="mx-auto flex w-full max-w-xl flex-col gap-4">
      <form className="card flex flex-col gap-4 p-6" onSubmit={submit}>
        <h2 className="inline-flex items-center gap-2 text-base font-semibold">
          <Building2 size={17} /> {company ? "Kompaniya ma'lumotlari" : "Kompaniyangizni yarating"}
        </h2>
        {!isOwner && (
          <div className="error">Faqat kompaniya egasi ma'lumotlarni o'zgartira oladi.</div>
        )}

        <div>
          <label className="label">Logotip</label>
          <div className="flex items-center gap-3">
            {(logo ? URL.createObjectURL(logo) : company?.logo_url) ? (
              <img
                src={logo ? URL.createObjectURL(logo) : company.logo_url}
                alt=""
                className="h-16 w-16 rounded-xl object-cover"
                style={{ border: "1px solid var(--border)" }}
              />
            ) : (
              <div
                className="flex h-16 w-16 items-center justify-center rounded-xl"
                style={{ background: "var(--bg)", border: "1px dashed var(--border)" }}
              >
                <Building2 size={20} style={{ color: "var(--muted)" }} />
              </div>
            )}
            {isOwner && (
              <input
                type="file"
                accept="image/*"
                className="input"
                onChange={(e) => setLogo(e.target.files[0])}
              />
            )}
          </div>
        </div>

        <div>
          <label className="label">Nomi *</label>
          <input className="input" value={form.name} onChange={set("name")} required disabled={!isOwner} />
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label className="label">Telefon</label>
            <input className="input" value={form.phone} onChange={set("phone")} placeholder="+998…" disabled={!isOwner} />
          </div>
          <div>
            <label className="label">Viloyat</label>
            <select className="input" value={form.viloyat} onChange={set("viloyat")} disabled={!isOwner}>
              <option value="">Tanlanmagan</option>
              {VILOYATLAR.map(([v, label]) => <option key={v} value={v}>{label}</option>)}
            </select>
          </div>
        </div>
        <div>
          <label className="label">Manzil</label>
          <input className="input" value={form.address} onChange={set("address")} disabled={!isOwner} />
        </div>

        <div>
          <label className="label inline-flex items-center gap-1.5">
            <MapPin size={13} /> Xizmat ko'rsatish hududi
          </label>
          <p className="mb-1.5 text-xs" style={{ color: "var(--muted)" }}>
            Firma joylashuvi va shu nuqtadan necha km radiusda mijozlarga xizmat qilishingiz —
            mahsulotlaringiz shu radius ichidagi foydalanuvchilarga ko'rinadi (viloyat chegarasidan
            qat'iy nazar). Bo'sh qoldirilsa, hamma joyda ko'rinadi.
          </p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
            <input
              className="input" type="number" step="0.000001" placeholder="Kenglik (lat)"
              value={form.latitude} onChange={set("latitude")} disabled={!isOwner}
            />
            <input
              className="input" type="number" step="0.000001" placeholder="Uzunlik (lng)"
              value={form.longitude} onChange={set("longitude")} disabled={!isOwner}
            />
            <input
              className="input" type="number" min="1" placeholder="Radius (km)"
              value={form.service_radius_km} onChange={set("service_radius_km")} disabled={!isOwner}
            />
          </div>
          {isOwner && (
            <button
              type="button"
              className="btn-ghost mt-2 inline-flex items-center gap-1.5 !px-3 !py-1.5 text-xs"
              onClick={detectLocation}
              disabled={locating}
            >
              <MapPin size={13} /> {locating ? "Aniqlanmoqda…" : "Joriy joylashuvni aniqlash"}
            </button>
          )}
        </div>

        <div>
          <label className="label">Tavsif</label>
          <textarea className="input" rows={3} value={form.description} onChange={set("description")} disabled={!isOwner} />
        </div>

        <div>
          <label className="label">Ijtimoiy sahifalar</label>
          <p className="mb-1.5 text-xs" style={{ color: "var(--muted)" }}>
            To'ldirilgan havolalar Do'kon sahifangizda bosiladigan ikonka sifatida ko'rinadi —
            mijozlar mobil ilovadan ham to'g'ridan-to'g'ri o'tib ko'ra oladi.
          </p>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <div className="relative">
              <AtSign size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
              <input
                className="input !pl-9" type="url" placeholder="https://instagram.com/…"
                value={form.instagram_url} onChange={set("instagram_url")} disabled={!isOwner}
              />
            </div>
            <div className="relative">
              <Send size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
              <input
                className="input !pl-9" type="url" placeholder="https://t.me/…"
                value={form.telegram_url} onChange={set("telegram_url")} disabled={!isOwner}
              />
            </div>
            <div className="relative">
              <LinkIcon size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
              <input
                className="input !pl-9" type="url" placeholder="https://facebook.com/…"
                value={form.facebook_url} onChange={set("facebook_url")} disabled={!isOwner}
              />
            </div>
            <div className="relative">
              <Globe size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2" style={{ color: "var(--muted)" }} />
              <input
                className="input !pl-9" type="url" placeholder="https://sizning-sayt.uz"
                value={form.website_url} onChange={set("website_url")} disabled={!isOwner}
              />
            </div>
          </div>
        </div>
        {company && (
          <div>
            <label className="label">Ishga olish shartnomasi matni</label>
            <p className="mb-1.5 text-xs" style={{ color: "var(--muted)" }}>
              Xodimni ishga taklif qilganingizda, u taklifni qabul qilishdan oldin o'z ilovasida
              aynan shu matnni ko'radi.
            </p>
            <textarea
              className="input"
              rows={8}
              value={form.employment_contract_template}
              onChange={set("employment_contract_template")}
              disabled={!isOwner}
              placeholder="Masalan: ish vaqti, maosh to'lash tartibi, sinov muddati va h.k."
            />
          </div>
        )}
        {error && <div className="error">{error}</div>}
        {msg && <span className="badge">{msg}</span>}
        {isOwner && (
          <button className="btn self-start" type="submit">
            {company ? "Saqlash" : "Yaratish"}
          </button>
        )}
      </form>
      {company && isOwner && <WorkTypesCard />}
      {company && isOwner && <TariffCard company={company} onChanged={load} />}
    </div>
  );
}

/// Firma egasi platforma tarif rejalaridan birini o'zi tanlaydi — hozircha
/// to'lov shlyuzi ulanmagan, faqat oylik summa hisoblab ko'rsatiladi (faol
/// xodimlar soni x xodim narxi + 3D modeli bor mahsulotlar soni x mahsulot
/// narxi). Qarang backend Company.billing_summary.
const EMPTY_WORK_TYPE = { stage: "", name: "", unit: "dona", price_per_unit: "", required_role: "" };
const UNIT_LABELS = { dona: "Dona", kg: "Kilogramm", m: "Metr", m2: "Kvadrat metr", m3: "Kub metr", litr: "Litr" };

/// Firma miqyosida markazlashgan "ish turlari" katalogi — bir marta narx
/// (birlik boshiga) belgilanadi, keyin mahsulot ish bosqichi yaratilganda
/// (FirmaProductDetail.jsx ProductionTab) shu ro'yxatdan tanlanadi va
/// xarajat avtomatik hisoblanadi (miqdor x narx).
function WorkTypesCard() {
  const [workTypes, setWorkTypes] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState(EMPTY_WORK_TYPE);
  const [saving, setSaving] = useState(false);

  const load = () =>
    api("/work-types/")
      .then((d) => setWorkTypes(d.results || []))
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const create = async (e) => {
    e.preventDefault();
    setError("");
    setSaving(true);
    try {
      await api("/work-types/", { method: "POST", body: form });
      setForm(EMPTY_WORK_TYPE);
      setShowForm(false);
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (wt) => {
    if (!confirm(`"${wt.name}" ish turi o'chirilsinmi?`)) return;
    try {
      await api(`/work-types/${wt.id}/`, { method: "DELETE" });
      await load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="card flex flex-col gap-4 p-6">
      <div className="flex items-center justify-between">
        <h2 className="inline-flex items-center gap-2 text-base font-semibold">
          <Hammer size={17} /> Ish turlari
        </h2>
        <button type="button" className="btn" onClick={() => setShowForm((v) => !v)}>
          {showForm ? "Bekor qilish" : "+ Yangi"}
        </button>
      </div>
      <p className="text-sm" style={{ color: "var(--muted)" }}>
        Har bir ish turi uchun bir marta narx (birlik boshiga) va lavozim belgilanadi — mahsulot ish
        bosqichi yaratilganda shu ro'yxatdan tanlanadi, xarajat qayta qo'lda kiritilmaydi.
      </p>
      {error && <div className="error">{error}</div>}
      {showForm && (
        <form onSubmit={create} className="flex flex-col gap-3 rounded-xl p-4" style={{ border: "1px solid var(--border)" }}>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label">Bosqich</label>
              <select className="input" value={form.stage} onChange={(e) => setForm({ ...form, stage: e.target.value })}>
                <option value="">—</option>
                {Object.entries(TASK_STAGE).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Nomi</label>
              <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
            </div>
            <div>
              <label className="label">Birlik</label>
              <select className="input" value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })}>
                {Object.entries(UNIT_LABELS).map(([k, label]) => <option key={k} value={k}>{label}</option>)}
              </select>
            </div>
            <div>
              <label className="label">Narx (birlik boshiga, so'm)</label>
              <input className="input" type="number" min="0" step="0.01" value={form.price_per_unit}
                onChange={(e) => setForm({ ...form, price_per_unit: e.target.value })} required />
            </div>
            <div className="col-span-2">
              <label className="label">Kerakli lavozim</label>
              <select className="input" value={form.required_role} onChange={(e) => setForm({ ...form, required_role: e.target.value })}>
                <option value="">—</option>
                {Object.entries(POSITIONS).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
              </select>
            </div>
          </div>
          <button className="btn self-start" type="submit" disabled={saving}>{saving ? "Saqlanmoqda…" : "Yaratish"}</button>
        </form>
      )}
      <div className="flex flex-col gap-2">
        {workTypes.length === 0 && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali ish turi qo'shilmagan.</p>
        )}
        {workTypes.map((wt) => (
          <div key={wt.id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl p-3" style={{ border: "1px solid var(--border)" }}>
            <div>
              <div className="font-medium">
                {wt.name}
                {wt.stage_display && <span className="ml-2 text-xs" style={{ color: "var(--muted)" }}>({wt.stage_display})</span>}
              </div>
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                {wt.price_per_unit} so'm/{wt.unit_display}
                {wt.required_role_display && ` · ${wt.required_role_display}`}
              </div>
            </div>
            <button onClick={() => remove(wt)} className="btn-ghost !px-2 !py-2" style={{ color: "var(--danger)" }}>
              <Trash2 size={16} />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

function TariffCard({ company, onChanged }) {
  const [plans, setPlans] = useState([]);
  const [error, setError] = useState("");
  const [savingId, setSavingId] = useState(null);

  useEffect(() => {
    api("/tariff-plans/")
      .then((d) => setPlans(d.results || []))
      .catch((e) => setError(e.message));
  }, []);

  const select = async (plan) => {
    setError("");
    setSavingId(plan.id);
    try {
      await api(`/companies/${company.slug}/`, { method: "PATCH", body: { tariff_plan: plan.id } });
      onChanged();
    } catch (err) {
      setError(err.message);
    } finally {
      setSavingId(null);
    }
  };

  const summary = company.billing_summary;

  return (
    <div className="card flex flex-col gap-4 p-6">
      <h2 className="inline-flex items-center gap-2 text-base font-semibold">
        <Building2 size={17} /> Tarif
      </h2>
      <p className="text-sm" style={{ color: "var(--muted)" }}>
        Oylik to'lov ikki qismdan iborat: faol xodimlar soni va 3D modeli bor mahsulotlar soni (variantlar
        hisobga olinmaydi — bitta mahsulotning bir nechta varianti bo'lsa ham bitta narx to'lanadi).
        Hozircha to'lov qo'lda amalga oshiriladi, keyinroq to'lov tizimi ulanadi.
      </p>
      {error && <div className="error">{error}</div>}
      {summary && (
        <div className="rounded-xl p-4" style={{ border: "1px solid var(--border)", background: "var(--surface-2, transparent)" }}>
          <div className="text-sm" style={{ color: "var(--muted)" }}>
            Joriy oy: {summary.employee_count} ta xodim, {summary.product_count} ta 3D mahsulot
          </div>
          {summary.plan ? (
            <div className="mt-1 text-lg font-semibold">
              {summary.total} {summary.plan.currency}/oy <span className="text-sm font-normal" style={{ color: "var(--muted)" }}>({summary.plan.name})</span>
            </div>
          ) : (
            <div className="mt-1 text-sm" style={{ color: "var(--muted)" }}>Hali tarif tanlanmagan.</div>
          )}
        </div>
      )}
      <div className="flex flex-col gap-2">
        {plans.length === 0 && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hozircha mavjud tarif rejasi yo'q.</p>
        )}
        {plans.map((p) => {
          const active = company.tariff_plan === p.id;
          return (
            <div
              key={p.id}
              className="flex flex-wrap items-center justify-between gap-3 rounded-xl p-4"
              style={{ border: active ? "2px solid var(--brand)" : "1px solid var(--border)" }}
            >
              <div>
                <div className="font-medium">{p.name}</div>
                {p.description && <div className="text-xs" style={{ color: "var(--muted)" }}>{p.description}</div>}
                <div className="text-xs" style={{ color: "var(--muted)" }}>
                  {p.price_per_employee} {p.currency}/xodim · {p.price_per_product} {p.currency}/3D mahsulot
                </div>
              </div>
              {active ? (
                <span className="rounded-full px-3 py-1 text-xs font-medium" style={{ background: "var(--brand)", color: "var(--brand-cta-text, #fff)" }}>
                  Tanlangan
                </span>
              ) : (
                <button className="btn" disabled={savingId === p.id} onClick={() => select(p)}>
                  {savingId === p.id ? "Saqlanmoqda…" : "Tanlash"}
                </button>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
