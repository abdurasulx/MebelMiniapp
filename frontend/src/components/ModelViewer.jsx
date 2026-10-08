import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { Play, Pause, Ruler } from "lucide-react";
import { useLocale } from "../locale";

let loaded = false;

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
 * Burish/kattalashtirish `camera-controls` orqali model-viewer'ning o'z
 * sudrash/pinch harakatlari bilan ishlaydi — qo'shimcha joystik/slayder
 * UI shart emas (foydalanuvchi talabiga ko'ra olib tashlandi).
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
  const { t } = useLocale();
  // O'lcham chiziqlari (chizmachilikdagi kabi): model geometriyasining HAQIQIY
  // o'lchamidan (`getDimensions()`, metr) hisoblanadi.
  const [dimInfo, setDimInfo] = useState(null);
  const [showDims, setShowDims] = useState(false);
  const svgRef = useRef(null);

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
    onReadyChange?.(false);
    onArSupportedChange?.(false);

    const onLoad = () => onReadyChange?.(true);
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

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setDimInfo(null);
    setShowDims(false);
    const read = () => {
      const d = el.getDimensions?.();
      const c = el.getBoundingBoxCenter?.();
      if (d && c && d.x > 0 && d.y > 0 && d.z > 0) setDimInfo({ x: d.x, y: d.y, z: d.z, cx: c.x, cy: c.y, cz: c.z });
    };
    el.addEventListener("load", read);
    if (el.loaded) read();
    return () => el.removeEventListener("load", read);
  }, [glb]);

  // Hotspot nuqtalarining ekrandagi o'rniga qarab SVG chiziqlarini yangilaymiz (kamera
  // aylanganda/yaqinlashganda ham chiziqlar modelga yopishib turadi).
  useEffect(() => {
    const el = ref.current;
    if (!el || !showDims || !dimInfo) return undefined;
    // O'lchamlar ko'rinayotganda avto-aylanish to'xtatiladi va kamera old-o'ng tomondan
    // qaraydi — shunda 3 ta o'lcham qirrasi (old-past eni, chap bo'yi, o'ng-past chuqurligi)
    // doim ko'rinib turadi va yozuvlar bir-birini bosmaydi.
    const prevOrbit = el.cameraOrbit;
    const wasRotating = el.autoRotate;
    el.autoRotate = false;
    el.cameraOrbit = "35deg 72deg auto";
    el.jumpCameraToGoal?.();
    const pos = (name) => el.queryHotspot?.(`hotspot-${name}`)?.canvasPosition;
    const setLine = (id, a, b) => {
      const line = svgRef.current?.querySelector(`#dim-${id}`);
      if (!line || !a || !b) return;
      line.setAttribute("x1", a.x);
      line.setAttribute("y1", a.y);
      line.setAttribute("x2", b.x);
      line.setAttribute("y2", b.y);
    };
    const update = () => {
      const p1 = pos("p1"), p2 = pos("p2"), p3 = pos("p3"), p4 = pos("p4");
      setLine("w", p1, p2);
      setLine("h", p1, p3);
      setLine("d", p2, p4);
    };
    update();
    const raf = requestAnimationFrame(update);
    el.addEventListener("camera-change", update);
    return () => {
      cancelAnimationFrame(raf);
      el.removeEventListener("camera-change", update);
      el.autoRotate = wasRotating;
      if (prevOrbit) el.cameraOrbit = prevOrbit;
    };
  }, [showDims, dimInfo]);

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
      {showDims && dimInfo && <DimensionHotspots info={dimInfo} t={t} />}
    </model-viewer>
    {showDims && dimInfo && (
      <>
        <svg
          ref={svgRef}
          aria-hidden="true"
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", pointerEvents: "none", overflow: "visible" }}
        >
          {["w", "h", "d"].map((id) => (
            <line key={id} id={`dim-${id}`} stroke="var(--brand-secondary, #805c46)" strokeWidth="1.6" strokeDasharray="5 3" />
          ))}
        </svg>
        <div className="dim-volume">
          {t("dim_volume")}: {volumeText(dimInfo)} m³
        </div>
      </>
    )}
    {dimInfo && (
      <button
        type="button"
        onClick={() => setShowDims((v) => !v)}
        title={t("dim_title")}
        aria-pressed={showDims}
        style={{
          position: "absolute",
          right: 12,
          bottom: 12,
          display: "flex",
          alignItems: "center",
          gap: 6,
          padding: "8px 14px",
          borderRadius: 999,
          border: "1px solid var(--border)",
          background: showDims ? "var(--brand-cta-bg)" : "var(--card)",
          color: showDims ? "var(--brand-cta-text)" : "var(--text)",
          fontSize: 13,
          fontWeight: 600,
          cursor: "pointer",
          boxShadow: "0 2px 8px rgba(0,0,0,.15)",
        }}
      >
        <Ruler size={15} />
        {t("dim_title")}
      </button>
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

const cm = (m) => `${Math.round(m * 100)} sm`;
const volumeText = ({ x, y, z }) => {
  const v = x * y * z;
  const str = v >= 1 ? v.toFixed(2) : v.toFixed(3);
  return str.replace(/0+$/, "").replace(/\.$/, "");
};

/** O'lcham nuqtalari va yozuvlari: bounding box'ning old-past-chap burchagidan boshlanadigan
 *  3 qirra — eni (X), bo'yi (Y), chuqurligi (Z). */
function DimensionHotspots({ info, t }) {
  const { x, y, z, cx, cy, cz } = info;
  const hx = x / 2, hy = y / 2, hz = z / 2;
  const p1 = [cx - hx, cy - hy, cz + hz];
  const p2 = [cx + hx, cy - hy, cz + hz];
  const p3 = [cx - hx, cy + hy, cz + hz];
  const p4 = [cx + hx, cy - hy, cz - hz];
  const mid = (a, b) => a.map((v, i) => (v + b[i]) / 2);
  const at = (p) => p.map((v) => `${v}m`).join(" ");
  return (
    <>
      {[["p1", p1], ["p2", p2], ["p3", p3], ["p4", p4]].map(([name, p]) => (
        <button key={name} slot={`hotspot-${name}`} className="dim-dot" data-position={at(p)} data-normal="0 0 0" aria-hidden="true" tabIndex={-1} />
      ))}
      <button slot="hotspot-lw" className="dim-label" data-position={at(mid(p1, p2))} data-normal="0 0 0" tabIndex={-1}>
        {t("dim_width")} {cm(x)}
      </button>
      <button slot="hotspot-lh" className="dim-label" data-position={at(mid(p1, p3))} data-normal="0 0 0" tabIndex={-1}>
        {t("dim_height")} {cm(y)}
      </button>
      <button slot="hotspot-ld" className="dim-label" data-position={at(mid(p2, p4))} data-normal="0 0 0" tabIndex={-1}>
        {t("dim_depth")} {cm(z)}
      </button>
    </>
  );
}

export default ModelViewer;
