import { useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { Layers, Camera, Maximize, Link2, Check, ListTree, Search, Eye, EyeOff, ChevronRight } from "lucide-react";

const MODES = [
  { value: "textured", label: "Teksturada" },
  { value: "textured_lines", label: "Teksturada, chiziqlar bilan" },
  { value: "wireframe", label: "Karkas" },
  { value: "effects", label: "Effektlar (studiya yorug'ligi)" },
  { value: "xray", label: "Rentgen rejimi" },
];

const BG_DEFAULT = 0x11131c;
const BG_WIREFRAME = 0xeef0f5;

/**
 * Bazissoft.ru uslubidagi to'liq Three.js model ko'rsatgichi — bitta GLB'ni
 * yuklab, kamera bilan aylantirib ko'rish + render rejimlari (tekstura,
 * tekstura+chiziq, karkas, effekt, rentgen) va sahna tuzilmasi (har bir qism
 * uchun ko'rsatish/yashirish) o'rtasida almashtirish imkonini beradi.
 * `<model-viewer>` bunday material-darajadagi rejimlarni bermaydi, shuning
 * uchun bu yerda xom Three.js sahnasi ishlatiladi.
 */
export default function ModelSceneViewer({ glb, alt = "3D model", style }) {
  const mountRef = useRef(null);
  const stateRef = useRef({});
  const [mode, setMode] = useState("textured_lines");
  const [menuOpen, setMenuOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [loading, setLoading] = useState(true);
  const [treeOpen, setTreeOpen] = useState(false);
  const [tree, setTree] = useState([]);
  const [search, setSearch] = useState("");
  const [expanded, setExpanded] = useState(() => new Set());
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(BG_DEFAULT);

    // Boshlang'ich aspekt sifatida xavfsiz standart qiymat ishlatiladi —
    // `mount.clientWidth/clientHeight` effekt ishga tushgan paytda hali
    // layout tugallanmagan bo'lishi mumkin (0/0 = NaN), bu esa proyeksiya
    // matritsasini butunlay buzib, sahnani ko'rinmas qilib qo'yardi.
    // ResizeObserver haqiqiy o'lcham ma'lum bo'lishi bilanoq tuzatadi.
    const camera = new THREE.PerspectiveCamera(45, 16 / 9, 0.01, 1000);
    camera.position.set(2, 1.6, 2.6);

    const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
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
    controls.minDistance = 0.05;
    controls.maxDistance = 100;

    const pmremGenerator = new THREE.PMREMGenerator(renderer);
    const envTexture = pmremGenerator.fromScene(new RoomEnvironment(), 0.04).texture;

    let raf;
    function animate() {
      raf = requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    const st = { scene, camera, renderer, controls, envTexture, root: null };
    stateRef.current = st;

    const resizeObserver = new ResizeObserver((entries) => {
      const { width, height } = entries[0].contentRect;
      if (!width || !height) return;
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
      if (st.root) frameObject(camera, st.root, controls);
    });
    resizeObserver.observe(mount);

    return () => {
      cancelAnimationFrame(raf);
      resizeObserver.disconnect();
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
    setTreeOpen(false);
    setSearch("");
    setExpanded(new Set());

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
            new THREE.EdgesGeometry(o.geometry, 1),
            new THREE.LineBasicMaterial({ color: 0x1a1a1a })
          );
          edges.visible = false;
          edges.userData.__helper = true;
          o.add(edges);
          o.userData.edges = edges;
        }
      });

      st.scene.add(root);
      st.root = root;
      frameObject(st.camera, root, st.controls);

      applyMode(st, mode);
      setTree(buildTree(root));
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

  const toggleNodeVisible = (node) => {
    node.ref.visible = !node.ref.visible;
    setTick((t) => t + 1);
  };

  const toggleExpanded = (id) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const filteredTree = useMemo(() => filterTree(tree, search.trim().toLowerCase()), [tree, search]);
  const autoExpand = search.trim().length > 0;

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

      {treeOpen && (
        <div
          style={{
            position: "absolute",
            top: 10,
            left: 10,
            bottom: 10,
            width: 240,
            background: "rgba(28,30,41,0.92)",
            border: "1px solid #33364a",
            borderRadius: 10,
            display: "flex",
            flexDirection: "column",
            overflow: "hidden",
            zIndex: 4,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 6, padding: 8, borderBottom: "1px solid #33364a" }}>
            <Search size={13} style={{ color: "#8b8fa3", flexShrink: 0 }} />
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Qidirish…"
              style={{
                flex: 1,
                minWidth: 0,
                background: "transparent",
                border: "none",
                outline: "none",
                color: "#e7e9f2",
                fontSize: 12.5,
              }}
            />
          </div>
          <div style={{ flex: 1, overflowY: "auto", padding: 4 }}>
            {filteredTree.length === 0 ? (
              <p style={{ color: "#8b8fa3", fontSize: 12, padding: 8 }}>Elementlar topilmadi.</p>
            ) : (
              filteredTree.map((n) => (
                <TreeRow
                  key={n.id}
                  node={n}
                  depth={0}
                  expanded={expanded}
                  autoExpand={autoExpand}
                  onToggleExpand={toggleExpanded}
                  onToggleVisible={toggleNodeVisible}
                />
              ))
            )}
          </div>
        </div>
      )}

      <div style={{ position: "absolute", top: 10, right: 10, display: "flex", gap: 6 }}>
        <ToolbarButton title="Sahna tuzilmasi" active={treeOpen} onClick={() => setTreeOpen((v) => !v)}>
          <ListTree size={16} />
        </ToolbarButton>
        <div style={{ position: "relative" }}>
          <ToolbarButton title="Ko'rinish rejimi" active={menuOpen} onClick={() => setMenuOpen((v) => !v)}>
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

function TreeRow({ node, depth, expanded, autoExpand, onToggleExpand, onToggleVisible }) {
  const hasChildren = node.children.length > 0;
  const isOpen = autoExpand || expanded.has(node.id);
  const visible = node.ref.visible;

  return (
    <div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 4,
          padding: "5px 6px",
          paddingLeft: 6 + depth * 14,
          borderRadius: 6,
          cursor: hasChildren ? "pointer" : "default",
        }}
        onClick={() => hasChildren && onToggleExpand(node.id)}
      >
        {hasChildren ? (
          <ChevronRight
            size={12}
            style={{ color: "#8b8fa3", flexShrink: 0, transform: isOpen ? "rotate(90deg)" : "none", transition: "transform 0.12s" }}
          />
        ) : (
          <span style={{ width: 12, flexShrink: 0 }} />
        )}
        <span
          style={{
            flex: 1,
            minWidth: 0,
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
            fontSize: 12,
            color: visible ? "#e7e9f2" : "#6b6f82",
          }}
          title={node.name}
        >
          {node.name}
        </span>
        <button
          onClick={(e) => {
            e.stopPropagation();
            onToggleVisible(node);
          }}
          title={visible ? "Yashirish" : "Ko'rsatish"}
          style={{
            background: "transparent",
            border: "none",
            color: visible ? "#e7e9f2" : "#6b6f82",
            padding: 3,
            display: "flex",
            cursor: "pointer",
            flexShrink: 0,
          }}
        >
          {visible ? <Eye size={13} /> : <EyeOff size={13} />}
        </button>
      </div>
      {hasChildren && isOpen && (
        <div>
          {node.children.map((c) => (
            <TreeRow
              key={c.id}
              node={c}
              depth={depth + 1}
              expanded={expanded}
              autoExpand={autoExpand}
              onToggleExpand={onToggleExpand}
              onToggleVisible={onToggleVisible}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function ToolbarButton({ children, title, onClick, active }) {
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
        background: active ? "#33364a" : "rgba(28,30,41,0.85)",
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

/** Kamerani obyektga FOV asosida aniq sig'diradi — konstant masofa o'rniga
 * haqiqiy proyeksiya geometriyasidan foydalanadi, shu bilan har xil o'lchamdagi
 * modellar ekranni bir xil zichlikda to'ldiradi ("juda kichik" muammosi). */
function frameObject(camera, object, controls, marginFactor = 1.25) {
  const box = new THREE.Box3().setFromObject(object);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const maxDim = Math.max(size.x, size.y, size.z) || 1;
  object.position.sub(center);

  const fovRad = (camera.fov * Math.PI) / 180;
  const fitHeightDistance = maxDim / (2 * Math.tan(fovRad / 2));
  const fitWidthDistance = fitHeightDistance / camera.aspect;
  const distance = marginFactor * Math.max(fitHeightDistance, fitWidthDistance);

  const direction = new THREE.Vector3(1, 0.55, 1).normalize();
  camera.position.copy(direction.multiplyScalar(distance));
  camera.near = distance / 100;
  camera.far = distance * 100;
  camera.updateProjectionMatrix();
  controls.target.set(0, 0, 0);
  controls.update();
}

/** GLTF sahna grafigidan (yordamchi chekka/karkas overlaylarni chetlab)
 * ko'rsatish/yashirish daraxtini quradi. */
function buildTree(root) {
  function walk(node) {
    return node.children
      .filter((c) => !c.userData?.__helper && !c.isLight && !c.isCamera)
      .map((c) => ({
        id: c.uuid,
        name: c.name || "(nomsiz element)",
        ref: c,
        children: walk(c),
      }));
  }
  return walk(root);
}

function filterTree(nodes, query) {
  if (!query) return nodes;
  const result = [];
  for (const n of nodes) {
    const children = filterTree(n.children, query);
    if (n.name.toLowerCase().includes(query) || children.length > 0) {
      result.push({ ...n, children });
    }
  }
  return result;
}

function applyMode(st, mode) {
  if (!st?.root) return;
  st.root.traverse((o) => {
    if (!o.isMesh) return;
    const base = o.userData.baseMaterial;
    const edges = o.userData.edges;
    if (!base || !edges) return;

    if (!o.userData.hiddenMaterial) {
      o.userData.hiddenMaterial = new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false });
    }

    switch (mode) {
      case "textured":
        o.visible = true;
        o.material = base;
        edges.visible = false;
        break;
      case "textured_lines":
        o.visible = true;
        o.material = base;
        edges.material.color.set(0x1a1a1a);
        edges.visible = true;
        break;
      case "wireframe":
        // Meshni to'liq `visible=false` qilib bo'lmaydi — Three.js render
        // paytida ota-obyekt ko'rinmas bo'lsa, uning bola (child)
        // elementlarini ham render qilmaydi, shu bilan chekka chiziqlar
        // (edges, bu meshning bolasi) ham yo'qolib qolardi. Shuning uchun
        // shaffof material qo'llaniladi — mesh ko'rinmas, lekin chekka
        // chiziqlar bola sifatida hali ham chiziladi.
        o.visible = true;
        o.material = o.userData.hiddenMaterial;
        edges.material.color.set(0x101010);
        edges.visible = true;
        break;
      case "effects":
        o.visible = true;
        o.material = base;
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
    st.scene.background = new THREE.Color(mode === "wireframe" ? BG_WIREFRAME : BG_DEFAULT);
    st.scene.environment = mode === "effects" ? st.envTexture : null;
  }
}
