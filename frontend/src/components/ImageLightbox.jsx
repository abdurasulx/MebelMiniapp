import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { ChevronLeft, ChevronRight, ImageOff, X } from "lucide-react";
import { useLocale } from "../locale";

const MAX_SCALE = 4;
const DOUBLE_TAP_SCALE = 2.5;
const DOUBLE_TAP_MS = 300;
const SWIPE_MIN_PX = 60;
const MAX_DOTS = 7;

const clamp = (v, min, max) => Math.min(max, Math.max(min, v));

/**
 * Marketplace uslubidagi to'liq ekranli rasm galereyasi.
 *
 * `images` — URL'lar ro'yxati, `index` — hozir ko'rsatilayotgani. Indeks
 * tashqaridan boshqariladi (`onIndexChange`), shuning uchun mahsulot
 * sahifasidagi joriy rasm modal ichidagi almashtirish bilan sinxron turadi.
 *
 * Imo-ishoralar (Pointer Events): bitta barmoq bilan surish — rasm almashadi
 * (kattalashtirilgan bo'lsa — rasm siljiydi), ikki barmoq — pinch-zoom,
 * ikki marta bosish — kattalashtirish/qaytarish, g'ildirak — zoom. Klaviatura:
 * Esc, ←, →.
 */
export default function ImageLightbox({ images, index, onIndexChange, onClose, alt = "" }) {
  const { t } = useLocale();
  const count = images.length;
  const multi = count > 1;

  const stageRef = useRef(null);
  const pointers = useRef(new Map());
  const gesture = useRef({ mode: null, startX: 0, startY: 0, startView: null, pinchDist: 1, pinchScale: 1, moved: false });
  const lastTap = useRef({ t: 0, x: 0, y: 0 });
  const [view, setView] = useState({ s: 1, x: 0, y: 0 });
  const [dragX, setDragX] = useState(0);
  const [gesturing, setGesturing] = useState(false);
  // url -> "ok" | "error"; qaytib kelinganda placeholder qayta ko'rinmasligi uchun saqlanadi.
  const [status, setStatus] = useState({});

  const go = useCallback(
    (delta) => {
      const next = clamp(index + delta, 0, count - 1);
      if (next !== index) onIndexChange(next);
    },
    [index, count, onIndexChange],
  );

  // Rasm almashganda kattalashtirish tiklanadi.
  useEffect(() => {
    setView({ s: 1, x: 0, y: 0 });
    setDragX(0);
  }, [index]);

  // Qo'shni rasmlar oldindan yuklanadi — surilganda bo'sh joy ko'rinmaydi.
  useEffect(() => {
    [index - 1, index + 1].forEach((i) => {
      if (images[i]) new Image().src = images[i];
    });
  }, [index, images]);

  // Orqa sahifa scroll qilinmaydi; yopilganda avvalgi fokus qaytariladi.
  useEffect(() => {
    const prevOverflow = document.body.style.overflow;
    const prevFocus = document.activeElement;
    document.body.style.overflow = "hidden";
    stageRef.current?.focus();
    return () => {
      document.body.style.overflow = prevOverflow;
      prevFocus?.focus?.();
    };
  }, []);

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === "Escape") onClose();
      else if (e.key === "ArrowLeft") go(-1);
      else if (e.key === "ArrowRight") go(1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [go, onClose]);

  const clampView = (v) => {
    const rect = stageRef.current?.getBoundingClientRect();
    if (!rect || v.s <= 1) return { s: 1, x: 0, y: 0 };
    const maxX = (rect.width * (v.s - 1)) / 2;
    const maxY = (rect.height * (v.s - 1)) / 2;
    return { s: v.s, x: clamp(v.x, -maxX, maxX), y: clamp(v.y, -maxY, maxY) };
  };

  const zoomAt = (px, py) => {
    if (view.s > 1) {
      setView({ s: 1, x: 0, y: 0 });
      return;
    }
    const rect = stageRef.current.getBoundingClientRect();
    const relX = px - (rect.left + rect.width / 2);
    const relY = py - (rect.top + rect.height / 2);
    setView(clampView({ s: DOUBLE_TAP_SCALE, x: relX * (1 - DOUBLE_TAP_SCALE), y: relY * (1 - DOUBLE_TAP_SCALE) }));
  };

  const onPointerDown = (e) => {
    stageRef.current.setPointerCapture(e.pointerId);
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    const g = gesture.current;
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()];
      g.mode = "pinch";
      g.pinchDist = Math.hypot(a.x - b.x, a.y - b.y) || 1;
      g.pinchScale = view.s;
      g.moved = true;
    } else {
      g.mode = view.s > 1 ? "pan" : "swipe";
      g.startX = e.clientX;
      g.startY = e.clientY;
      g.startView = view;
      g.moved = false;
    }
    setGesturing(true);
  };

  const onPointerMove = (e) => {
    if (!pointers.current.has(e.pointerId)) return;
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY });
    const g = gesture.current;
    if (g.mode === "pinch" && pointers.current.size >= 2) {
      const [a, b] = [...pointers.current.values()];
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      const s = clamp(g.pinchScale * (dist / g.pinchDist), 1, MAX_SCALE);
      setView((v) => clampView({ ...v, s }));
      return;
    }
    const dx = e.clientX - g.startX;
    const dy = e.clientY - g.startY;
    if (Math.hypot(dx, dy) > 8) g.moved = true;
    if (g.mode === "pan") {
      setView(clampView({ s: g.startView.s, x: g.startView.x + dx, y: g.startView.y + dy }));
    } else if (g.mode === "swipe" && multi && Math.abs(dx) > Math.abs(dy)) {
      const atEdge = (index === 0 && dx > 0) || (index === count - 1 && dx < 0);
      setDragX(atEdge ? dx * 0.3 : dx);
    }
  };

  const onPointerEnd = (e) => {
    if (!pointers.current.has(e.pointerId)) return;
    pointers.current.delete(e.pointerId);
    const g = gesture.current;
    if (pointers.current.size > 0) return; // pinch'ning bir barmog'i qoldi — kutamiz
    if (g.mode === "swipe") {
      const threshold = Math.min(SWIPE_MIN_PX, (stageRef.current?.clientWidth || 300) * 0.18);
      if (dragX <= -threshold) go(1);
      else if (dragX >= threshold) go(-1);
    }
    if (!g.moved && e.type === "pointerup") {
      const now = Date.now();
      const last = lastTap.current;
      if (now - last.t < DOUBLE_TAP_MS && Math.hypot(e.clientX - last.x, e.clientY - last.y) < 30) {
        zoomAt(e.clientX, e.clientY);
        lastTap.current = { t: 0, x: 0, y: 0 };
      } else {
        lastTap.current = { t: now, x: e.clientX, y: e.clientY };
      }
    }
    g.mode = null;
    setDragX(0);
    setGesturing(false);
  };

  const onWheel = (e) => {
    const factor = e.deltaY < 0 ? 1.15 : 1 / 1.15;
    setView((v) => clampView({ ...v, s: clamp(v.s * factor, 1, MAX_SCALE) }));
  };

  // Ko'p rasmda nuqtalar oynasi MAX_DOTS bilan cheklanadi, chetlari kichrayadi.
  const dotStart = clamp(index - Math.floor(MAX_DOTS / 2), 0, Math.max(0, count - MAX_DOTS));
  const dots = Array.from({ length: Math.min(count, MAX_DOTS) }, (_, k) => dotStart + k);

  const smooth = gesturing ? "none" : "transform 300ms cubic-bezier(0.22, 0.8, 0.3, 1)";
  const pill = { background: "rgba(0,0,0,0.5)", backdropFilter: "blur(8px)", color: "#fff" };

  return createPortal(
    <div
      role="dialog"
      aria-modal="true"
      aria-label={alt}
      className="fixed inset-0 z-[100] flex select-none flex-col"
      style={{ background: "rgba(10,8,7,0.97)", backdropFilter: "blur(6px)" }}
    >
      <div
        ref={stageRef}
        tabIndex={-1}
        className="absolute inset-0 overflow-hidden outline-none"
        style={{ touchAction: "none", cursor: view.s > 1 ? "grab" : "zoom-in" }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerEnd}
        onPointerCancel={onPointerEnd}
        onWheel={onWheel}
      >
        <div
          className="flex h-full w-full will-change-transform"
          style={{ transform: `translate3d(calc(${-index * 100}% + ${dragX}px), 0, 0)`, transition: smooth }}
        >
          {images.map((src, i) => {
            if (Math.abs(i - index) > 1) return <div key={i} className="h-full shrink-0 basis-full" />;
            const st = status[src];
            const current = i === index;
            return (
              <div key={i} className="relative flex h-full shrink-0 basis-full items-center justify-center p-2 sm:p-8">
                {st !== "ok" && st !== "error" && (
                  <div className="absolute h-10 w-10 animate-spin rounded-full border-2 border-white/20 border-t-white/80" />
                )}
                {st === "error" ? (
                  <div className="flex flex-col items-center gap-2 text-white/70">
                    <ImageOff size={36} />
                    <span className="text-sm">{t("gallery_image_error")}</span>
                  </div>
                ) : (
                  <img
                    src={src}
                    alt={alt}
                    draggable={false}
                    decoding="async"
                    onLoad={() => setStatus((s) => ({ ...s, [src]: "ok" }))}
                    onError={() => setStatus((s) => ({ ...s, [src]: "error" }))}
                    className="h-full w-full object-contain transition-opacity duration-200"
                    style={{
                      opacity: st === "ok" ? 1 : 0,
                      transform: current ? `translate3d(${view.x}px, ${view.y}px, 0) scale(${view.s})` : undefined,
                      transition: gesturing ? "opacity 200ms" : "opacity 200ms, transform 250ms cubic-bezier(0.22, 0.8, 0.3, 1)",
                    }}
                  />
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div
        className="pointer-events-none relative flex items-start justify-between p-3 sm:p-5"
        style={{ paddingTop: "calc(0.75rem + env(safe-area-inset-top))" }}
      >
        {multi ? (
          <span className="pointer-events-auto rounded-full px-3 py-1.5 text-sm font-medium tabular-nums" style={pill} aria-live="polite">
            {index + 1} / {count}
          </span>
        ) : (
          <span />
        )}
        <button
          type="button"
          onClick={onClose}
          aria-label={t("gallery_close")}
          title={`${t("gallery_close")} (Esc)`}
          className="pointer-events-auto flex h-10 w-10 items-center justify-center rounded-full transition hover:bg-white/20"
          style={pill}
        >
          <X size={20} />
        </button>
      </div>

      {multi && (
        <>
          {[-1, 1].map((dir) => {
            const disabled = dir < 0 ? index === 0 : index === count - 1;
            const Icon = dir < 0 ? ChevronLeft : ChevronRight;
            return (
              <button
                key={dir}
                type="button"
                onClick={() => go(dir)}
                disabled={disabled}
                aria-label={t(dir < 0 ? "gallery_prev" : "gallery_next")}
                className={`absolute top-1/2 hidden h-12 w-12 -translate-y-1/2 items-center justify-center rounded-full transition hover:bg-white/20 disabled:opacity-25 md:flex ${dir < 0 ? "left-5" : "right-5"}`}
                style={pill}
              >
                <Icon size={24} />
              </button>
            );
          })}

          <div
            className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-center pb-5"
            style={{ paddingBottom: "calc(1.25rem + env(safe-area-inset-bottom))" }}
          >
            <div className="pointer-events-auto flex items-center gap-1.5 rounded-full px-3 py-2" style={pill}>
              {dots.map((i) => {
                const edge = count > MAX_DOTS && ((i === dots[0] && i > 0) || (i === dots[dots.length - 1] && i < count - 1));
                const active = i === index;
                return (
                  <button
                    key={i}
                    type="button"
                    onClick={() => onIndexChange(i)}
                    aria-label={`${i + 1} / ${count}`}
                    aria-current={active}
                    className="rounded-full"
                    style={{
                      height: active ? 8 : edge ? 4 : 6,
                      width: active ? 20 : edge ? 4 : 6,
                      background: active ? "#fff" : "rgba(255,255,255,0.4)",
                      transition: "all 250ms cubic-bezier(0.22, 0.8, 0.3, 1)",
                    }}
                  />
                );
              })}
            </div>
          </div>
        </>
      )}
    </div>,
    document.body,
  );
}
