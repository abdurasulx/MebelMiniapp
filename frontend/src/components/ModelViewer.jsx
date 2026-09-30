import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
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
    </model-viewer>
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
