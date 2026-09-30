import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { Play, Pause, RotateCw } from "lucide-react";

let loaded = false;

const JOYSTICK_RADIUS = 32;

/**
 * Modelni siljitish uchun joystik (iOS ilovadagi `PositionJoystick`ning web
 * ekvivalenti) — bosib turib istalgan tomonga sudrash davomida
 * `onMove(dx, dz)` normallashtirilgan (-1..1) yo'nalishni doim yangilab
 * beradi, qo'yib yuborilganda tugma markazga qaytadi.
 */
function PositionJoystick({ onMove }) {
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  // `tick`ning o'z-o'ziga qayta chaqiriladigan requestAnimationFrame sikli
  // birinchi chaqiruvdagi closure'ni "eskirgan holda" saqlab qoladi — shu
  // sababli offset holati state emas, ref orqali o'qiladi (aks holda
  // joystik faqat vizual harakat qilib, modelni haqiqatda siljitmasdi).
  const offsetRef = useRef({ x: 0, y: 0 });
  const draggingRef = useRef(false);
  const rafRef = useRef(null);

  const stop = () => {
    draggingRef.current = false;
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    rafRef.current = null;
    offsetRef.current = { x: 0, y: 0 };
    setOffset({ x: 0, y: 0 });
  };

  const tick = () => {
    if (!draggingRef.current) return;
    const { x, y } = offsetRef.current;
    if (x !== 0 || y !== 0) onMove(x / JOYSTICK_RADIUS, y / JOYSTICK_RADIUS);
    rafRef.current = requestAnimationFrame(tick);
  };

  const onPointerDown = (e) => {
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // ba'zi brauzer/holatlarda pointer capture mumkin bo'lmasligi mumkin —
      // baribir sudrashni boshlayveramiz (onPointerMove baribir ishlaydi).
    }
    draggingRef.current = true;
    const rect = e.currentTarget.getBoundingClientRect();
    updateFromEvent(e, rect);
    rafRef.current = requestAnimationFrame(tick);
  };

  const updateFromEvent = (e, rect) => {
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    let dx = e.clientX - cx;
    let dy = e.clientY - cy;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > JOYSTICK_RADIUS) {
      dx = (dx / dist) * JOYSTICK_RADIUS;
      dy = (dy / dist) * JOYSTICK_RADIUS;
    }
    offsetRef.current = { x: dx, y: dy };
    setOffset({ x: dx, y: dy });
  };

  const onPointerMove = (e) => {
    if (!draggingRef.current) return;
    updateFromEvent(e, e.currentTarget.getBoundingClientRect());
  };

  useEffect(() => stop, []);

  return (
    <div
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={stop}
      onPointerCancel={stop}
      title="Sudrab modelni siljiting"
      style={{
        position: "absolute",
        right: 12,
        bottom: 12,
        width: 76,
        height: 76,
        borderRadius: "50%",
        background: "rgba(0,0,0,.28)",
        backdropFilter: "blur(2px)",
        touchAction: "none",
        cursor: "grab",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: "50%",
          top: "50%",
          width: 32,
          height: 32,
          borderRadius: "50%",
          background: "#fff",
          boxShadow: "0 2px 6px rgba(0,0,0,.3)",
          transform: `translate(calc(-50% + ${offset.x}px), calc(-50% + ${offset.y}px))`,
        }}
      />
    </div>
  );
}

/**
 * Modelni burish uchun gorizontal chizg'ich (iOS ilovadagi rotatsiya
 * slayderining web ekvivalenti) — chapga/o'ngga sudrash `onRotate(deltaDeg)`
 * chaqiradi, boshlanish nuqtasidan farq har hodisada beriladi.
 */
function RotateBar({ onRotate }) {
  const lastXRef = useRef(null);

  const onPointerDown = (e) => {
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // qarang PositionJoystick'dagi izoh
    }
    lastXRef.current = e.clientX;
  };
  const onPointerMove = (e) => {
    if (lastXRef.current == null) return;
    const deltaDeg = (e.clientX - lastXRef.current) * 0.6;
    lastXRef.current = e.clientX;
    onRotate(deltaDeg);
  };
  const stop = () => {
    lastXRef.current = null;
  };

  return (
    <div
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={stop}
      onPointerCancel={stop}
      title="Sudrab modelni bering"
      style={{
        position: "absolute",
        left: "50%",
        top: 12,
        transform: "translateX(-50%)",
        display: "flex",
        alignItems: "center",
        gap: 6,
        padding: "7px 16px",
        borderRadius: 999,
        background: "rgba(0,0,0,.28)",
        backdropFilter: "blur(2px)",
        color: "#fff",
        fontSize: 12.5,
        fontWeight: 600,
        touchAction: "none",
        cursor: "grab",
        userSelect: "none",
      }}
    >
      <RotateCw size={14} /> Burish
    </div>
  );
}

function hexToRgba(hex) {
  if (!hex || hex.length < 7) return null;
  const h = hex.replace("#", "");
  const r = parseInt(h.substring(0, 2), 16) / 255;
  const g = parseInt(h.substring(2, 4), 16) / 255;
  const b = parseInt(h.substring(4, 6), 16) / 255;
  return [r, g, b, 1];
}

/**
 * 3D model ko'rsatgich (Google <model-viewer>).
 * GLB — web/Android AR, USDZ — iOS AR Quick Look.
 *
 * `colorHex`/`textureUrl` — bitta geometriyaga rang variantini runtime'da
 * qo'llash uchun (har rang uchun alohida GLB shart emas): tekstura berilsa
 * material'ning baseColorTexture'i, aks holda oddiy rang tint (baseColorFactor)
 * o'rnatiladi. Xuddi shu yondashuv iOS'da RealityKit material orqali qo'llanadi.
 *
 * AR'ga kirish endi model-viewer'ning o'z (ba'zan hali tayyor bo'lmasa ham
 * bosiladigan, shuning uchun "tanlanmay qoladi" degan xatoga o'xshab
 * ko'rinadigan) ichki tugmasi orqali emas — shu tugma butunlay
 * yashirilgan (`slot="ar-button"`ga ko'rinmas almashtiruvchi qo'yilgan),
 * o'rniga tashqaridan `ref.current.activateAR()` chaqiriladi (qarang
 * ProductDetail.jsx). Bu haqiqatda model TO'LIQ yuklangandan va AR'ning
 * shu qurilmada ishlashi tasdiqlangandan keyingina mumkin bo'ladi —
 * `onReadyChange`/`onArSupportedChange` orqali holat tashqariga chiqadi,
 * shunda tugma "hali tayyor emas" paytida o'chirilgan (disabled) holda
 * turadi va bosilganda hech narsa qilmasdan qolib ketmaydi.
 */
const ModelViewer = forwardRef(function ModelViewer(
  { glb, usdz, alt = "3D model", poster, style, colorHex, textureUrl, onReadyChange, onArSupportedChange },
  forwardedRef
) {
  const ref = useRef(null);
  const [hasAnimation, setHasAnimation] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [ready, setReady] = useState(false);

  useImperativeHandle(forwardedRef, () => ({
    activateAR: () => ref.current?.activateAR(),
  }));

  useEffect(() => {
    if (!loaded) {
      import("@google/model-viewer");
      loaded = true;
    }
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const apply = async () => {
      const materials = el.model?.materials || [];
      if (!materials.length) return;
      if (textureUrl) {
        try {
          const texture = await el.createTexture(textureUrl);
          materials.forEach((m) => m.pbrMetallicRoughness.baseColorTexture.setTexture(texture));
        } catch {
          // tekstura yuklanmasa jim o'tkazamiz
        }
      } else {
        const rgba = hexToRgba(colorHex);
        if (rgba) materials.forEach((m) => m.pbrMetallicRoughness.setBaseColorFactor(rgba));
      }
    };

    el.addEventListener("load", apply);
    if (el.loaded) apply();
    return () => el.removeEventListener("load", apply);
  }, [glb, colorHex, textureUrl]);

  // Model o'z animatsiyasiga ega bo'lsagina play tugmasi chiqadi (GLB
  // `animations` — masalan eshik/tortma ochilishi). Avtomatik boshlanmaydi.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setHasAnimation(false);
    setPlaying(false);
    const check = () => setHasAnimation((el.availableAnimations || []).length > 0);
    el.addEventListener("load", check);
    if (el.loaded) check();
    return () => el.removeEventListener("load", check);
  }, [glb]);

  // Tayyorlik holati — model to'liq yuklanganda va shu qurilmada AR'ni
  // haqiqatan boshlash mumkinligi ma'lum bo'lganda tashqariga xabar beriladi.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setReady(false);
    onReadyChange?.(false);
    onArSupportedChange?.(false);

    const onLoad = () => {
      setReady(true);
      onReadyChange?.(true);
    };
    const onArStatus = (e) => {
      // "not-presenting" — AR ishga tayyor (hali boshlanmagan); "failed" —
      // bu qurilma/brauzerda AR umuman ishlamaydi (masalan desktop Chrome).
      onArSupportedChange?.(e.detail?.status !== "failed");
    };
    el.addEventListener("load", onLoad);
    el.addEventListener("ar-status", onArStatus);
    if (el.loaded) onLoad();
    return () => {
      el.removeEventListener("load", onLoad);
      el.removeEventListener("ar-status", onArStatus);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [glb, usdz]);

  const toggleAnimation = () => {
    const el = ref.current;
    if (!el) return;
    if (playing) {
      el.pause();
    } else {
      el.play({ repetitions: Infinity });
    }
    setPlaying(!playing);
  };

  // Joystik/burish orqali qo'lda boshqarish boshlanganda avtomatik aylanish
  // to'xtatiladi — aks holda foydalanuvchi qo'yib yuborgan burchakni
  // model o'zi darhol "buzib" qo'yardi.
  const stopAutoRotate = () => ref.current?.removeAttribute("auto-rotate");

  const handleJoystickMove = (dx, dz) => {
    const el = ref.current;
    if (!el || typeof el.getCameraTarget !== "function") return;
    stopAutoRotate();
    const target = el.getCameraTarget();
    const speed = 0.01;
    el.cameraTarget = `${target.x + dx * speed}m ${target.y}m ${target.z + dz * speed}m`;
  };

  const handleRotate = (deltaDeg) => {
    const el = ref.current;
    if (!el || typeof el.getCameraOrbit !== "function") return;
    stopAutoRotate();
    const orbit = el.getCameraOrbit();
    const thetaDeg = (orbit.theta * 180) / Math.PI + deltaDeg;
    const phiDeg = (orbit.phi * 180) / Math.PI;
    el.cameraOrbit = `${thetaDeg}deg ${phiDeg}deg ${orbit.radius}m`;
  };

  if (!glb && !usdz) return null;

  return (
    <div style={{ position: "relative" }}>
    <model-viewer
      ref={ref}
      src={glb || undefined}
      ios-src={usdz || undefined}
      alt={alt}
      poster={poster || undefined}
      camera-controls=""
      auto-rotate=""
      loading="eager"
      ar=""
      ar-modes="webxr scene-viewer quick-look"
      ar-scale="fixed"
      shadow-intensity="1"
      style={{
        width: "100%",
        height: "360px",
        borderRadius: "16px",
        background: "var(--card)",
        ...style,
      }}
    >
      {/* model-viewer'ning o'z (pastki o'ng burchakdagi) AR belgisi shu
          ko'rinmas tugma bilan almashtiriladi — AR faqat tashqi "AR'da
          ko'rish" tugmasi orqali, tayyor bo'lgandagina ishga tushadi. */}
      <button slot="ar-button" style={{ display: "none" }} aria-hidden="true" />
    </model-viewer>
    {ready && (
      <>
        <RotateBar onRotate={handleRotate} />
        <PositionJoystick onMove={handleJoystickMove} />
      </>
    )}
    {hasAnimation && (
      <button
        type="button"
        onClick={toggleAnimation}
        title={playing ? "Animatsiyani to'xtatish" : "Animatsiyani ijro etish"}
        style={{
          position: "absolute",
          left: 12,
          bottom: 12,
          display: "flex",
          alignItems: "center",
          gap: 6,
          padding: "8px 14px",
          borderRadius: 999,
          border: "1px solid var(--border)",
          background: "var(--card)",
          color: "var(--text)",
          fontSize: 13,
          fontWeight: 600,
          cursor: "pointer",
          boxShadow: "0 2px 8px rgba(0,0,0,.15)",
        }}
      >
        {playing ? <Pause size={15} /> : <Play size={15} />}
        {playing ? "To'xtatish" : "Animatsiya"}
      </button>
    )}
    </div>
  );
});

export default ModelViewer;
