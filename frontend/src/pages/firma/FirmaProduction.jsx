import { useEffect, useState } from "react";
import { Play, Check, Clock, Workflow, ClipboardList } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { POSITIONS } from "../../positions";
import { TASK_FLOW, TASK_STAGE, TASK_STATUS } from "../../taskStage";
import { StatusBadge } from "../../orderStatus";
import LoadMoreButton from "../../components/LoadMoreButton";

export default function FirmaProduction() {
  const { user } = useAuth();
  const isManager = user?.role === "company_owner";
  const [tab, setTab] = useState("pipeline");

  return (
    <div className="flex flex-col gap-4">
      <div className="flex gap-2">
        <button
          className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            tab === "pipeline"
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setTab("pipeline")}
        >
          <Workflow size={13} /> Ishlab chiqarish pipeline
        </button>
        <button
          className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            tab === "tasks"
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setTab("tasks")}
        >
          <ClipboardList size={13} /> Qo'shimcha vazifalar
        </button>
      </div>
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        {tab === "pipeline"
          ? "Har buyurtma qabul qilinganda mahsulot retseptidan avtomatik yaratiladigan bosqichlar — barcha bosqich tugasa, buyurtma avtomatik \"Tayyor\" bo'ladi."
          : "Pipelinega kirmaydigan qo'shimcha ishlar uchun qo'lda yaratiladigan vazifalar (masalan yetkazib berish, maxsus topshiriq)."}
      </p>
      {tab === "pipeline" ? <WorkflowPipeline /> : isManager ? <ManagerView /> : <EmployeeView />}
    </div>
  );
}

/* ================= Avtomatik ishlab chiqarish pipeline ================= */

function WorkflowPipeline() {
  const [instances, setInstances] = useState([]);
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [busyId, setBusyId] = useState(null);

  const load = () =>
    api("/workflow-instances/")
      .then((d) => {
        setInstances(d.results || []);
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setInstances((prev) => [...prev, ...(d.results || [])]);
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
      {groups.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>
          Hali hech qanday buyurtma uchun ishlab chiqarish bosqichi yo'q.
        </p>
      )}
      {groups.map((g) => (
        <div key={g.order} className="card flex flex-col gap-3 p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <span className="font-semibold">Buyurtma {g.order_display}</span>
            <StatusBadge status={g.order_status} />
          </div>
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
                  {step.status_display}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="font-medium">{step.name}</div>
                  <div className="text-xs" style={{ color: "var(--muted)" }}>
                    {step.role_display}
                    {step.employee_name && ` · ${step.employee_name}`}
                    {` · ${step.estimated_hours} soat`}
                  </div>
                </div>
                {step.status === "in_progress" && (
                  step.photo_requirement === "required" ? (
                    <span className="text-xs" style={{ color: "var(--muted)" }}>
                      Yakunlash uchun rasm talab qilinadi (mobil ilovadan yuklang)
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
                {step.status === "pending" && (
                  <span className="text-xs" style={{ color: "var(--muted)" }}>Navbatda</span>
                )}
              </div>
            ))}
          </div>
        </div>
      ))}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

/* ================= Manager (ega) ko'rinishi ================= */

function ManagerView() {
  const [tasks, setTasks] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [orders, setOrders] = useState([]);
  const [error, setError] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [filter, setFilter] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);

  const load = () =>
    Promise.all([api("/tasks/"), api("/employees/"), api("/orders/")])
      .then(([t, e, o]) => {
        setTasks(t.results || []);
        setNextPage(t.next || null);
        setEmployees((e.results || []).filter((x) => x.is_active));
        setOrders(o.results || []);
      })
      .catch((err) => setError(err.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setTasks((prev) => [...prev, ...(d.results || [])]);
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
          onClose={() => setShowForm(false)}
          onDone={() => { setShowForm(false); load(); }}
        />
      )}
    </div>
  );
}

function TaskForm({ employees, orders, onClose, onDone }) {
  const [form, setForm] = useState({
    title: "", description: "", stage: "assembly", assigned_to: "", order: "", deadline: "",
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
    try {
      const body = { ...form };
      if (!body.assigned_to) delete body.assigned_to;
      if (!body.order) delete body.order;
      if (!body.deadline) delete body.deadline;
      await api("/tasks/", { method: "POST", body });
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
          <input className="input" value={form.title} onChange={set("title")} required />
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
          <select className="input" value={form.assigned_to} onChange={set("assigned_to")}>
            <option value="">Tayinlanmagan</option>
            {filteredEmployees.map((e) => (
              <option key={e.id} value={e.user_id || ""}>{e.user_name || e.user_email}</option>
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
            <label className="label">Muddat</label>
            <input className="input" type="date" value={form.deadline} onChange={set("deadline")} />
          </div>
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
    api("/tasks/")
      .then((d) => {
        setTasks(d.results || []);
        setNextPage(d.next || null);
      })
      .catch((e) => setError(e.message));

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setTasks((prev) => [...prev, ...(d.results || [])]);
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
  const isOverdue = task.deadline && task.status !== "done" && new Date(task.deadline) < new Date();

  const advance = async () => {
    const next = task.status === "todo" ? "in_progress" : "done";
    try {
      await api(`/tasks/${task.id}/`, { method: "PATCH", body: { status: next } });
      onChanged();
    } catch (e) {
      setError(e.message);
    }
  };

  const remove = async () => {
    if (!confirm(`"${task.title}" o'chirilsinmi?`)) return;
    try {
      await api(`/tasks/${task.id}/`, { method: "DELETE" });
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
          <span className="font-semibold">{task.title}</span>
          <span
            className="rounded-full px-2 py-0.5 text-[10px] font-medium"
            style={{ background: `color-mix(in srgb, ${TASK_STATUS[task.status].color} 16%, transparent)`, color: TASK_STATUS[task.status].color }}
          >
            {TASK_STATUS[task.status].label}
          </span>
          {isOverdue && (
            <span className="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium" style={{ background: "rgba(231,76,60,.15)", color: "#e74c3c" }}>
              <Clock size={11} /> Muddati o'tdi
            </span>
          )}
        </div>
        <div className="text-xs" style={{ color: "var(--muted)" }}>
          {stage.label}
          {task.order_display && ` · Buyurtma ${task.order_display}`}
          {manager && task.assigned_to_name && ` · ${task.assigned_to_name}`}
          {task.deadline && ` · muddat: ${task.deadline}`}
        </div>
        {task.description && <div className="mt-1 text-sm">{task.description}</div>}
        {error && <div className="error mt-1">{error}</div>}
      </div>
      <div className="flex gap-2">
        {task.status !== "done" && (
          <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={advance}>
            {task.status === "todo" ? <><Play size={12} /> Boshlash</> : <><Check size={12} /> Bajarildi</>}
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
