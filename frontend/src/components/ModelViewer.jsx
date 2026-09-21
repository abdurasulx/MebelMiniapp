import { useEffect, useRef, useState } from "react";
import { Play, Pause } from "lucide-react";

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
 */
export default function ModelViewer({ glb, usdz, alt = "3D model", poster, style, colorHex, textureUrl }) {
  const ref = useRef(null);
  const [hasAnimation, setHasAnimation] = useState(false);
  const [playing, setPlaying] = useState(false);

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
      ar=""
      ar-modes="webxr scene-viewer quick-look"
      shadow-intensity="1"
      style={{
        width: "100%",
        height: "360px",
        borderRadius: "16px",
        background: "var(--card)",
        ...style,
      }}
    ></model-viewer>
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
}
