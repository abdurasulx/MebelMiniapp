import { useEffect, useState } from "react";
import { CircleCheckBig, Loader2, CircleDashed, Camera, Send } from "lucide-react";
import { api } from "../api";

const STATUS_ICON = { completed: CircleCheckBig, in_progress: Loader2, pending: CircleDashed };
const STATUS_COLOR = { completed: "#27ae60", in_progress: "#3498db", pending: "var(--muted)" };

/**
 * Buyurtma ishlab chiqarish jarayoni — firma tomonida progress/complete
 * amallari bilan (editable), mijoz tomonida faqat o'qish uchun (timeline).
 */
export default function WorkflowPanel({ order, editable = false, onChanged }) {
  const [activeStep, setActiveStep] = useState(null);
  const [prediction, setPrediction] = useState(null);

  useEffect(() => {
    api(`/orders/${order.id}/prediction/`).then(setPrediction).catch(() => {});
  }, [order.id]);

  const steps = order.workflow_steps || [];

  return (
    <div
      className="flex flex-col gap-4 rounded-xl p-4"
      style={{ border: "1px dashed var(--border)", background: "color-mix(in srgb, var(--primary) 8%, transparent)" }}
    >
      {editable && order.production_cost && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {/* Tannarx/foyda faqat firma egasiga qaytariladi (qarang
              OrderSerializer.get_production_cost) — oddiy xodimga
              `production_cost` faqat `selling_price` bilan keladi. */}
          {order.production_cost.profit !== undefined && (
            <>
              <CostTile label="Ishlab chiqarish" value={order.production_cost.total_cost} />
              <CostTile
                label="Foyda"
                value={order.production_cost.profit}
                color={order.production_cost.profit >= 0 ? "#27ae60" : "#e74c3c"}
              />
            </>
          )}
          <CostTile label="Sotuv narxi" value={order.production_cost.selling_price} />
          {prediction?.estimated_finish && (
            <CostTile
              label={`Taxminiy tugash (${Math.round((prediction.confidence || 0) * 100)}%)`}
              value={new Date(prediction.estimated_finish).toLocaleDateString("uz-UZ")}
              isText
            />
          )}
        </div>
      )}

      <div className="flex flex-col gap-3">
        {steps.map((step) => (
          <StepCard
            key={step.id}
            step={step}
            editable={editable}
            active={activeStep === step.id}
            onToggle={() => setActiveStep(activeStep === step.id ? null : step.id)}
            onChanged={onChanged}
          />
        ))}
      </div>
    </div>
  );
}

function CostTile({ label, value, color, isText }) {
  return (
    <div className="card p-3">
      <div className="text-[10px]" style={{ color: "var(--muted)" }}>{label}</div>
      <div className="text-sm font-bold" style={{ color: color || "inherit" }}>
        {isText ? value : `${Number(value).toLocaleString()} so'm`}
      </div>
    </div>
  );
}

function StepCard({ step, editable, active, onToggle, onChanged }) {
  const Icon = STATUS_ICON[step.status];
  const color = STATUS_COLOR[step.status];
  // Bosqich hali "erkin" (pending + is_available) bo'lsa — avval aniq
  // QABUL QILISH kerak, undan keyingina yangilanish/yakunlash ko'rinadi
  // (mobil ilovadagi "Boshlash" bilan bir xil qadam — avval bittasi
  // to'g'ridan-to'g'ri yakunlash tugmasini bosib qo'yishi mumkin bo'lib,
  // kim qachon boshlaganini bilib bo'lmas edi).
  const canStart = editable && step.status === "pending" && step.is_available;
  const canProgress = editable && step.status === "in_progress";
  const canAct = canStart || canProgress;

  return (
    <div className="card p-3">
      <button
        className="flex w-full items-center gap-3 text-left"
        onClick={canAct || step.updates?.length > 0 ? onToggle : undefined}
      >
        <Icon size={18} style={{ color }} className={step.status === "in_progress" ? "animate-spin" : ""} />
        <div className="min-w-0 flex-1">
          <div className="text-sm font-medium">{step.name}</div>
          <div className="text-xs" style={{ color: "var(--muted)" }}>
            {step.role_display || step.role}{step.employee_name ? ` · ${step.employee_name}` : ""}
            {step.updates?.length > 0 && ` · ${step.updates.length} yangilanish`}
          </div>
        </div>
        <span className="text-xs font-medium" style={{ color }}>{step.status_display}</span>
      </button>

      {active && (
        <div className="mt-3 flex flex-col gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
          {step.updates?.length > 0 && (
            <div className="flex flex-col gap-2">
              {step.updates.map((u) => (
                <div key={u.id} className="flex gap-2 rounded-lg p-2 text-xs" style={{ background: "var(--card)" }}>
                  {u.image_url && (
                    <img src={u.image_url} alt="" className="h-14 w-14 shrink-0 rounded-lg object-cover" />
                  )}
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5" style={{ color: "var(--muted)" }}>
                      {u.is_completion && <CircleCheckBig size={11} style={{ color: "#27ae60" }} />}
                      {u.employee_name} · {new Date(u.created_at).toLocaleString("uz-UZ")}
                    </div>
                    {u.comment && <p className="mt-0.5">{u.comment}</p>}
                  </div>
                </div>
              ))}
            </div>
          )}
          {canStart && <StartAction step={step} onChanged={onChanged} />}
          {canProgress && <StepActions step={step} onChanged={onChanged} />}
        </div>
      )}
    </div>
  );
}

function StartAction({ step, onChanged }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const start = async () => {
    setError("");
    setBusy(true);
    try {
      if (step.is_manual) {
        await api(`/workflow-instances/${step.id}/`, { method: "PATCH", body: { status: "in_progress" } });
      } else {
        // Retsept bosqichi to'g'ridan-to'g'ri PATCH orqali boshlanmaydi
        // (backend qasddan rad etadi — qarang WorkflowStepInstanceViewSet.
        // perform_update). `progress` amali esa ichida `activate_if_ready()`
        // chaqiradi, u xuddi shu pending->in_progress o'tishni bajaradi —
        // bo'sh so'rov bilan chaqirish "qabul qilish"ning to'g'ri usuli.
        await api(`/workflow-instances/${step.id}/progress/`, { method: "POST", body: {} });
      }
      onChanged?.();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-2">
      <button className="btn btn-brand inline-flex w-fit items-center gap-1.5 !px-3 !py-1.5 text-xs" disabled={busy} onClick={start}>
        <CircleCheckBig size={13} /> {busy ? "Qabul qilinmoqda…" : "Qabul qilish"}
      </button>
      {error && <div className="error">{error}</div>}
    </div>
  );
}

function StepActions({ step, onChanged }) {
  const [comment, setComment] = useState("");
  const [image, setImage] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const post = async (path) => {
    if (path === "complete" && step.photo_requirement === "required" && !image) {
      setError("Bu bosqichni yakunlash uchun rasm majburiy");
      return;
    }
    if (path === "complete" && step.comment_requirement === "required" && !comment) {
      setError("Bu bosqichni yakunlash uchun izoh majburiy");
      return;
    }
    setError("");
    setBusy(true);
    try {
      const fd = new FormData();
      if (comment) fd.append("comment", comment);
      if (image) fd.append("image", image);
      await api(`/workflow-instances/${step.id}/${path}/`, { method: "POST", body: fd, isForm: true });
      setComment("");
      setImage(null);
      onChanged?.();
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-2">
      <textarea
        className="input"
        rows={2}
        placeholder="Izoh (ixtiyoriy)…"
        value={comment}
        onChange={(e) => setComment(e.target.value)}
      />
      <div className="flex flex-wrap items-center gap-2">
        <label className="btn-ghost inline-flex cursor-pointer items-center gap-1 !px-3 !py-1.5 text-xs">
          <Camera size={13} /> {image ? image.name : "Rasm"}
          <input type="file" accept="image/*" className="hidden" onChange={(e) => setImage(e.target.files[0])} />
        </label>
        <button className="btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" disabled={busy} onClick={() => post("progress")}>
          <Send size={13} /> Yangilanish qo'shish
        </button>
        <button className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" disabled={busy} onClick={() => post("complete")}>
          <CircleCheckBig size={13} /> Bosqichni yakunlash
        </button>
      </div>
      {step.photo_requirement === "required" && (
        <p className="text-[11px]" style={{ color: "var(--muted)" }}>Yakunlash uchun rasm majburiy.</p>
      )}
      {step.comment_requirement === "required" && (
        <p className="text-[11px]" style={{ color: "var(--muted)" }}>Yakunlash uchun izoh majburiy.</p>
      )}
      {error && <div className="error">{error}</div>}
    </div>
  );
}
