import { useEffect, useState } from "react";
import { Play, Check, Clock, Workflow, ClipboardList, Gauge, ChevronDown, ChevronRight, User } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";
import { TASK_FLOW, TASK_STAGE, TASK_STATUS } from "../../taskStage";
import { StatusBadge } from "../../orderStatus";
import LoadMoreButton from "../../components/LoadMoreButton";
import DateRangeInput from "../../components/DateRangeInput";

const TABS = [
  { key: "pipeline", label: "Ishlab chiqarish pipeline", icon: Workflow },
  { key: "tasks", label: "Qo'shimcha vazifalar", icon: ClipboardList },
  { key: "capacity", label: "Xodimlar bandligi", icon: Gauge },
];

const TAB_HINTS = {
  pipeline: "Har buyurtma qabul qilinganda mahsulot retseptidan avtomatik yaratiladigan bosqichlar — barcha bosqich tugasa, buyurtma avtomatik \"Tayyor\" bo'ladi.",
  tasks: "Pipelinega kirmaydigan qo'shimcha ishlar uchun qo'lda yaratiladigan vazifalar (masalan yetkazib berish, maxsus topshiriq).",
  capacity: "Har xodimning hozirgi navbatida qancha soatlik ish borligi — yangi buyurtma/vazifa kimga tayinlashni rejalashtirish uchun.",
};

export default function FirmaProduction() {
  const { user } = useAuth();
  const isManager = user?.role === "company_owner";
  const [tab, setTab] = useState("pipeline");

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-2">
        {TABS.map((t) => (
          <button
            key={t.key}
            className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={
              tab === t.key
                ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                : { border: "1px solid var(--border)", color: "var(--muted)" }
            }
            onClick={() => setTab(t.key)}
          >
            <t.icon size={13} /> {t.label}
          </button>
        ))}
      </div>
      <p className="text-xs" style={{ color: "var(--muted)" }}>{TAB_HINTS[tab]}</p>
      {tab === "pipeline" && <WorkflowPipeline isManager={isManager} />}
      {tab === "tasks" && (isManager ? <ManagerView /> : <EmployeeView />)}
      {tab === "capacity" && <CapacityView />}
    </div>
  );
}

/* ================= Xodimlar bandligi (ishlab chiqarish rejalashtirish) ================= */

function CapacityView() {
  const [rows, setRows] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api("/workflow-capacity/")
      .then((d) => setRows(d || []))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p className="text-sm" style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;
  if (error) return <div className="error">{error}</div>;
  if (rows.length === 0) return <p className="text-sm" style={{ color: "var(--muted)" }}>Faol xodim yo'q.</p>;

  const maxHours = Math.max(1, ...rows.map((r) => r.pending_hours));

  return (
    <div className="flex flex-col gap-3">
      {rows.map((r) => (
        <div key={r.employee} className="card flex flex-col gap-2 p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="font-semibold">{r.employee_name}</span>
              <span className="ml-2 text-xs" style={{ color: "var(--muted)" }}>
                {r.positions.map((p) => POSITIONS[p]?.label || p).join(", ")}
              </span>
            </div>
            <span className="text-sm font-bold" style={{ color: r.pending_hours > 0 ? "var(--warning)" : "var(--success)" }}>
              {r.pending_hours} soat navbatda
              {r.in_progress_count > 0 && ` · ${r.in_progress_count} ta bajarilmoqda`}
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full" style={{ background: "var(--bg)" }}>
            <div
              className="h-full rounded-full"
              style={{
                width: `${Math.min(100, (r.pending_hours / maxHours) * 100)}%`,
                background: r.pending_hours > 0 ? "var(--warning)" : "var(--success)",
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

/* ================= Avtomatik ishlab chiqarish pipeline ================= */

function WorkflowPipeline({ isManager }) {
  const [instances, setInstances] = useState([]);
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [busyId, setBusyId] = useState(null);
  const [expanded, setExpanded] = useState(new Set());

  const toggleExpanded = (orderId) =>
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(orderId)) next.delete(orderId);
      else next.add(orderId);
      return next;
    });

  const load = () =>
    api("/workflow-instances/")
      .then((d) => {
        setInstances((d.results || []).filter((i) => !i.is_manual));
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setInstances((prev) => [...prev, ...(d.results || []).filter((i) => !i.is_manual)]);
      setNextPage(d.next || null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const complete = async (step) => {
    setBusyId(step.id);
    setError("");
    try {
      await api(`/workflow-instances/${step.id}/complete/`, { method: "POST", body: {} });
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const approve = async (step) => {
    setBusyId(step.id);
    setError("");
    try {
      await api(`/workflow-instances/${step.id}/approve/`, { method: "POST", body: {} });
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const groups = [];
  const groupByOrder = new Map();
  for (const step of instances) {
    let g = groupByOrder.get(step.order);
    if (!g) {
      g = { order: step.order, order_display: step.order_display, order_status: step.order_status, steps: [] };
      groupByOrder.set(step.order, g);
      groups.push(g);
    }
    g.steps.push(step);
  }
  for (const g of groups) g.steps.sort((a, b) => a.order_index - b.order_index);

  return (
    <div className="flex flex-col gap-4">
      {error && <div className="error">{error}</div>}
      <OpenPoolView isManager={isManager} />
      {groups.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          Hali hech qanday buyurtma uchun ishlab chiqarish bosqichi yo'q.
        </p>
      )}
      {groups.map((g) => {
        const isOpen = expanded.has(g.order);
        const doneCount = g.steps.filter((s) => s.status === "completed" || s.status === "approved").length;
        const employeeNames = [...new Set(g.steps.map((s) => s.employee_name).filter(Boolean))];
        return (
          <div key={g.order} className="card flex flex-col gap-3 p-4">
            <button
              className="flex w-full flex-wrap items-center justify-between gap-2 text-left"
              onClick={() => toggleExpanded(g.order)}
            >
              <span className="inline-flex items-center gap-2 font-semibold">
                {isOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                Buyurtma {g.order_display}
              </span>
              <span className="inline-flex flex-wrap items-center gap-2">
                <span className="text-xs" style={{ color: "var(--muted)" }}>
                  {doneCount}/{g.steps.length} bosqich bajarildi
                  {employeeNames.length > 0 && ` · ${employeeNames.join(", ")}`}
                </span>
                <StatusBadge status={g.order_status} />
              </span>
            </button>
            {isOpen && (
              <div className="flex flex-col gap-2">
                {g.steps.map((step) => (
                  <div
                    key={step.id}
                    className="flex flex-wrap items-center gap-3 rounded-xl p-3"
                    style={{ border: "1px solid var(--border)" }}
                  >
                    <span
                      className="rounded-full px-2 py-0.5 text-[10px] font-medium"
                      style={{
                        background: `color-mix(in srgb, ${TASK_STATUS[step.status]?.color || "#8a8f98"} 16%, transparent)`,
                        color: TASK_STATUS[step.status]?.color || "#8a8f98",
                      }}
                    >
                      {step.awaiting_approval ? "Admin tasdig'ini kutmoqda" : step.status_display}
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium">{step.name}</div>
                      {step.cutting_instruction && (
                        <div className="text-xs font-medium" style={{ color: "var(--brand)" }}>{step.cutting_instruction}</div>
                      )}
                      <div className="mt-0.5 inline-flex items-center gap-1 text-xs font-medium" style={{ color: step.employee_name ? "var(--text)" : "var(--muted)" }}>
                        <User size={11} /> {step.employee_name || "Hali usta biriktirilmagan"}
                      </div>
                      <div className="text-xs" style={{ color: "var(--muted)" }}>
                        {step.role_display}
                        {` · ${step.estimated_hours} soat`}
                        {step.deadline && (
                          <span
                            style={
                              step.status !== "completed" && new Date(step.deadline) < new Date()
                                ? { color: "var(--danger)", fontWeight: 600 }
                                : undefined
                            }
                          >
                            {` · muddat: ${step.deadline}`}
                          </span>
                        )}
                      </div>
                    </div>
                    {step.status === "in_progress" && (
                      step.photo_requirement === "required" ? (
                        <span className="text-xs" style={{ color: "var(--muted)" }}>
                          Yakunlash uchun rasm talab qilinadi (mobil ilovadan yuklang)
                        </span>
                      ) : step.comment_requirement === "required" ? (
                        <span className="text-xs" style={{ color: "var(--muted)" }}>
                          Yakunlash uchun izoh talab qilinadi (mobil ilovadan yozing)
                        </span>
                      ) : (
                        <button
                          className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                          disabled={busyId === step.id}
                          onClick={() => complete(step)}
                        >
                          <Check size={12} /> Bajarildi
                        </button>
                      )
                    )}
                    {step.awaiting_approval && isManager && (
                      <button
                        className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                        style={{ background: TASK_STATUS.approved.color, color: "#fff" }}
                        disabled={busyId === step.id}
                        onClick={() => approve(step)}
                      >
                        <Check size={12} /> Tasdiqlash
                      </button>
                    )}
                    {step.status === "pending" && (
                      isManager && step.is_available && !step.employee_name && step.open_applications_count > 0 ? (
                        <ApplicantsControl step={step} onApproved={load} />
                      ) : (
                        <span className="text-xs" style={{ color: "var(--muted)" }}>
                          {step.is_available && !step.employee_name ? "Navbatda (hali zayavka yo'q)" : "Navbatda"}
                        </span>
                      )
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

/* ================= Firma egasi/menejer uchun: bosqichga kelgan zayavkalar =================
   Har bir zayavkani ko'rsatadi, "Tasdiqlash" bosilsa shu usta biriktiriladi
   va qolgan barcha kutilayotgan zayavkalar avtomatik rad etiladi (backend). */
function ApplicantsControl({ step, onApproved }) {
  const [open, setOpen] = useState(false);
  const [applicants, setApplicants] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [error, setError] = useState("");

  const toggle = async () => {
    if (open) {
      setOpen(false);
      return;
    }
    setOpen(true);
    if (applicants === null) {
      try {
        const d = await api(`/workflow-instances/${step.id}/applications/`);
        setApplicants(d);
      } catch (e) {
        setError(e.message);
      }
    }
  };

  const approve = async (applicationId) => {
    setBusyId(applicationId);
    setError("");
    try {
      await api(`/workflow-instances/${step.id}/approve-application/`, {
        method: "POST",
        body: { application_id: applicationId },
      });
      onApproved();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        className="rounded-full px-2.5 py-1 text-[11px] font-medium"
        style={{ background: "color-mix(in srgb, var(--brand) 16%, transparent)", color: "var(--brand)" }}
        onClick={toggle}
      >
        {step.open_applications_count} ta zayavka
      </button>
      {error && <div className="error text-[11px]">{error}</div>}
      {open && (
        <div className="flex flex-col gap-1.5 rounded-lg p-2" style={{ border: "1px solid var(--border)" }}>
          {applicants === null && <span className="text-[11px]" style={{ color: "var(--muted)" }}>Yuklanmoqda…</span>}
          {applicants?.map((a) => (
            <div key={a.id} className="flex items-center gap-2 text-[11px]">
              <span>{a.employee_name || "Nomsiz usta"}</span>
              <button
                className="btn !px-2 !py-0.5 text-[11px]"
                disabled={busyId === a.id}
                onClick={() => approve(a.id)}
              >
                Tasdiqlash
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ================= Usta uchun: "erkin" (xodimi hali yo'q) bosqichlar hovuzi =================
   Bosqich boshlanishga tayyor (oldingi bosqichlar tugagan) va ustaning
   lavozimiga mos bo'lsa shu yerda ko'rinadi — "Zayavka yuborish" bosilgach
   firma egasi tasdiqlashini kutadi (bir vaqtda bir nechta usta yuborishi
   mumkin, faqat bittasi tasdiqlanadi). */
function OpenPoolView({ isManager }) {
  const [steps, setSteps] = useState([]);
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [loading, setLoading] = useState(true);

  const load = () =>
    api("/workflow-instances/open/")
      .then((d) => setSteps(d.results || []))
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));

  useEffect(() => {
    load();
  }, []);

  const apply = async (step) => {
    setBusyId(step.id);
    setError("");
    try {
      await api(`/workflow-instances/${step.id}/apply/`, { method: "POST", body: {} });
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  const cancelStep = async (step) => {
    if (!confirm(`"${step.name}" bosqichi bekor qilinsinmi?`)) return;
    setBusyId(step.id);
    setError("");
    try {
      await api(`/workflow-instances/${step.id}/cancel/`, { method: "POST", body: {} });
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusyId(null);
    }
  };

  if (loading) return null;
  if (steps.length === 0) return null;

  return (
    <div className="card flex flex-col gap-3 p-4" style={{ borderColor: "var(--brand)" }}>
      <div className="font-semibold text-sm">Erkin topshiriqlar ({steps.length})</div>
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        {isManager
          ? "Bu bosqichlarga hali usta biriktirilmagan — kerak bo'lsa bekor qiling."
          : "Bu bosqichlarga hali usta biriktirilmagan — zayavka yuboring, firma egasi tasdiqlasa sizga o'tadi."}
      </p>
      {error && <div className="error">{error}</div>}
      <div className="flex flex-col gap-2">
        {steps.map((step) => (
          <div
            key={step.id}
            className="flex flex-wrap items-center gap-3 rounded-xl p-3"
            style={{ border: "1px solid var(--border)" }}
          >
            <div className="min-w-0 flex-1">
              <div className="font-medium">{step.name}</div>
              {step.cutting_instruction && (
                <div className="text-xs font-medium" style={{ color: "var(--brand)" }}>{step.cutting_instruction}</div>
              )}
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                {step.order_display && `Buyurtma ${step.order_display} · `}
                {step.role_display} · {step.estimated_hours} soat
              </div>
            </div>
            {isManager ? (
              <button
                className="btn-danger !px-2.5 !py-1 text-xs"
                disabled={busyId === step.id}
                onClick={() => cancelStep(step)}
              >
                Bekor qilish
              </button>
            ) : step.my_application_status === "pending" ? (
              <span className="rounded-full px-2.5 py-1 text-[11px] font-medium" style={{ background: "color-mix(in srgb, var(--muted) 16%, transparent)" }}>
                Kutilmoqda (tasdiqlanishi kutilmoqda)
              </span>
            ) : (
              <button
                className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                disabled={busyId === step.id}
                onClick={() => apply(step)}
              >
                Zayavka yuborish
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

/* ================= Manager (ega) ko'rinishi — qo'lda vazifalar ================= */

function ManagerView() {
  const [tasks, setTasks] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [filter, setFilter] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    Promise.all([api("/workflow-instances/"), api("/employees/"), api("/orders/"), api("/products/")])
      .then(([t, e, o, p]) => {
        setTasks((t.results || []).filter((x) => x.is_manual));
        setNextPage(t.next || null);
        setEmployees((e.results || []).filter((x) => x.is_active));
        setOrders(o.results || []);
        setProducts(p.results || []);
      })
      .catch((err) => setError(err.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setTasks((prev) => [...prev, ...(d.results || []).filter((x) => x.is_manual)]);
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

  const shown = filter ? tasks.filter((t) => t.status === filter) : tasks;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex flex-wrap gap-2">
          <button
            className="rounded-full px-3 py-1.5 text-xs font-medium transition"
            style={
              filter === ""
                ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                : { border: "1px solid var(--border)", color: "var(--muted)" }
            }
            onClick={() => setFilter("")}
          >
            Barchasi ({tasks.length})
          </button>
          {TASK_FLOW.map((s) => {
            const n = tasks.filter((t) => t.status === s).length;
            return (
              <button
                key={s}
                className="rounded-full px-3 py-1.5 text-xs font-medium transition"
                style={
                  filter === s
                    ? { background: TASK_STATUS[s].color, color: "#fff" }
                    : { border: "1px solid var(--border)", color: "var(--muted)" }
                }
                onClick={() => setFilter(s)}
              >
                {TASK_STATUS[s].label} ({n})
              </button>
            );
          })}
        </div>
        <button className="btn" onClick={() => setShowForm(true)}>+ Yangi vazifa</button>
      </div>

      {error && <div className="error">{error}</div>}
      {shown.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Vazifalar yo'q.</p>
      )}

      <div className="flex flex-col gap-3">
        {shown.map((t) => (
          <TaskCard key={t.id} task={t} manager onChanged={load} />
        ))}
      </div>
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>

      {showForm && (
        <TaskForm
          employees={employees}
          orders={orders}
          products={products}
          onClose={() => setShowForm(false)}
          onDone={() => { setShowForm(false); load(); }}
        />
      )}
    </div>
  );
}

function TaskForm({ employees, orders, products, onClose, onDone }) {
  const [form, setForm] = useState({
    name: "", description: "", stage: "assembly", employee: "", order: "", product: "",
    planned_start_date: "", deadline: "", requires_approval: "",
  });
  const [error, setError] = useState("");
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value });

  const suggestedPos = TASK_STAGE_TO_POSITION[form.stage];
  const filteredEmployees = suggestedPos
    ? employees.filter((e) => (e.positions || []).includes(suggestedPos))
    : employees;

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    if (form.requires_approval === "") {
      setError("Tasdiqlash shart yoki shart emasligini tanlang");
      return;
    }
    try {
      const body = { ...form, requires_approval: form.requires_approval === "true" };
      if (!body.employee) delete body.employee;
      if (!body.order) delete body.order;
      if (!body.product) delete body.product;
      if (!body.planned_start_date) delete body.planned_start_date;
      if (!body.deadline) delete body.deadline;
      await api("/workflow-instances/", { method: "POST", body });
      onDone();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-md flex-col gap-4 p-6"
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h2 className="text-base font-semibold">Yangi vazifa</h2>
        <div>
          <label className="label">Sarlavha *</label>
          <input className="input" value={form.name} onChange={set("name")} required />
        </div>
        <div>
          <label className="label">Bosqich</label>
          <select className="input" value={form.stage} onChange={set("stage")}>
            {Object.entries(TASK_STAGE).map(([k, v]) => (
              <option key={k} value={k}>{v.label}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">
            Kimga tayinlansin?
            {suggestedPos && (
              <span className="ml-1" style={{ color: "var(--muted)" }}>
                (tavsiya: {POSITIONS[suggestedPos]?.label})
              </span>
            )}
          </label>
          <select className="input" value={form.employee} onChange={set("employee")}>
            <option value="">Tayinlanmagan</option>
            {filteredEmployees.map((e) => (
              <option key={e.id} value={e.id}>{e.user_name || e.user_email}</option>
            ))}
          </select>
          {suggestedPos && filteredEmployees.length === 0 && (
            <p className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
              Bu kasbdagi xodim yo'q — barcha xodimlar ko'rsatilyapti.
            </p>
          )}
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="label">Buyurtma (ixtiyoriy)</label>
            <select className="input" value={form.order} onChange={set("order")}>
              <option value="">—</option>
              {orders.map((o) => (
                <option key={o.id} value={o.id}>{o.customer_email} — #{o.id.slice(0, 8)}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Bog'liq mahsulot (ixtiyoriy)</label>
            <select className="input" value={form.product} onChange={set("product")}>
              <option value="">—</option>
              {products.map((p) => (
                <option key={p.id} value={p.id}>{p.name_uz}</option>
              ))}
            </select>
          </div>
        </div>
        <div>
          <label className="label">Boshlanish — tugash sanasi</label>
          <DateRangeInput
            start={form.planned_start_date}
            stop={form.deadline}
            onChange={({ start, stop }) =>
              setForm((f) => ({ ...f, planned_start_date: start, deadline: stop }))
            }
          />
        </div>
        <div>
          <label className="label">Tasdiqlash shartmi? *</label>
          <div className="flex gap-2">
            <button
              type="button"
              className={form.requires_approval === "true" ? "btn !px-3 !py-1.5 text-xs" : "btn-ghost !px-3 !py-1.5 text-xs"}
              onClick={() => setForm((f) => ({ ...f, requires_approval: "true" }))}
            >
              Tasdiqlash shart
            </button>
            <button
              type="button"
              className={form.requires_approval === "false" ? "btn !px-3 !py-1.5 text-xs" : "btn-ghost !px-3 !py-1.5 text-xs"}
              onClick={() => setForm((f) => ({ ...f, requires_approval: "false" }))}
            >
              Tasdiqlash shart emas
            </button>
          </div>
          <p className="mt-1 text-xs" style={{ color: "var(--muted)" }}>
            Shart bo'lsa — usta "Bajardim" bosgach, siz tasdiqlamaguncha ish haqi hisobiga qo'shilmaydi.
          </p>
        </div>
        <div>
          <label className="label">Izoh</label>
          <textarea className="input" rows={2} value={form.description} onChange={set("description")} />
        </div>
        {error && <div className="error">{error}</div>}
        <div className="flex gap-2">
          <button className="btn" type="submit">Saqlash</button>
          <button className="btn-ghost" type="button" onClick={onClose}>Bekor</button>
        </div>
      </form>
    </div>
  );
}

const TASK_STAGE_TO_POSITION = {
  cutting: "usta",
  edge_processing: "usta",
  assembly: "usta",
  painting: "usta",
  quality_control: "usta",
  installation: "ornatuvchi",
  delivery: "haydovchi",
  other: null,
};

/* ================= Xodim ko'rinishi ================= */

function EmployeeView() {
  const [tasks, setTasks] = useState([]);
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    api("/workflow-instances/")
      .then((d) => {
        setTasks((d.results || []).filter((x) => x.is_manual));
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setTasks((prev) => [...prev, ...(d.results || []).filter((x) => x.is_manual)]);
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

  const groups = TASK_FLOW.map((s) => ({ status: s, items: tasks.filter((t) => t.status === s) }));

  return (
    <div className="flex flex-col gap-6">
      <h2 className="text-base font-semibold">Mening vazifalarim</h2>
      {error && <div className="error">{error}</div>}
      {tasks.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Sizga hali vazifa tayinlanmagan.</p>
      )}
      {groups.map(
        (g) =>
          g.items.length > 0 && (
            <div key={g.status} className="flex flex-col gap-2">
              <div className="text-xs font-semibold uppercase" style={{ color: TASK_STATUS[g.status].color }}>
                {TASK_STATUS[g.status].label} ({g.items.length})
              </div>
              {g.items.map((t) => (
                <TaskCard key={t.id} task={t} onChanged={load} />
              ))}
            </div>
          )
      )}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

/* ================= Umumiy vazifa kartasi ================= */

function TaskCard({ task, manager, onChanged }) {
  const [error, setError] = useState("");
  const stage = TASK_STAGE[task.stage] || TASK_STAGE.other;
  const isOverdue = task.deadline && task.status !== "completed" && new Date(task.deadline) < new Date();

  const advance = async () => {
    const next = task.status === "pending" ? "in_progress" : "completed";
    try {
      await api(`/workflow-instances/${task.id}/`, { method: "PATCH", body: { status: next } });
      onChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const remove = async () => {
    if (!confirm(`"${task.name}" o'chirilsinmi?`)) return;
    try {
      await api(`/workflow-instances/${task.id}/`, { method: "DELETE" });
      onChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="card flex flex-wrap items-center gap-4 p-4">
      <span
        className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
        style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
      >
        <stage.icon size={20} />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-semibold">{task.name}</span>
          <span
            className="rounded-full px-2 py-0.5 text-[10px] font-medium"
            style={{ background: `color-mix(in srgb, ${TASK_STATUS[task.status].color} 16%, transparent)`, color: TASK_STATUS[task.status].color }}
          >
            {task.awaiting_approval ? "Admin tasdig'ini kutmoqda" : TASK_STATUS[task.status].label}
          </span>
          {isOverdue && (
            <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium" style={{ background: "color-mix(in srgb, var(--danger) 15%, transparent)", color: "var(--danger)" }}>
              <Clock size={11} /> Muddati o'tdi
            </span>
          )}
        </div>
        <div className="text-xs" style={{ color: "var(--muted)" }}>
          {stage.label}
          {task.order_display && ` · Buyurtma ${task.order_display}`}
          {manager && task.employee_name && ` · ${task.employee_name}`}
          {task.deadline && ` · muddat: ${task.deadline}`}
        </div>
        {task.description && <div className="mt-1 text-sm">{task.description}</div>}
        {error && <div className="error mt-1">{error}</div>}
      </div>
      <div className="flex gap-2">
        {task.status !== "completed" && (
          <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={advance}>
            {task.status === "pending" ? <><Play size={12} /> Boshlash</> : <><Check size={12} /> Bajarildi</>}
          </button>
        )}
        {manager && (
          <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={remove}>
            O'chirish
          </button>
        )}
      </div>
    </div>
  );
}
