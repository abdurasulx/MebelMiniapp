import { useEffect, useRef, useState } from "react";
import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { X, Check, Search } from "lucide-react";

/**
 * Mahsulotning 3D modelini (GLB) ko'rsatib, foydalanuvchiga bevosita
 * modelga bosib (yoki yon ro'yxatdan) bitta nomlangan qismni ("oyoq",
 * "orqa_suyanchiq" va h.k.) tanlash imkonini beruvchi modal — tanlangan nom
 * `onSelect(name)` orqali qaytariladi va `BillOfMaterial.part_name`
 * sifatida saqlanadi. GLB'ni backend emas, shu komponent o'zi (three.js
 * orqali) yuklab, node nomlarini o'qiydi — xuddi ModelSceneViewer.jsx'dagi
 * sahna-tuzilmasi paneli kabi, lekin faqat tanlash uchun soddalashtirilgan.
 */
export default function Model3DPartPicker({ glbUrl, onSelect, onClose }) {
  const mountRef = useRef(null);
  const stateRef = useRef({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [parts, setParts] = useState([]);
  const [selected, setSelected] = useState(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x14161f);
    const camera = new THREE.PerspectiveCamera(45, mount.clientWidth / mount.clientHeight, 0.01, 100);
    camera.position.set(2, 1.6, 2.4);

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(mount.clientWidth, mount.clientHeight);
    mount.appendChild(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.target.set(0, 0.8, 0);

    scene.add(new THREE.AmbientLight(0xffffff, 0.9));
    const dirLight = new THREE.DirectionalLight(0xffffff, 1.1);
    dirLight.position.set(3, 5, 4);
    scene.add(dirLight);

    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const originalMaterials = new Map();
    const highlightMaterial = new THREE.MeshStandardMaterial({ color: 0xff7a29, emissive: 0x552200 });

    const highlight = (meshList) => {
      // Avvalgi ta'kidlashni tiklaymiz.
      for (const [mesh, mat] of originalMaterials) mesh.material = mat;
      originalMaterials.clear();
      for (const mesh of meshList) {
        originalMaterials.set(mesh, mesh.material);
        mesh.material = highlightMaterial;
      }
    };

    const findNamedAncestor = (obj) => {
      let cur = obj;
      while (cur && (!cur.name || cur.name.startsWith("Object_") || cur.name === "")) {
        cur = cur.parent;
      }
      return cur;
    };

    const meshesUnderNode = (node) => {
      const list = [];
      node.traverse((c) => {
        if (c.isMesh) list.push(c);
      });
      return list;
    };

    const loader = new GLTFLoader();
    let root = null;
    loader.load(
      glbUrl,
      (gltf) => {
        root = gltf.scene;
        scene.add(root);

        const box = new THREE.Box3().setFromObject(root);
        const size = box.getSize(new THREE.Vector3());
        const center = box.getCenter(new THREE.Vector3());
        const maxDim = Math.max(size.x, size.y, size.z) || 1;
        root.position.sub(center);
        root.position.y += size.y / 2;
        controls.target.set(0, size.y / 2, 0);
        camera.position.set(maxDim * 1.2, maxDim * 1.0, maxDim * 1.4);
        camera.near = maxDim / 100;
        camera.far = maxDim * 20;
        camera.updateProjectionMatrix();

        const namedParts = [];
        root.traverse((c) => {
          if (c.isMesh && c.name && !c.name.startsWith("Object_")) {
            namedParts.push({ name: c.name, node: c });
          }
        });
        setParts(namedParts);
        setLoading(false);
      },
      undefined,
      (err) => {
        setError(err?.message || "3D modelni yuklab bo'lmadi");
        setLoading(false);
      }
    );

    const handleClick = (event) => {
      if (!root) return;
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const hits = raycaster.intersectObjects(root.children, true);
      if (hits.length === 0) return;
      const namedNode = findNamedAncestor(hits[0].object);
      if (namedNode?.name) {
        setSelected(namedNode.name);
        highlight(meshesUnderNode(namedNode));
      }
    };
    renderer.domElement.addEventListener("click", handleClick);

    let frameId;
    const animate = () => {
      frameId = requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    };
    animate();

    const handleResize = () => {
      camera.aspect = mount.clientWidth / mount.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(mount.clientWidth, mount.clientHeight);
    };
    window.addEventListener("resize", handleResize);

    stateRef.current = { highlight, meshesUnderNode, getRoot: () => root };

    return () => {
      cancelAnimationFrame(frameId);
      window.removeEventListener("resize", handleResize);
      renderer.domElement.removeEventListener("click", handleClick);
      renderer.dispose();
      mount.removeChild(renderer.domElement);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [glbUrl]);

  const selectFromList = (name) => {
    setSelected(name);
    const root = stateRef.current.getRoot?.();
    if (!root) return;
    const node = parts.find((p) => p.name === name)?.node;
    if (node) stateRef.current.highlight([node]);
  };

  const filteredParts = parts.filter((p) => p.name.toLowerCase().includes(search.toLowerCase()));

  return (
    <div
      style={{
        position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 1000,
        display: "flex", alignItems: "center", justifyContent: "center", padding: 20,
      }}
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: "min(900px, 100%)", height: "min(600px, 90vh)", background: "#1a1c26",
          borderRadius: 14, display: "flex", overflow: "hidden", boxShadow: "0 20px 60px rgba(0,0,0,0.5)",
        }}
      >
        <div style={{ flex: 1, position: "relative" }}>
          <div ref={mountRef} style={{ width: "100%", height: "100%" }} />
          {loading && (
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", color: "#fff", fontSize: 13 }}>
              Yuklanmoqda…
            </div>
          )}
          {error && (
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", color: "#ff8080", fontSize: 13, padding: 20, textAlign: "center" }}>
              {error}
            </div>
          )}
          <button
            onClick={onClose}
            style={{
              position: "absolute", top: 10, right: 10, background: "rgba(0,0,0,0.5)", border: "none",
              borderRadius: 8, color: "#fff", width: 32, height: 32, display: "flex", alignItems: "center",
              justifyContent: "center", cursor: "pointer",
            }}
          >
            <X size={16} />
          </button>
        </div>
        <div style={{ width: 260, display: "flex", flexDirection: "column", borderLeft: "1px solid rgba(255,255,255,0.08)" }}>
          <div style={{ padding: 12, borderBottom: "1px solid rgba(255,255,255,0.08)" }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: "#fff", marginBottom: 8 }}>Qismni tanlang</div>
            <div style={{ position: "relative" }}>
              <Search size={13} style={{ position: "absolute", left: 8, top: 8, color: "#8a8fa3" }} />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Qidirish…"
                style={{
                  width: "100%", boxSizing: "border-box", padding: "6px 8px 6px 26px", borderRadius: 8,
                  border: "1px solid rgba(255,255,255,0.12)", background: "rgba(255,255,255,0.05)",
                  color: "#fff", fontSize: 12,
                }}
              />
            </div>
          </div>
          <div style={{ flex: 1, overflowY: "auto", padding: 6 }}>
            {parts.length === 0 && !loading && (
              <div style={{ fontSize: 12, color: "#8a8fa3", padding: 10 }}>
                Bu modelda nomlangan qismlar topilmadi.
              </div>
            )}
            {filteredParts.map((p) => (
              <div
                key={p.name}
                onClick={() => selectFromList(p.name)}
                style={{
                  padding: "6px 10px", borderRadius: 8, cursor: "pointer", fontSize: 12,
                  color: selected === p.name ? "#ff7a29" : "#d6d8e0",
                  background: selected === p.name ? "rgba(255,122,41,0.12)" : "transparent",
                }}
              >
                {p.name}
              </div>
            ))}
          </div>
          <div style={{ padding: 12, borderTop: "1px solid rgba(255,255,255,0.08)" }}>
            <button
              disabled={!selected}
              onClick={() => selected && onSelect(selected)}
              style={{
                width: "100%", display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
                padding: "8px 12px", borderRadius: 8, border: "none",
                background: selected ? "#ff7a29" : "rgba(255,255,255,0.08)",
                color: selected ? "#1a1c26" : "#8a8fa3", fontWeight: 700, fontSize: 13,
                cursor: selected ? "pointer" : "not-allowed",
              }}
            >
              <Check size={14} /> Tanlash{selected ? `: ${selected}` : ""}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
