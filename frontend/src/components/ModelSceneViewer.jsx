import { useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";
import { Layers, Camera, Maximize, Link2, Check, ListTree, Search, Eye, EyeOff, ChevronRight, Ruler, Box, DoorOpen, DoorClosed, Play, Pause } from "lucide-react";

// CAD dasturlar (Bazis va shunga o'xshash mebel loyihalash dasturlari) eshik
// ochilish animatsiyasini eksport qila olmaydi — shuning uchun eshik nomi
// bo'yicha avtomatik topib, saytning o'zi interaktiv aylantiradi (haqiqiy
// mebel-konfigurator saytlari — Bazis namoyish sahifalari ham — shu yo'l
// bilan ishlaydi).
const DOOR_NAME_RE = /\b(dver|door|eshik)/i;
const HINGE_NAME_RE = /(petlya|hinge|zawes|scharnir)/i;
const HANDLE_NAME_RE = /(ruchka|handle)/i;
const DOOR_OPEN_ANGLE = Math.PI * 0.6; // ~108 daraja

const MODES = [
  { value: "textured", label: "Teksturada" },
  { value: "textured_lines", label: "Teksturada, chiziqlar bilan" },
  { value: "wireframe", label: "Karkas" },
  { value: "effects", label: "Effektlar (studiya yorug'ligi)" },
  { value: "xray", label: "Rentgen rejimi" },
];

const VIEW_PRESETS = [
  { label: "Old", dir: [0, 0, 1] },
  { label: "Orqa", dir: [0, 0, -1] },
  { label: "Chap", dir: [-1, 0, 0] },
  { label: "O'ng", dir: [1, 0, 0] },
  { label: "Tepa", dir: [0, 1, 0.0001] },
  { label: "Ostki", dir: [0, -1, 0.0001] },
  { label: "Izometrik", dir: [1, 0.55, 1] },
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
  const [viewMenuOpen, setViewMenuOpen] = useState(false);
  const [measuring, setMeasuring] = useState(false);
  const [measureDistance, setMeasureDistance] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [hasDoors, setHasDoors] = useState(false);
  const [doorsOpen, setDoorsOpen] = useState(false);
  const [hasAnimation, setHasAnimation] = useState(false);
  const [playing, setPlaying] = useState(false);

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
    const clock = new THREE.Clock();
    function animate() {
      raf = requestAnimationFrame(animate);
      controls.update();
      // Modelning o'z (GLB'ga eksport qilingan) animatsiyasi — faqat play
      // bosilganda `action.paused=false` bo'ladi, aks holda mixer qotib turadi.
      stateRef.current.mixer?.update(clock.getDelta());
      // `st` obyekti pastda e'lon qilinadi, lekin `animate()` shu yerda
      // darhol (birinchi marta sinxron) chaqiriladi — shuning uchun `st`ni
      // to'g'ridan-to'g'ri yopishtirib bo'lmaydi (TDZ xatosi). `stateRef`
      // esa komponent boshida `useRef({})` bilan allaqachon mavjud.
      const doorPivots = stateRef.current.doorPivots;
      if (doorPivots) {
        for (const pivot of doorPivots) {
          const target = pivot.userData.doorOpen ? pivot.userData.openSign * DOOR_OPEN_ANGLE : 0;
          pivot.rotation.y += (target - pivot.rotation.y) * 0.12;
        }
      }
      renderer.render(scene, camera);
    }
    animate();

    const measureGroup = new THREE.Group();
    scene.add(measureGroup);

    const st = {
      scene, camera, renderer, controls, envTexture, root: null,
      measureGroup, measurePoints: [], measureActive: false, onMeasure: null,
      selectedNode: null, onSelect: null,
    };
    stateRef.current = st;

    // Tanlangan qismni (va uning bola meshlarini) to'q sariq chiziq bilan
    // belgilaydi — bazissoft.ru'dagi kabi. Ham 3D sahnada bosish, ham
    // tuzilma panelidan tanlash shu bir xil funksiyani chaqiradi.
    function selectNode(node) {
      if (st.selectedNode) {
        st.selectedNode.traverse((o) => {
          if (o.userData?.selectOutline) o.userData.selectOutline.visible = false;
        });
      }
      st.selectedNode = node || null;
      if (node) {
        node.traverse((o) => {
          if (o.userData?.selectOutline) o.userData.selectOutline.visible = true;
        });
      }
      st.onSelect?.(node?.uuid ?? null);
    }
    st.selectNode = selectNode;

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    function handleClick(e) {
      if (!st.root) return;
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((e.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const meshes = [];
      st.root.traverse((o) => {
        if (o.isMesh && o.visible) meshes.push(o);
      });
      const hits = raycaster.intersectObjects(meshes, false);

      if (st.measureActive) {
        if (!hits.length) return;
        const point = hits[0].point.clone();

        if (st.measurePoints.length >= 2) {
          st.measurePoints = [];
          st.measureGroup.clear();
          st.onMeasure?.(null);
        }
        st.measurePoints.push(point);
        const dotSize = Math.max(camera.position.distanceTo(controls.target) * 0.012, 0.005);
        const dot = new THREE.Mesh(
          new THREE.SphereGeometry(dotSize, 12, 12),
          new THREE.MeshBasicMaterial({ color: 0xff4d4f, depthTest: false })
        );
        dot.renderOrder = 999;
        dot.position.copy(point);
        st.measureGroup.add(dot);

        if (st.measurePoints.length === 2) {
          const [a, b] = st.measurePoints;
          const line = new THREE.Line(
            new THREE.BufferGeometry().setFromPoints([a, b]),
            new THREE.LineBasicMaterial({ color: 0xff4d4f, depthTest: false })
          );
          line.renderOrder = 999;
          st.measureGroup.add(line);
          st.onMeasure?.(a.distanceTo(b));
        }
        return;
      }

      if (!hits.length) {
        selectNode(null);
        return;
      }
      // Yuqoriga ko'tarilib, root'ning bevosita bolasi bo'lgan eng yaqin
      // ajdodni topamiz — bu tuzilma panelidagi yuqori darajadagi elementga
      // mos keladi (masalan butun tortma bloki, faqat bitta mesh emas).
      let node = hits[0].object;
      while (node.parent && node.parent !== st.root) node = node.parent;
      selectNode(node);
    }
    renderer.domElement.addEventListener("click", handleClick);

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
      renderer.domElement.removeEventListener("click", handleClick);
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
    setSelectedId(null);

    const loader = new GLTFLoader();
    let cancelled = false;
    loader.load(glb, (gltf) => {
      if (cancelled) return;
      if (st.root) st.scene.remove(st.root);
      st.mixer?.stopAllAction();
      st.mixer = null;

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

          const selectOutline = new THREE.LineSegments(
            new THREE.EdgesGeometry(o.geometry, 1),
            new THREE.LineBasicMaterial({ color: 0xff9f1c, depthTest: false, linewidth: 2 })
          );
          selectOutline.visible = false;
          selectOutline.renderOrder = 998;
          selectOutline.userData.__helper = true;
          o.add(selectOutline);
          o.userData.selectOutline = selectOutline;
        }
      });

      st.scene.add(root);
      st.root = root;
      st.selectedNode = null;
      frameObject(st.camera, root, st.controls);

      const doorPivots = setupDoorPivots(root);
      st.doorPivots = doorPivots;
      setHasDoors(doorPivots.length > 0);
      setDoorsOpen(false);

      if (gltf.animations?.length) {
        const mixer = new THREE.AnimationMixer(root);
        st.mixer = mixer;
        st.animActions = gltf.animations.map((clip) => {
          const action = mixer.clipAction(clip);
          action.play();
          action.paused = true;
          return action;
        });
        setHasAnimation(true);
      } else {
        st.animActions = [];
        setHasAnimation(false);
      }
      setPlaying(false);

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

  useEffect(() => {
    const st = stateRef.current;
    st.onMeasure = setMeasureDistance;
    st.onSelect = setSelectedId;
  }, []);

  useEffect(() => {
    const st = stateRef.current;
    st.measureActive = measuring;
    if (!measuring) {
      st.measurePoints = [];
      st.measureGroup?.clear();
      setMeasureDistance(null);
    }
  }, [measuring]);

  const setPresetView = (dir) => {
    const st = stateRef.current;
    if (!st.root) return;
    const box = new THREE.Box3().setFromObject(st.root);
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z) || 1;
    const fovRad = (st.camera.fov * Math.PI) / 180;
    const fitH = maxDim / (2 * Math.tan(fovRad / 2));
    const fitW = fitH / st.camera.aspect;
    const distance = 1.25 * Math.max(fitH, fitW);
    st.camera.position.copy(new THREE.Vector3(...dir).normalize().multiplyScalar(distance));
    st.controls.target.set(0, 0, 0);
    st.controls.update();
    setViewMenuOpen(false);
  };

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

  const toggleDoors = () => {
    const st = stateRef.current;
    if (!st.doorPivots?.length) return;
    const next = !doorsOpen;
    st.doorPivots.forEach((pivot) => {
      pivot.userData.doorOpen = next;
    });
    setDoorsOpen(next);
  };

  const toggleAnimation = () => {
    const st = stateRef.current;
    if (!st.animActions?.length) return;
    const next = !playing;
    st.animActions.forEach((action) => {
      action.paused = !next;
    });
    setPlaying(next);
  };

  const toggleNodeVisible = (node) => {
    node.ref.visible = !node.ref.visible;
    setTick((t) => t + 1);
  };

  const selectFromTree = (node) => {
    stateRef.current.selectNode?.(node.ref);
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
                  onSelect={selectFromTree}
                  selectedId={selectedId}
                />
              ))
            )}
          </div>
        </div>
      )}

      {measuring && (
        <div
          style={{
            position: "absolute",
            top: 10,
            left: "50%",
            transform: "translateX(-50%)",
            background: "rgba(28,30,41,0.92)",
            border: "1px solid #33364a",
            borderRadius: 8,
            padding: "6px 12px",
            color: "#e7e9f2",
            fontSize: 12.5,
            zIndex: 4,
          }}
        >
          {measureDistance != null
            ? `Masofa: ${measureDistance.toFixed(3)} m`
            : "Modelda ikkita nuqtani bosing…"}
        </div>
      )}

      <div style={{ position: "absolute", top: 10, right: 10, display: "flex", gap: 6 }}>
        {hasAnimation && (
          <ToolbarButton
            title={playing ? "Animatsiyani to'xtatish" : "Animatsiyani ijro etish"}
            active={playing}
            onClick={toggleAnimation}
          >
            {playing ? <Pause size={16} /> : <Play size={16} />}
          </ToolbarButton>
        )}
        {hasDoors && (
          <ToolbarButton
            title={doorsOpen ? "Eshiklarni yopish" : "Eshiklarni ochish"}
            active={doorsOpen}
            onClick={toggleDoors}
          >
            {doorsOpen ? <DoorOpen size={16} /> : <DoorClosed size={16} />}
          </ToolbarButton>
        )}
        <ToolbarButton title="Sahna tuzilmasi" active={treeOpen} onClick={() => setTreeOpen((v) => !v)}>
          <ListTree size={16} />
        </ToolbarButton>
        <ToolbarButton title="O'lchash" active={measuring} onClick={() => setMeasuring((v) => !v)}>
          <Ruler size={16} />
        </ToolbarButton>
        <div style={{ position: "relative" }}>
          <ToolbarButton title="Kamera burchagi" active={viewMenuOpen} onClick={() => setViewMenuOpen((v) => !v)}>
            <Box size={16} />
          </ToolbarButton>
          {viewMenuOpen && (
            <div
              style={{
                position: "absolute",
                top: "calc(100% + 6px)",
                right: 0,
                background: "#1c1e29",
                border: "1px solid #33364a",
                borderRadius: 10,
                padding: 4,
                minWidth: 160,
                boxShadow: "0 8px 24px rgba(0,0,0,0.35)",
                zIndex: 5,
              }}
            >
              {VIEW_PRESETS.map((p) => (
                <button
                  key={p.label}
                  onClick={() => setPresetView(p.dir)}
                  style={{
                    display: "block",
                    width: "100%",
                    padding: "8px 10px",
                    background: "transparent",
                    color: "#e7e9f2",
                    border: "none",
                    borderRadius: 6,
                    fontSize: 12.5,
                    textAlign: "left",
                    cursor: "pointer",
                  }}
                >
                  {p.label}
                </button>
              ))}
            </div>
          )}
        </div>
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

function TreeRow({ node, depth, expanded, autoExpand, onToggleExpand, onToggleVisible, onSelect, selectedId }) {
  const hasChildren = node.children.length > 0;
  const isOpen = autoExpand || expanded.has(node.id);
  const visible = node.ref.visible;
  const isSelected = node.id === selectedId;

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
          cursor: "pointer",
          background: isSelected ? "rgba(255,159,28,0.18)" : "transparent",
        }}
        onClick={() => onSelect(node)}
      >
        {hasChildren ? (
          <ChevronRight
            size={12}
            style={{ color: "#8b8fa3", flexShrink: 0, transform: isOpen ? "rotate(90deg)" : "none", transition: "transform 0.12s" }}
            onClick={(e) => {
              e.stopPropagation();
              onToggleExpand(node.id);
            }}
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
            color: isSelected ? "#ff9f1c" : visible ? "#e7e9f2" : "#6b6f82",
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
              onSelect={onSelect}
              selectedId={selectedId}
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

/**
 * Nomi bo'yicha eshik (dver/door/eshik) deb topilgan har bir qism uchun
 * aylanish nuqtasi (pivot) yaratadi — CAD dastur (Bazis va h.k.) eshik
 * ochilishini animatsiya sifatida eksport qila olmagani uchun, saytning
 * o'zi interaktiv ravishda ochib-yopa oladigan qilib beriladi.
 *
 * Har bir eshik uchun: yaqin turgan osma (petlya) qismi topilsa, aylanish
 * o'qi shu osmaning joylashuvidan o'tkaziladi (aniq); topilmasa, eshikning
 * markazdan uzoqroq chetidan taxminiy o'q olinadi (eng yaqin taxmin).
 * `Object3D.attach()` — dunyoviy transformatsiyani saqlagan holda qayta
 * ota-belgilash — eshik vizual jihatdan bir joyda turgan holda, faqat
 * aylanish markazini o'zgartirish imkonini beradi.
 */
function setupDoorPivots(root) {
  root.updateMatrixWorld(true);

  const allMatches = [];
  root.traverse((o) => {
    if (DOOR_NAME_RE.test(o.name)) allMatches.push(o);
  });
  // Ba'zi modellarda "ikki tabaqali eshik" kabi guruh nomi ham "dver" so'zini
  // o'z ichiga oladi va shu bilan birga uning ichidagi har bir haqiqiy eshik
  // barg (leaf) ham alohida moslikka tushadi — natijada bir-birining ichiga
  // joylashgan bir nechta pivot hosil bo'lib, aylanishlar bir-ustiga qo'shilib
  // ketadi (hech qachon to'g'ri yopilmaydi). Shuning uchun faqat boshqa hech
  // qanday moslikni o'z ichiga OLMAYDIGAN (eng ichki, leaf) tugunlar qoldiriladi.
  const isAncestorOf = (possibleAncestor, node) => {
    let p = node.parent;
    while (p) {
      if (p === possibleAncestor) return true;
      p = p.parent;
    }
    return false;
  };
  const doorNodes = allMatches.filter(
    (node) => !allMatches.some((other) => other !== node && isAncestorOf(node, other))
  );

  const pivots = [];
  const box = new THREE.Box3();
  const worldPos = new THREE.Vector3();

  for (const doorNode of doorNodes) {
    const parent = doorNode.parent;
    if (!parent) continue;

    let hingeX = null;
    for (const sibling of parent.children) {
      if (sibling !== doorNode && HINGE_NAME_RE.test(sibling.name)) {
        sibling.getWorldPosition(worldPos);
        hingeX = worldPos.x;
        break;
      }
    }

    box.setFromObject(doorNode);
    if (box.isEmpty()) continue;
    const center = box.getCenter(new THREE.Vector3());
    if (hingeX === null) {
      // Osma topilmadi — eng yaqin taxmin sifatida chap chetni ilashish
      // nuqtasi deb olamiz.
      hingeX = box.min.x;
    }
    const hingeWorldPos = new THREE.Vector3(hingeX, center.y, center.z);

    const pivot = new THREE.Group();
    pivot.name = `${doorNode.name} (ochish o'qi)`;
    pivot.userData.__helper = true; // tuzilma panelida alohida ko'rsatilmasin
    pivot.userData.isDoorPivot = true;
    pivot.userData.doorOpen = false;
    pivot.userData.openSign = hingeX <= center.x ? -1 : 1;

    pivot.position.copy(parent.worldToLocal(hingeWorldPos.clone()));
    parent.add(pivot);
    pivot.attach(doorNode);

    // Eshikka yaqin tutqich (ruchka) bo'lsa, u ham eshik bilan birga
    // aylanishi kerak — aks holda tutqich joyida qolib, eshik undan
    // "chiqib ketgandek" ko'rinadi.
    for (const sibling of [...parent.children]) {
      if (sibling !== pivot && HANDLE_NAME_RE.test(sibling.name)) {
        pivot.attach(sibling);
      }
    }

    pivots.push(pivot);
  }

  return pivots;
}

/** GLTF sahna grafigidan (yordamchi chekka/karkas overlaylarni chetlab)
 * ko'rsatish/yashirish daraxtini quradi. */
function buildTree(root) {
  function walk(node) {
    const result = [];
    for (const c of node.children) {
      if (c.isLight || c.isCamera) continue;
      if (c.userData?.__helper) {
        // Texnik yordamchi tugun (masalan eshik ochish-pivot guruhi yoki
        // chekka chizig'i) — o'zi ro'yxatda ko'rinmaydi, lekin ichidagi
        // haqiqiy qismlar (masalan eshikning o'zi) shu darajada davom etadi.
        result.push(...walk(c));
        continue;
      }
      result.push({ id: c.uuid, name: c.name || "(nomsiz element)", ref: c, children: walk(c) });
    }
    return result;
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
