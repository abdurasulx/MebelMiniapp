import { useEffect, useState } from "react";
import { Building2, MapPin } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";

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
        setError("Joylashuvni aniqlab bo'lmadi: " + err.message);
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
    </div>
  );
}
