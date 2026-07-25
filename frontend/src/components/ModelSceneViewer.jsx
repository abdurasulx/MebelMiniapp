import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { Layers, Camera, Maximize, Link2, Check } from "lucide-react";

const MODES = [
  { value: "textured", label: "Teksturada" },
  { value: "textured_lines", label: "Teksturada, chiziqlar bilan" },
  { value: "wireframe", label: "Karkas" },
  { value: "effects", label: "Effektlar (studiya yorug'ligi)" },
  { value: "xray", label: "Rentgen rejimi" },
];

/**
 * Bazissoft.ru uslubidagi to'liq Three.js model ko'rsatgichi — bitta GLB'ni
 * yuklab, kamera bilan aylantirib ko'rish + render rejimlari (tekstura,
 * tekstura+chiziq, karkas, effekt, rentgen) o'rtasida almashtirish imkonini
 * beradi. `<model-viewer>` bunday material-darajadagi rejimlarni bermaydi,
 * shuning uchun bu yerda xom Three.js sahnasi ishlatiladi.
 */
export default function ModelSceneViewer({ glb, alt = "3D model", style }) {
  const mountRef = useRef(null);
  const stateRef = useRef({});
  const [mode, setMode] = useState("textured_lines");
  const [menuOpen, setMenuOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x11131c);

    const camera = new THREE.PerspectiveCamera(45, mount.clientWidth / mount.clientHeight, 0.01, 1000);
    camera.position.set(2, 1.6, 2.6);

    const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setSize(mount.clientWidth, mount.clientHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    mount.appendChild(renderer.domElement);

    const hemi = new THREE.HemisphereLight(0xffffff, 0x3a3a3a, 1.1);
    scene.add(hemi);
    const dir = new THREE.DirectionalLight(0xffffff, 1.6);
    dir.position.set(4, 6, 5);
    scene.add(dir);
    const rim = new THREE.DirectionalLight(0x9db8ff, 0.9);
    rim.position.set(-5, 3, -4);
    scene.add(rim);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.minDistance = 0.2;
    controls.maxDistance = 50;

    const pmremGenerator = new THREE.PMREMGenerator(renderer);
    const envTexture = pmremGenerator.fromScene(new RoomEnvironment(), 0.04).texture;

    const clock = new THREE.Clock();
    let raf;
    function animate() {
      raf = requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    function handleResize() {
      camera.aspect = mount.clientWidth / mount.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(mount.clientWidth, mount.clientHeight);
    }
    window.addEventListener("resize", handleResize);

    stateRef.current = { scene, camera, renderer, controls, envTexture, root: null };

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", handleResize);
      controls.dispose();
      renderer.dispose();
      pmremGenerator.dispose();
      mount.removeChild(renderer.domElement);
    };
  }, []);

  // GLB yuklash — model almashsa qayta yuklanadi.
  useEffect(() => {
    const st = stateRef.current;
    if (!st.scene || !glb) return;
    setLoading(true);

    const loader = new GLTFLoader();
    let cancelled = false;
    loader.load(glb, (gltf) => {
      if (cancelled) return;
      if (st.root) st.scene.remove(st.root);

      const root = gltf.scene;
      root.traverse((o) => {
        if (o.isMesh) {
          o.userData.baseMaterial = o.material;
          const edges = new THREE.LineSegments(
            new THREE.EdgesGeometry(o.geometry, 25),
            new THREE.LineBasicMaterial({ color: 0x1a1a1a })
          );
          edges.visible = false;
          o.add(edges);
          o.userData.edges = edges;
        }
      });

      // Kameraga sig'dirish uchun bounding box hisoblash.
      const box = new THREE.Box3().setFromObject(root);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const maxDim = Math.max(size.x, size.y, size.z) || 1;
      root.position.sub(center);

      st.scene.add(root);
      st.root = root;

      const dist = maxDim * 1.8;
      st.camera.position.set(dist, dist * 0.7, dist);
      st.camera.near = maxDim / 100;
      st.camera.far = maxDim * 100;
      st.camera.updateProjectionMatrix();
      st.controls.target.set(0, 0, 0);
      st.controls.update();

      applyMode(st, mode);
      setLoading(false);
    });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [glb]);

  useEffect(() => {
    applyMode(stateRef.current, mode);
  }, [mode]);

  const screenshot = () => {
    const { renderer, scene, camera } = stateRef.current;
    if (!renderer) return;
    renderer.render(scene, camera);
    const url = renderer.domElement.toDataURL("image/png");
    const a = document.createElement("a");
    a.href = url;
    a.download = "model-skrinshot.png";
    a.click();
  };

  const copyLink = () => {
    navigator.clipboard?.writeText(window.location.href);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const fullscreen = () => {
    mountRef.current?.requestFullscreen?.();
  };

  return (
    <div style={{ position: "relative", width: "100%", height: "360px", borderRadius: "16px", overflow: "hidden", ...style }}>
      <div ref={mountRef} style={{ width: "100%", height: "100%" }} aria-label={alt} />

      {loading && (
        <div
          className="flex items-center justify-center"
          style={{ position: "absolute", inset: 0, color: "#cfd3e0", fontSize: 13, background: "rgba(17,19,28,0.55)" }}
        >
          Yuklanmoqda…
        </div>
      )}

      <div style={{ position: "absolute", top: 10, right: 10, display: "flex", gap: 6 }}>
        <div style={{ position: "relative" }}>
          <ToolbarButton title="Ko'rinish rejimi" onClick={() => setMenuOpen((v) => !v)}>
            <Layers size={16} />
          </ToolbarButton>
          {menuOpen && (
            <div
              style={{
                position: "absolute",
                top: "calc(100% + 6px)",
                right: 0,
                background: "#1c1e29",
                border: "1px solid #33364a",
                borderRadius: 10,
                padding: 4,
                minWidth: 220,
                boxShadow: "0 8px 24px rgba(0,0,0,0.35)",
                zIndex: 5,
              }}
            >
              {MODES.map((m) => (
                <button
                  key={m.value}
                  onClick={() => {
                    setMode(m.value);
                    setMenuOpen(false);
                  }}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    gap: 8,
                    width: "100%",
                    padding: "8px 10px",
                    background: mode === m.value ? "#2a2d3f" : "transparent",
                    color: "#e7e9f2",
                    border: "none",
                    borderRadius: 6,
                    fontSize: 12.5,
                    textAlign: "left",
                    cursor: "pointer",
                  }}
                >
                  {m.label}
                  {mode === m.value && <Check size={13} />}
                </button>
              ))}
            </div>
          )}
        </div>
        <ToolbarButton title="Skrinshot" onClick={screenshot}>
          <Camera size={16} />
        </ToolbarButton>
        <ToolbarButton title="Havolani nusxalash" onClick={copyLink}>
          {copied ? <Check size={16} /> : <Link2 size={16} />}
        </ToolbarButton>
        <ToolbarButton title="To'liq ekran" onClick={fullscreen}>
          <Maximize size={16} />
        </ToolbarButton>
      </div>
    </div>
  );
}

function ToolbarButton({ children, title, onClick }) {
  return (
    <button
      title={title}
      onClick={onClick}
      style={{
        width: 32,
        height: 32,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "rgba(28,30,41,0.85)",
        color: "#e7e9f2",
        border: "1px solid #33364a",
        borderRadius: 8,
        cursor: "pointer",
      }}
    >
      {children}
    </button>
  );
}

function applyMode(st, mode) {
  if (!st?.root) return;
  st.root.traverse((o) => {
    if (!o.isMesh) return;
    const base = o.userData.baseMaterial;
    const edges = o.userData.edges;
    if (!base || !edges) return;

    switch (mode) {
      case "textured":
        o.visible = true;
        o.material = base;
        base.wireframe = false;
        edges.visible = false;
        break;
      case "textured_lines":
        o.visible = true;
        o.material = base;
        base.wireframe = false;
        edges.material.color.set(0x1a1a1a);
        edges.visible = true;
        break;
      case "wireframe":
        o.visible = true;
        if (!o.userData.wireMaterial) {
          o.userData.wireMaterial = new THREE.MeshBasicMaterial({
            color: 0xd8dbe8,
            wireframe: true,
          });
        }
        o.material = o.userData.wireMaterial;
        edges.visible = false;
        break;
      case "effects":
        o.visible = true;
        o.material = base;
        base.wireframe = false;
        edges.visible = false;
        break;
      case "xray":
        o.visible = true;
        if (!o.userData.xrayMaterial) {
          o.userData.xrayMaterial = new THREE.MeshBasicMaterial({
            color: 0x6fa8ff,
            transparent: true,
            opacity: 0.18,
            side: THREE.DoubleSide,
            depthWrite: false,
          });
        }
        o.material = o.userData.xrayMaterial;
        edges.material.color.set(0x9db8ff);
        edges.visible = true;
        break;
      default:
        break;
    }
  });

  if (st.scene) {
    st.scene.environment = mode === "effects" ? st.envTexture : null;
  }
}
