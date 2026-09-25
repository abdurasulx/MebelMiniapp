// Bazis guruhlari backend'dan `stage` bilan keladi (qarang
// apps.custom_orders.services.bazis_groups_from_summary).
export const STAGES = [
  { key: "cutting", label: "Kesish" },
  { key: "edge_processing", label: "Kromkalash" },
  { key: "other", label: "Teshish" },
];

export const newId = () => Math.random().toString(36).slice(2);
export const emptyPerson = () => ({ mode: "role", employeeId: "", role: "" });

export function initialBazisState(preview) {
  const groupPay = {};
  for (const g of preview.groups || []) {
    const existing = Number(g.price_per_unit) || 0;
    groupPay[g.name] = { paid: existing > 0, price: existing > 0 ? String(existing) : "" };
  }
  const materialMap = {};
  for (const m of preview.materials || []) {
    if (m.suggested_material_id) materialMap[m.name] = m.suggested_material_id;
  }
  return {
    groupPay,
    stagePerson: { cutting: emptyPerson(), edge_processing: emptyPerson(), other: emptyPerson() },
    extraStages: [],
    materialMap,
  };
}

const personPayload = (p) => {
  if (p.mode === "employee" && p.employeeId) return { employee_id: p.employeeId };
  if (p.mode === "role" && p.role) return { role: p.role };
  return null;
};

// Backend'ga yuboriladigan maydonlar (FormData'ga JSON matn sifatida qo'shiladi).
export function buildBazisPayload(state, groups) {
  const prices = {};
  for (const [name, g] of Object.entries(state.groupPay)) {
    if (g.paid && g.price) prices[name] = g.price;
  }
  const assignments = {};
  for (const { key } of STAGES) {
    if (!groups.some((g) => g.stage === key)) continue;
    const person = personPayload(state.stagePerson[key]);
    if (person) assignments[key] = person;
  }
  const extraStages = state.extraStages
    .filter((s) => s.name.trim())
    .map((s) => ({
      name: s.name.trim(),
      ...(personPayload(s) || {}),
      jobs: s.jobs
        .filter((j) => j.name.trim())
        .map((j) => ({ name: j.name.trim(), quantity: j.quantity || "1", price: j.price || "0" })),
    }));
  const materialMap = {};
  for (const [name, id] of Object.entries(state.materialMap)) {
    if (id) materialMap[name] = id;
  }
  return { prices, assignments, extraStages, materialMap };
}

