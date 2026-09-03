import { useEffect, useState } from "react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";

const PAY_TYPES = {
  fixed: "Faqat oylik",
  fixed_bonus: "Oylik + vazifa bonusi",
  commission: "Komissiya (% sotuvdan)",
  hourly: "Soatbay",
};

const EMPTY = {
  pay_type: "fixed_bonus",
  min_salary: "0",
  max_salary: "0",
  default_bonus_per_task: "0",
  default_commission_percent: "0",
  default_hourly_rate: "0",
  kpi_target_tasks_per_month: "",
  kpi_target_on_time_percent: "",
  kpi_bonus_multiplier: "1",
};

/// Lavozim bo'yicha ISHBU FIRMAGA tegishli ish haqi standarti — xodim
/// ishga taklif qilinganda shu standart boshlang'ich taklif sifatida
/// ko'rsatiladi (Employees.jsx), lekin har bir xodimning o'zi keyinchalik
/// individual sozlanadi (backend PositionPayStandard, company=shu firma).
/// Firma o'zi belgilamagan lavozim uchun platforma standarti (agar bor
/// bo'lsa) ishlatiladi — bu yerda faqat FIRMANING O'Z qiymatlari
/// tahrirlanadi, platforma standarti ko'rinmaydi/o'zgartirilmaydi (u faqat
/// platforma admini tomonidan boshqariladi).
export default function FirmaPayStandards() {
  const { user } = useAuth();
  const companyId = user?.company?.id;
  const [standards, setStandards] = useState({});
  const [drafts, setDrafts] = useState({});
  const [error, setError] = useState("");
  const [savingPosition, setSavingPosition] = useState(null);

  const load = () =>
    api("/pay-standards/")
      .then((d) => {
        const byPosition = {};
        (d.results || []).forEach((s) => {
          if (s.company === companyId) byPosition[s.position] = s;
        });
        setStandards(byPosition);
        const nextDrafts = {};
        Object.keys(POSITIONS).forEach((pos) => {
          const s = byPosition[pos];
          nextDrafts[pos] = s
            ? {
                pay_type: s.pay_type,
                min_salary: String(s.min_salary),
                max_salary: String(s.max_salary),
                default_bonus_per_task: String(s.default_bonus_per_task),
                default_commission_percent: String(s.default_commission_percent),
                default_hourly_rate: String(s.default_hourly_rate),
                kpi_target_tasks_per_month: s.kpi_target_tasks_per_month ?? "",
                kpi_target_on_time_percent: s.kpi_target_on_time_percent ?? "",
                kpi_bonus_multiplier: String(s.kpi_bonus_multiplier),
              }
            : { ...EMPTY };
        });
        setDrafts(nextDrafts);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const updateDraft = (position, field, value) =>
    setDrafts((prev) => ({ ...prev, [position]: { ...prev[position], [field]: value } }));

  const save = async (position) => {
    setError("");
    setSavingPosition(position);
    const d = drafts[position];
    const body = {
      company: companyId,
      position,
      pay_type: d.pay_type,
      min_salary: d.min_salary || 0,
      max_salary: d.max_salary || 0,
      default_bonus_per_task: d.default_bonus_per_task || 0,
      default_commission_percent: d.default_commission_percent || 0,
      default_hourly_rate: d.default_hourly_rate || 0,
      kpi_target_tasks_per_month: d.kpi_target_tasks_per_month === "" ? null : d.kpi_target_tasks_per_month,
      kpi_target_on_time_percent: d.kpi_target_on_time_percent === "" ? null : d.kpi_target_on_time_percent,
      kpi_bonus_multiplier: d.kpi_bonus_multiplier || 1,
    };
    try {
      const existing = standards[position];
      if (existing) {
        await api(`/pay-standards/${existing.id}/`, { method: "PATCH", body });
      } else {
        await api("/pay-standards/", { method: "POST", body });
      }
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setSavingPosition(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="card p-5">
        <h2 className="mb-1 text-base font-semibold">Lavozim bo'yicha ish haqi standartlari</h2>
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          Har bir lavozim uchun kompaniyangizning standart to'lov turi, tavsiya etilgan maosh oralig'i va
          KPI maqsadi. Xodim ishga taklif qilinganda shu standart boshlang'ich taklif sifatida
          ko'rsatiladi — har bir xodimning o'zi <strong>Xodimlar</strong> sahifasida individual
          sozlanadi, bu yerdagi qiymatlar faqat umumiy taklif/nazorat uchun.
        </p>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="flex flex-col gap-3">
        {Object.entries(POSITIONS).map(([pos, meta]) => {
          const d = drafts[pos] || EMPTY;
          const Icon = meta.icon;
          return (
            <div key={pos} className="card p-5">
              <div className="mb-3 flex items-center gap-2">
                <Icon size={16} />
                <span className="font-semibold">{meta.label}</span>
                <span className="text-xs" style={{ color: "var(--muted)" }}>{meta.desc}</span>
              </div>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                <div>
                  <label className="label">To'lov turi</label>
                  <select
                    className="input"
                    value={d.pay_type}
                    onChange={(e) => updateDraft(pos, "pay_type", e.target.value)}
                  >
                    {Object.entries(PAY_TYPES).map(([k, label]) => (
                      <option key={k} value={k}>{label}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="label">Min oylik</label>
                  <input className="input" type="number" value={d.min_salary}
                    onChange={(e) => updateDraft(pos, "min_salary", e.target.value)} />
                </div>
                <div>
                  <label className="label">Maks oylik</label>
                  <input className="input" type="number" value={d.max_salary}
                    onChange={(e) => updateDraft(pos, "max_salary", e.target.value)} />
                </div>
                {d.pay_type === "fixed_bonus" && (
                  <div>
                    <label className="label">Vazifa bonusi</label>
                    <input className="input" type="number" value={d.default_bonus_per_task}
                      onChange={(e) => updateDraft(pos, "default_bonus_per_task", e.target.value)} />
                  </div>
                )}
                {d.pay_type === "commission" && (
                  <div>
                    <label className="label">Komissiya %</label>
                    <input className="input" type="number" value={d.default_commission_percent}
                      onChange={(e) => updateDraft(pos, "default_commission_percent", e.target.value)} />
                  </div>
                )}
                {d.pay_type === "hourly" && (
                  <div>
                    <label className="label">Soatbay narx</label>
                    <input className="input" type="number" value={d.default_hourly_rate}
                      onChange={(e) => updateDraft(pos, "default_hourly_rate", e.target.value)} />
                  </div>
                )}
                <div>
                  <label className="label">KPI: oyiga N vazifa</label>
                  <input className="input" type="number" placeholder="—" value={d.kpi_target_tasks_per_month}
                    onChange={(e) => updateDraft(pos, "kpi_target_tasks_per_month", e.target.value)} />
                </div>
                <div>
                  <label className="label">KPI: o'z vaqtida %</label>
                  <input className="input" type="number" placeholder="—" value={d.kpi_target_on_time_percent}
                    onChange={(e) => updateDraft(pos, "kpi_target_on_time_percent", e.target.value)} />
                </div>
                <div>
                  <label className="label">Bonus multiplikator</label>
                  <input className="input" type="number" step="0.1" value={d.kpi_bonus_multiplier}
                    onChange={(e) => updateDraft(pos, "kpi_bonus_multiplier", e.target.value)} />
                </div>
                <div className="flex items-end">
                  <button
                    className="btn w-full"
                    disabled={savingPosition === pos}
                    onClick={() => save(pos)}
                  >
                    {savingPosition === pos ? "Saqlanmoqda…" : standards[pos] ? "Yangilash" : "Yaratish"}
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
