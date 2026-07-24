import { useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom";
import {
  List, Move3d, RotateCw, Ruler, Trash2, Camera, Link2, Lock, Unlock, Plus, X,
} from "lucide-react";
import { api } from "../api";
import RoomScene from "../components/RoomScene";

/**
 * Xona-loyiha kompozitori — Bazis (viewer.bazissoft.ru) uslubidagi asboblar
 * paneli: elementlar ro'yxati, ko'chirish/aylantirish, o'lchash, skrinshot,
 * ulashish havolasi. To'lov qilinmagan loyihada faqat ko'rish (joylashtirish
 * bloklanadi).
 */
export default function ProjectComposer() {
  const { id } = useParams();
  const [project, setProject] = useState(null);
  const [error, setError] = useState("");
  const [showList, setShowList] = useState(true);
  const [showAddPanel, setShowAddPanel] = useState(false);
  const [transformMode, setTransformMode] = useState("translate");
  const [measureMode, setMeasureMode] = useState(false);
  const [measureResult, setMeasureResult] = useState(null);
  const [selectedId, setSelectedId] = useState(null);
  const [busy, setBusy] = useState(false);
  const sceneRef = useRef(null);

  const load = () => api(`/projects/${id}/`).then(setProject).catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (error) {
    return (
      <div className="mx-auto max-w-md px-4 py-16 text-center">
        <div className="error">{error}</div>
      </div>
    );
  }
  if (!project) {
    return <div className="p-8 text-center" style={{ color: "var(--muted)" }}>Yuklanmoqda…</div>;
  }

  if (!project.is_paid) {
    return <PayGate project={project} onPaid={load} />;
  }

  const handlePickTransform = (mode) => {
    setTransformMode(mode);
    setMeasureMode(false);
    sceneRef.current?.setTransformMode(mode);
    sceneRef.current?.setMeasureMode(false);
  };

  const handleMeasureToggle = () => {
    const next = !measureMode;
    setMeasureMode(next);
    sceneRef.current?.setMeasureMode(next);
    if (!next) setMeasureResult(null);
  };

  const handleTransformChange = async (itemId, transform) => {
    // Optimistik: darhol UI'da yangilaymiz, keyin serverga yozamiz.
    setProject((p) => ({
      ...p,
      items: p.items.map((it) => (it.id === itemId ? { ...it, ...transform } : it)),
    }));
    try {
      await api(`/projects/${id}/items/${itemId}/`, { method: "PATCH", body: transform });
    } catch {
      // jim — keyingi harakatda qayta urinilaveradi
    }
  };

  const deleteSelected = async () => {
    if (!selectedId) return;
    setBusy(true);
    try {
      await api(`/projects/${id}/items/${selectedId}/`, { method: "DELETE" });
      sceneRef.current?.deselect();
      setSelectedId(null);
      await load();
    } finally {
      setBusy(false);
    }
  };

  const takeScreenshot = () => {
    const dataUrl = sceneRef.current?.screenshot();
    if (!dataUrl) return;
    const a = document.createElement("a");
    a.href = dataUrl;
    a.download = `${project.name}.png`;
    a.click();
  };

  const togglePublic = async () => {
    const updated = await api(`/projects/${id}/`, { method: "PATCH", body: { is_public: !project.is_public } });
    setProject(updated);
  };

  const copyShareLink = () => {
    const url = `${window.location.origin}/viewer/project/${project.share_token}`;
    navigator.clipboard?.writeText(url);
  };

  return (
    <div className="relative flex flex-col" style={{ background: "#eef1f5", height: "calc(100vh - 57px)" }}>
      <div className="flex items-center justify-between gap-3 border-b bg-white px-4 py-2" style={{ borderColor: "var(--border)" }}>
        <div className="flex items-center gap-2">
          <button className="btn-ghost !p-2" onClick={() => setShowList((v) => !v)} title="Elementlar ro'yxati">
            <List size={18} />
          </button>
          <span className="font-bold">{project.name}</span>
        </div>
        <div className="flex items-center gap-1">
          <ToolButton active={transformMode === "translate"} onClick={() => handlePickTransform("translate")} icon={Move3d} title="Ko'chirish" />
          <ToolButton active={transformMode === "rotate"} onClick={() => handlePickTransform("rotate")} icon={RotateCw} title="Aylantirish" />
          <ToolButton active={measureMode} onClick={handleMeasureToggle} icon={Ruler} title="O'lchash" />
          <ToolButton onClick={deleteSelected} icon={Trash2} title="O'chirish" disabled={!selectedId || busy} danger />
          <div className="mx-1 h-6 w-px" style={{ background: "var(--border)" }} />
          <ToolButton onClick={takeScreenshot} icon={Camera} title="Skrinshot" />
          <ToolButton onClick={togglePublic} icon={project.is_public ? Unlock : Lock} title={project.is_public ? "Ochiq havola" : "Yopiq havola"} />
          <ToolButton onClick={copyShareLink} icon={Link2} title="Havolani nusxalash" />
        </div>
      </div>

      <div className="relative flex-1">
        <RoomScene
          ref={sceneRef}
          items={project.items}
          editable
          onSelect={setSelectedId}
          onTransformChange={handleTransformChange}
          onMeasure={(d) => setMeasureResult(d)}
        />

        {measureResult != null && (
          <div className="absolute left-1/2 top-4 -translate-x-1/2 rounded-full bg-black/80 px-4 py-1.5 text-sm font-bold text-white">
            {measureResult.toFixed(2)} m
          </div>
        )}

        {showList && (
          <div className="absolute left-3 top-3 max-h-[70%] w-56 overflow-y-auto rounded-xl border bg-white/95 p-2 shadow-lg" style={{ borderColor: "var(--border)" }}>
            {project.items.length === 0 && (
              <p className="p-2 text-xs" style={{ color: "var(--muted)" }}>Hali element yo'q</p>
            )}
            {project.items.map((it) => (
              <button
                key={it.id}
                onClick={() => setSelectedId(it.id)}
                className="block w-full truncate rounded-lg px-2 py-1.5 text-left text-xs"
                style={{
                  background: selectedId === it.id ? "color-mix(in srgb, var(--primary) 25%, transparent)" : "transparent",
                }}
              >
                {it.product_name || "Element"}
              </button>
            ))}
          </div>
        )}

        <button
          onClick={() => setShowAddPanel(true)}
          className="btn btn-brand absolute bottom-5 right-5 !rounded-full !p-3 shadow-lg"
          title="Element qo'shish"
        >
          <Plus size={20} />
        </button>

        {showAddPanel && (
          <AddItemPanel
            projectId={id}
            onClose={() => setShowAddPanel(false)}
            onAdded={async () => {
              setShowAddPanel(false);
              await load();
            }}
          />
        )}
      </div>
    </div>
  );
}

function ToolButton({ icon: Icon, active, onClick, title, disabled, danger }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      title={title}
      className="rounded-lg p-2 transition disabled:opacity-30"
      style={{
        background: active ? "var(--primary)" : "transparent",
        color: danger ? "#e74c3c" : active ? "var(--primary-deep)" : "var(--text)",
      }}
    >
      <Icon size={18} />
    </button>
  );
}

function PayGate({ project, onPaid }) {
  const [busy, setBusy] = useState(false);
  const pay = async () => {
    setBusy(true);
    try {
      await api(`/projects/${project.id}/pay/`, { method: "POST" });
      onPaid();
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="mx-auto flex min-h-[70vh] max-w-md flex-col items-center justify-center gap-4 px-4 text-center">
      <Lock size={40} style={{ color: "var(--muted)" }} />
      <h1 className="text-lg font-bold">"{project.name}" loyihasini joylashtirish</h1>
      <p className="text-sm" style={{ color: "var(--muted)" }}>
        Xonangizni 3D'da joylashtirib ko'rish uchun avval to'lovni amalga oshiring.
      </p>
      <button className="btn btn-brand" onClick={pay} disabled={busy}>
        {busy ? "Yuborilmoqda…" : "To'lovni amalga oshirish"}
      </button>
    </div>
  );
}

function AddItemPanel({ projectId, onClose, onAdded }) {
  const [tab, setTab] = useState("products");
  const [products, setProducts] = useState([]);
  const [details, setDetails] = useState([]);
  const [search, setSearch] = useState("");
  const [busyId, setBusyId] = useState(null);

  useEffect(() => {
    api("/products/").then((p) => setProducts(p.results || [])).catch(() => {});
    api("/detail-assets/").then((p) => setDetails(p.results || [])).catch(() => {});
  }, []);

  const addProduct = async (product) => {
    setBusyId(product.id);
    try {
      await api(`/projects/${projectId}/items/`, {
        method: "POST",
        body: {
          source_type: "product",
          product: product.id,
          variant: product.variants?.[0]?.id,
          position: [0, 0, 0],
        },
      });
      onAdded();
    } finally {
      setBusyId(null);
    }
  };

  const addDetail = async (detail) => {
    setBusyId(detail.id);
    try {
      await api(`/projects/${projectId}/items/`, {
        method: "POST",
        body: { source_type: "detail", detail_asset: detail.id, position: [0, 0, 0] },
      });
      onAdded();
    } finally {
      setBusyId(null);
    }
  };

  const q = search.trim().toLowerCase();
  const filteredProducts = products.filter((p) => p.name_uz.toLowerCase().includes(q));
  const filteredDetails = details.filter((d) => d.name.toLowerCase().includes(q));

  return (
    <div className="absolute inset-y-0 right-0 flex w-80 flex-col border-l bg-white shadow-2xl" style={{ borderColor: "var(--border)" }}>
      <div className="flex items-center justify-between border-b p-3" style={{ borderColor: "var(--border)" }}>
        <span className="font-bold">Element qo'shish</span>
        <button onClick={onClose} className="btn-ghost !p-1.5"><X size={16} /></button>
      </div>
      <div className="flex gap-1 p-2">
        <button
          className="flex-1 rounded-lg py-1.5 text-sm font-semibold"
          style={{ background: tab === "products" ? "var(--primary)" : "var(--bg)" }}
          onClick={() => setTab("products")}
        >
          Mahsulotlar
        </button>
        <button
          className="flex-1 rounded-lg py-1.5 text-sm font-semibold"
          style={{ background: tab === "details" ? "var(--primary)" : "var(--bg)" }}
          onClick={() => setTab("details")}
        >
          Detal elementlar
        </button>
      </div>
      <div className="px-2">
        <input className="input" placeholder="Qidirish…" value={search} onChange={(e) => setSearch(e.target.value)} />
      </div>
      <div className="flex-1 overflow-y-auto p-2">
        {tab === "products"
          ? filteredProducts.map((p) => (
              <button
                key={p.id}
                onClick={() => addProduct(p)}
                disabled={busyId === p.id || !p.model3d?.glb_url}
                className="mb-1 flex w-full items-center justify-between rounded-lg px-2 py-2 text-left text-sm hover:bg-black/5 disabled:opacity-40"
              >
                <span className="truncate">{p.name_uz}</span>
                {!p.model3d?.glb_url && <span className="text-[10px]" style={{ color: "var(--muted)" }}>3D yo'q</span>}
              </button>
            ))
          : filteredDetails.map((d) => (
              <button
                key={d.id}
                onClick={() => addDetail(d)}
                disabled={busyId === d.id}
                className="mb-1 flex w-full items-center justify-between rounded-lg px-2 py-2 text-left text-sm hover:bg-black/5 disabled:opacity-40"
              >
                <span className="truncate">{d.name}</span>
                <span className="text-[10px]" style={{ color: "var(--muted)" }}>{d.category_display}</span>
              </button>
            ))}
      </div>
    </div>
  );
}
