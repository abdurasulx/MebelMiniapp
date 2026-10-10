// Sotuvchi brauzerida 3D modeldan standart rasmlarni olish va serverga yuklash.
// Render sahifa (/render/index.html, model-viewer) yashirin iframe'da ishlaydi va
// har bir rakurs uchun PNG qaytaradi; serverda faqat standartlash/saqlash bor.
import { api, apiUpload } from "../api";

const SHOTS = "hero,front,side,back,top";
const IFRAME_TIMEOUT_MS = 180_000;

function dataUrlToBlob(dataUrl) {
  const [head, b64] = dataUrl.split(",");
  const mime = /data:([^;]+)/.exec(head)?.[1] || "image/png";
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i += 1) bytes[i] = bin.charCodeAt(i);
  return new Blob([bytes], { type: mime });
}

/** Bitta GLB'ni yashirin iframe'da render qiladi; natija: {dimensionsCm, variants:[{name,id,shots}]}. */
function renderInIframe(glbUrl, variants) {
  return new Promise((resolve, reject) => {
    const q = new URLSearchParams({
      src: glbUrl,
      size: "1600",
      shots: SHOTS,
      auto: "1",
      variants: JSON.stringify(variants),
    });
    const frame = document.createElement("iframe");
    frame.title = "render";
    frame.setAttribute("aria-hidden", "true");
    // Ko'rinmas, lekin viewport ichida (model-viewer IntersectionObserver uchun).
    Object.assign(frame.style, {
      position: "fixed", left: "0", top: "0", width: "800px", height: "800px",
      opacity: "0.01", pointerEvents: "none", border: "0", zIndex: "-1",
    });
    let timer;
    const cleanup = () => {
      clearTimeout(timer);
      window.removeEventListener("message", onMsg);
      frame.remove();
    };
    const onMsg = (e) => {
      if (e.source !== frame.contentWindow || e.data?.type !== "vida-render") return;
      cleanup();
      if (e.data.ok) resolve(e.data.result);
      else reject(new Error(e.data.error || "Brauzerda rasm olib bo'lmadi"));
    };
    window.addEventListener("message", onMsg);
    timer = setTimeout(() => {
      cleanup();
      reject(new Error("Rasm olish vaqti tugadi. Qurilmangiz WebGL'ni qo'llab-quvvatlashini tekshiring."));
    }, IFRAME_TIMEOUT_MS);
    frame.src = `/render/index.html?${q}`;
    document.body.appendChild(frame);
  });
}

/** Mahsulotning render manbalari: umumiy GLB va o'z GLB'iga ega variantlar. */
export function renderSources(product) {
  const usable = (m) => m && m.status === "ready" && m.glb_url && /\.glb(\?|$)/i.test(m.glb_url);
  const sources = [];
  if (usable(product.model3d)) {
    sources.push({
      glbUrl: product.model3d.glb_url,
      variant: null,
      tints: product.variants.map((v) => ({
        id: v.id, name: v.name, color: v.color_hex || "", texture: v.texture_url || "",
      })),
    });
  }
  product.variants.forEach((v) => {
    if (usable(v.model3d)) sources.push({ glbUrl: v.model3d.glb_url, variant: v, tints: [] });
  });
  return sources;
}

/**
 * 3D modeldan rasmlarni oladi va serverga yuboradi. `onProgress({stage, done, total, label})`.
 * Qaytaradi: yangilangan mahsulot (render-complete javobi).
 */
export async function captureAndUpload(product, onProgress = () => {}) {
  const sources = renderSources(product);
  if (!sources.length) throw new Error("Render uchun tayyor GLB model yo'q.");

  // 1) Hamma manbalarni brauzerda render qilamiz.
  const rendered = [];
  for (let i = 0; i < sources.length; i += 1) {
    onProgress({ stage: "capture", done: i, total: sources.length, label: "Model ko'rinishlari olinmoqda…" });
    const src = sources[i];
    const result = await renderInIframe(src.glbUrl, src.tints);
    rendered.push({ src, result });
  }

  // 2) Yuklanadigan rasmlar ro'yxati.
  const jobs = [];
  let dims = null;
  rendered.forEach(({ src, result }) => {
    dims = dims || result.dimensionsCm;
    result.variants.forEach((v) => {
      const variantId = src.variant ? src.variant.id : v.id || null;
      const name = src.variant ? src.variant.name : v.name;
      v.shots.forEach((s) => jobs.push({ variantId, name, shot: s.key, dataUrl: s.dataUrl }));
    });
  });

  // 3) Serverga yuklash (har bir rakurs — alohida so'rov, foiz ko'rsatiladi).
  for (let i = 0; i < jobs.length; i += 1) {
    const j = jobs[i];
    onProgress({ stage: "upload", done: i, total: jobs.length, label: "Rasmlar saqlanmoqda…" });
    const fd = new FormData();
    fd.append("image", dataUrlToBlob(j.dataUrl), `${j.shot}.png`);
    fd.append("shot", j.shot);
    if (j.variantId) fd.append("variant", j.variantId);
    fd.append("variant_name", j.name);
    await apiUpload(`/products/${product.id}/render-image/`, fd);
  }
  onProgress({ stage: "upload", done: jobs.length, total: jobs.length, label: "Yakunlanmoqda…" });
  return api(`/products/${product.id}/render-complete/`, {
    method: "POST",
    body: { dimensions_cm: dims },
  });
}

export async function reportRenderFailure(productId, message) {
  try {
    await api(`/products/${productId}/render-failed/`, { method: "POST", body: { error: message } });
  } catch (_) {
    /* e'tiborsiz */
  }
}
