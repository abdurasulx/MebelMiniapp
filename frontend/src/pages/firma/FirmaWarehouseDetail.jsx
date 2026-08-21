import { Fragment, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Hammer, Plus, Pencil, Trash2 } from "lucide-react";
import { api } from "../../api";

const UNIT_OPTIONS = [
  ["dona", "Dona"], ["kg", "Kilogramm"], ["m", "Metr"],
  ["m2", "Kvadrat metr"], ["m3", "Kub metr"], ["litr", "Litr"],
];

const DIMENSION_OPTIONS = [
  ["none", "Oddiy (o'lchamsiz)"],
  ["linear", "Chiziqli — reyka (uzunlik bo'yicha kesiladi)"],
  ["sheet", "Varaq — fanera/DVP (eni x bo'yi bo'yicha kesiladi)"],
];

export default function FirmaWarehouseDetail() {
  const { id } = useParams();
  const [warehouse, setWarehouse] = useState(null);
  const [error, setError] = useState("");

  const load = () =>
    api(`/warehouses/${id}/`)
      .then(setWarehouse)
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (error) return <div className="error">{error}</div>;
  if (!warehouse) return <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>;

  return (
    <div className="flex flex-col gap-4">
      <Link to="/warehouses" className="btn-ghost inline-flex w-fit items-center gap-1.5 !px-3 !py-1.5 text-sm">
        <ArrowLeft size={15} /> Omborlar
      </Link>
      <div className="flex items-center gap-2">
        <h1 className="text-xl font-bold">{warehouse.name}</h1>
        <span className="badge badge-brand">{warehouse.kind_display}</span>
      </div>
      {warehouse.address && <p className="text-sm" style={{ color: "var(--muted)" }}>{warehouse.address}</p>}

      {warehouse.kind === "raw_material" ? (
        <MaterialWarehousePanel warehouseId={warehouse.id} />
      ) : (
        <ProductWarehousePanel warehouseId={warehouse.id} />
      )}
    </div>
  );
}

function MaterialWarehousePanel({ warehouseId }) {
  const [stocks, setStocks] = useState([]);
  const [movements, setMovements] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [error, setError] = useState("");
  const [showMove, setShowMove] = useState(false);
  const [showNewMaterial, setShowNewMaterial] = useState(false);
  const [move, setMove] = useState({ material: "", movement_type: "in", quantity: "", note: "" });
  const [newMaterial, setNewMaterial] = useState({
    name: "", unit: "dona", unit_cost: "", dimension_type: "none", stock_unit_length: "",
  });
  const [remnants, setRemnants] = useState([]);
  const [busy, setBusy] = useState(false);
  const [editingMaterial, setEditingMaterial] = useState(null);
  const [showReceiveSheet, setShowReceiveSheet] = useState(false);
  const [receiveSheet, setReceiveSheet] = useState({ material: "", length: "", width: "", quantity: "1" });
  const [receiveError, setReceiveError] = useState("");
  const [receiveBusy, setReceiveBusy] = useState(false);

  const sheetMaterials = materials.filter((m) => m.dimension_type === "sheet");

  const load = () =>
    Promise.all([
      api(`/warehouses/${warehouseId}/material-stocks/`),
      api(`/warehouses/${warehouseId}/material-movements/`),
      api("/materials/"),
      api(`/warehouses/${warehouseId}/material-remnants/`),
    ])
      .then(([s, m, mat, r]) => {
        setStocks(s.results || []);
        setMovements(m.results || []);
        setMaterials(mat.results || []);
        setRemnants(r.results || []);
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [warehouseId]);

  const createMaterial = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const created = await api("/materials/", {
        method: "POST",
        body: {
          ...newMaterial,
          stock_unit_length: newMaterial.dimension_type === "linear" ? (newMaterial.stock_unit_length || null) : null,
        },
      });
      setNewMaterial({ name: "", unit: "dona", unit_cost: "", dimension_type: "none", stock_unit_length: "" });
      setShowNewMaterial(false);
      setMove((m) => ({ ...m, material: created.id }));
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const submitMove = async (e) => {
    e.preventDefault();
    setError("");
    if (!move.material) {
      setError("Materialni tanlang");
      return;
    }
    setBusy(true);
    try {
      await api(`/warehouses/${warehouseId}/material-movements/`, {
        method: "POST",
        body: { ...move, quantity: move.quantity || 0 },
      });
      setMove({ material: "", movement_type: "in", quantity: "", note: "" });
      setShowMove(false);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const submitReceiveSheet = async (e) => {
    e.preventDefault();
    setReceiveError("");
    if (!receiveSheet.material) {
      setReceiveError("Materialni tanlang");
      return;
    }
    setReceiveBusy(true);
    try {
      await api(`/warehouses/${warehouseId}/material-remnants/receive/`, {
        method: "POST",
        body: { ...receiveSheet, width: receiveSheet.width || null },
      });
      setReceiveSheet({ material: "", length: "", width: "", quantity: "1" });
      setShowReceiveSheet(false);
      load();
    } catch (err) {
      setReceiveError(err.message);
    } finally {
      setReceiveBusy(false);
    }
  };

  const removeMaterial = async (m) => {
    if (!confirm(`"${m.name}" materiali o'chirilsinmi?`)) return;
    try {
      await api(`/materials/${m.id}/`, { method: "DELETE" });
      load();
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="card flex flex-col gap-3 p-5">
        <h2 className="text-base font-semibold">Materiallar</h2>
        {materials.length === 0 ? (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali material yaratilmagan.</p>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Nomi</th>
                  <th>Birligi</th>
                  <th>Birlik narxi</th>
                  <th className="text-right">Amal</th>
                </tr>
              </thead>
              <tbody>
                {materials.map((m) => (
                  <Fragment key={m.id}>
                    <tr>
                      <td className="font-medium">{m.name}</td>
                      <td>{m.unit_display}</td>
                      <td>{Number(m.unit_cost).toLocaleString()} so'm</td>
                      <td className="text-right">
                        <div className="flex justify-end gap-2">
                          <button
                            className="btn-ghost !px-2 !py-1.5"
                            title="Tahrirlash"
                            onClick={() => setEditingMaterial(editingMaterial === m.id ? null : m.id)}
                          >
                            <Pencil size={13} />
                          </button>
                          <button
                            className="btn-ghost !px-2 !py-1.5"
                            title="O'chirish"
                            style={{ color: "#e74c3c" }}
                            onClick={() => removeMaterial(m)}
                          >
                            <Trash2 size={13} />
                          </button>
                        </div>
                      </td>
                    </tr>
                    {editingMaterial === m.id && (
                      <tr>
                        <td colSpan={4}>
                          <MaterialEditForm
                            material={m}
                            onClose={() => setEditingMaterial(null)}
                            onSaved={() => {
                              setEditingMaterial(null);
                              load();
                            }}
                          />
                        </td>
                      </tr>
                    )}
                  </Fragment>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="card flex flex-col gap-3 p-5">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold">Qoldiqlar</h2>
          <button className="btn !px-3 !py-1.5 text-xs" onClick={() => setShowMove((v) => !v)}>
            <Plus size={13} className="inline" /> Kirim / Chiqim
          </button>
        </div>

        {showMove && (
          <form className="flex flex-col gap-3 rounded-xl p-4" style={{ border: "1px dashed var(--border)" }} onSubmit={submitMove}>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="label">Material</label>
                <div className="flex gap-2">
                  <select className="input" value={move.material} onChange={(e) => setMove({ ...move, material: e.target.value })}>
                    <option value="">Tanlang…</option>
                    {materials.map((m) => (
                      <option key={m.id} value={m.id}>{m.name} ({m.unit_display})</option>
                    ))}
                  </select>
                  <button type="button" className="btn-ghost !px-3 !py-1.5 text-xs" onClick={() => setShowNewMaterial((v) => !v)}>
                    + Yangi
                  </button>
                </div>
              </div>
              <div>
                <label className="label">Turi</label>
                <select className="input" value={move.movement_type} onChange={(e) => setMove({ ...move, movement_type: e.target.value })}>
                  <option value="in">Kirim</option>
                  <option value="out">Chiqim</option>
                </select>
              </div>
              <div>
                <label className="label">Miqdor</label>
                <input className="input" type="number" step="0.001" min="0" value={move.quantity}
                  onChange={(e) => setMove({ ...move, quantity: e.target.value })} required />
              </div>
              <div>
                <label className="label">Izoh (ixtiyoriy)</label>
                <input className="input" value={move.note} onChange={(e) => setMove({ ...move, note: e.target.value })} />
              </div>
            </div>

            {showNewMaterial && (
              <div className="flex flex-wrap items-end gap-3 rounded-lg p-3" style={{ background: "var(--bg)" }}>
                <div>
                  <label className="label">Yangi material nomi</label>
                  <input className="input" value={newMaterial.name} onChange={(e) => setNewMaterial({ ...newMaterial, name: e.target.value })} />
                </div>
                <div>
                  <label className="label">O'lchov birligi</label>
                  <select className="input" value={newMaterial.unit} onChange={(e) => setNewMaterial({ ...newMaterial, unit: e.target.value })}>
                    <option value="dona">Dona</option>
                    <option value="kg">Kilogramm</option>
                    <option value="m">Metr</option>
                    <option value="m2">Kvadrat metr</option>
                    <option value="m3">Kub metr</option>
                    <option value="litr">Litr</option>
                  </select>
                </div>
                <div>
                  <label className="label">Birlik narxi (so'm)</label>
                  <input className="input" type="number" min="0" value={newMaterial.unit_cost}
                    onChange={(e) => setNewMaterial({ ...newMaterial, unit_cost: e.target.value })} />
                </div>
                <div>
                  <label className="label">Turi</label>
                  <select className="input" value={newMaterial.dimension_type}
                    onChange={(e) => setNewMaterial({ ...newMaterial, dimension_type: e.target.value })}>
                    {DIMENSION_OPTIONS.map(([v, label]) => <option key={v} value={v}>{label}</option>)}
                  </select>
                </div>
                {newMaterial.dimension_type === "linear" && (
                  <div>
                    <label className="label">Yaxlit birlik uzunligi (m)</label>
                    <input className="input" type="number" step="0.001" min="0" placeholder="masalan 1.0"
                      value={newMaterial.stock_unit_length}
                      onChange={(e) => setNewMaterial({ ...newMaterial, stock_unit_length: e.target.value })} />
                    <p className="text-xs" style={{ color: "var(--muted)" }}>
                      Belgilansa, ishlab chiqarishda kesish-qoldiq (offcut) tizimi ishlaydi.
                    </p>
                  </div>
                )}
                {newMaterial.dimension_type === "sheet" && (
                  <p className="text-xs" style={{ color: "var(--muted)" }}>
                    Standart o'lcham yo'q — har bir partiya "Qoldiqlar" bo'limidagi "Varaq kirim
                    qilish" orqali o'z eni/bo'yi bilan kiritiladi.
                  </p>
                )}
                <button className="btn !px-3 !py-1.5 text-xs" type="button" onClick={createMaterial} disabled={busy || !newMaterial.name}>
                  Qo'shish
                </button>
              </div>
            )}

            {error && <div className="error">{error}</div>}
            <div className="flex gap-2">
              <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
                {busy ? "Saqlanmoqda…" : "Saqlash"}
              </button>
              <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setShowMove(false)}>Bekor</button>
            </div>
          </form>
        )}

        {!showMove && error && <div className="error">{error}</div>}

        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Material</th>
                <th>Birligi</th>
                <th>Qoldiq</th>
                <th>Birlik narxi</th>
                <th>Jami qiymat</th>
              </tr>
            </thead>
            <tbody>
              {stocks.map((s) => (
                <tr key={s.id}>
                  <td className="font-medium">{s.material_name}</td>
                  <td>{s.material_unit}</td>
                  <td>{Number(s.quantity).toLocaleString()}</td>
                  <td>{Number(s.material_unit_cost).toLocaleString()} so'm</td>
                  <td>{(Number(s.quantity) * Number(s.material_unit_cost)).toLocaleString()} so'm</td>
                </tr>
              ))}
              {stocks.length === 0 && (
                <tr><td colSpan={5} style={{ color: "var(--muted)" }}>Hali qoldiq yo'q.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="card flex flex-col gap-3 p-5">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold">Qoldiqlar (offcut) va varaqlar</h2>
          {sheetMaterials.length > 0 && (
            <button className="btn !px-3 !py-1.5 text-xs" onClick={() => setShowReceiveSheet((v) => !v)}>
              <Plus size={13} className="inline" /> Varaq kirim qilish
            </button>
          )}
        </div>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          Kesishdan qolgan qayta ishlatsa bo'ladigan bo'laklar (chiziqli materiallar) — ishlab
          chiqarishda avval shulardan foydalaniladi, keyin yangi yaxlit birlikdan kesiladi. Varaq
          materiallar (fanera/DVP) esa har bir kirim partiyasi o'z eni/bo'yi bilan bevosita shu yerga
          kiritiladi (standart o'lchami yo'q).
        </p>

        {showReceiveSheet && (
          <form className="flex flex-wrap items-end gap-3 rounded-xl p-4" style={{ border: "1px dashed var(--border)" }} onSubmit={submitReceiveSheet}>
            <div>
              <label className="label">Material</label>
              <select className="input" value={receiveSheet.material}
                onChange={(e) => setReceiveSheet({ ...receiveSheet, material: e.target.value })}>
                <option value="">Tanlang…</option>
                {sheetMaterials.map((m) => (
                  <option key={m.id} value={m.id}>{m.name} ({m.unit_display})</option>
                ))}
              </select>
            </div>
            <div>
              <label className="label">Eni (m)</label>
              <input className="input" type="number" step="0.001" min="0" value={receiveSheet.width}
                onChange={(e) => setReceiveSheet({ ...receiveSheet, width: e.target.value })} required />
            </div>
            <div>
              <label className="label">Bo'yi (m)</label>
              <input className="input" type="number" step="0.001" min="0" value={receiveSheet.length}
                onChange={(e) => setReceiveSheet({ ...receiveSheet, length: e.target.value })} required />
            </div>
            <div>
              <label className="label">Soni</label>
              <input className="input" type="number" min="1" value={receiveSheet.quantity}
                onChange={(e) => setReceiveSheet({ ...receiveSheet, quantity: e.target.value })} required />
            </div>
            {receiveError && <div className="error">{receiveError}</div>}
            <div className="flex gap-2">
              <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={receiveBusy}>
                {receiveBusy ? "Saqlanmoqda…" : "Kirim qilish"}
              </button>
              <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setShowReceiveSheet(false)}>Bekor</button>
            </div>
          </form>
        )}

        {remnants.length > 0 && (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Material</th>
                  <th>Eni</th>
                  <th>Bo'yi</th>
                  <th>Soni</th>
                </tr>
              </thead>
              <tbody>
                {remnants.map((r) => (
                  <tr key={r.id}>
                    <td className="font-medium">{r.material_name}</td>
                    <td>{r.width != null ? `${Number(r.width).toLocaleString()} ${r.material_unit}` : "—"}</td>
                    <td>{Number(r.length).toLocaleString()} {r.material_unit}</td>
                    <td>{r.quantity}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        {remnants.length === 0 && !showReceiveSheet && (
          <p className="text-sm" style={{ color: "var(--muted)" }}>Hali qoldiq/varaq yo'q.</p>
        )}
      </div>

      <MovementHistory movements={movements} qtyLabel="material_name" />
    </div>
  );
}

function MaterialEditForm({ material, onClose, onSaved }) {
  const [form, setForm] = useState({
    name: material.name,
    unit: material.unit,
    unit_cost: material.unit_cost,
    dimension_type: material.dimension_type || "none",
    stock_unit_length: material.stock_unit_length || "",
  });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      await api(`/materials/${material.id}/`, {
        method: "PATCH",
        body: { ...form, stock_unit_length: form.dimension_type === "linear" ? (form.stock_unit_length || null) : null },
      });
      onSaved();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <form
      className="flex flex-wrap items-end gap-3 rounded-xl p-4"
      style={{ border: "1px dashed var(--border)" }}
      onSubmit={submit}
    >
      <div style={{ minWidth: 160 }}>
        <label className="label">Nomi</label>
        <input className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
      </div>
      <div>
        <label className="label">O'lchov birligi</label>
        <select className="input" value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })}>
          {UNIT_OPTIONS.map(([v, label]) => <option key={v} value={v}>{label}</option>)}
        </select>
      </div>
      <div>
        <label className="label">Birlik narxi (so'm)</label>
        <input className="input" type="number" min="0" value={form.unit_cost}
          onChange={(e) => setForm({ ...form, unit_cost: e.target.value })} />
      </div>
      <div>
        <label className="label">Turi</label>
        <select className="input" value={form.dimension_type}
          onChange={(e) => setForm({ ...form, dimension_type: e.target.value })}>
          {DIMENSION_OPTIONS.map(([v, label]) => <option key={v} value={v}>{label}</option>)}
        </select>
      </div>
      {form.dimension_type === "linear" && (
        <div>
          <label className="label">Yaxlit birlik uzunligi (m)</label>
          <input className="input" type="number" step="0.001" min="0" value={form.stock_unit_length}
            onChange={(e) => setForm({ ...form, stock_unit_length: e.target.value })} />
        </div>
      )}
      {error && <div className="error">{error}</div>}
      <div className="flex gap-2">
        <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>{busy ? "Saqlanmoqda…" : "Saqlash"}</button>
        <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={onClose}>Bekor</button>
      </div>
    </form>
  );
}

function ProductWarehousePanel({ warehouseId }) {
  const [stocks, setStocks] = useState([]);
  const [movements, setMovements] = useState([]);
  const [products, setProducts] = useState([]);
  const [rawWarehouses, setRawWarehouses] = useState([]);
  const [error, setError] = useState("");
  const [showMove, setShowMove] = useState(false);
  const [move, setMove] = useState({ product: "", variant: "", movement_type: "in", quantity: "", note: "" });
  const [busy, setBusy] = useState(false);

  const load = () =>
    Promise.all([
      api(`/warehouses/${warehouseId}/product-stocks/`),
      api(`/warehouses/${warehouseId}/product-movements/`),
      api("/products/"),
      api("/warehouses/"),
    ])
      .then(([s, m, p, wh]) => {
        setStocks(s.results || []);
        setMovements(m.results || []);
        setProducts(p.results || []);
        setRawWarehouses((wh.results || []).filter((w) => w.kind === "raw_material"));
      })
      .catch((e) => setError(e.message));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [warehouseId]);

  const selectedProduct = products.find((p) => p.id === move.product);

  const submitMove = async (e) => {
    e.preventDefault();
    setError("");
    if (!move.product) {
      setError("Mahsulotni tanlang");
      return;
    }
    setBusy(true);
    try {
      await api(`/warehouses/${warehouseId}/product-movements/`, {
        method: "POST",
        body: { ...move, variant: move.variant || null, quantity: move.quantity || 0 },
      });
      setMove({ product: "", variant: "", movement_type: "in", quantity: "", note: "" });
      setShowMove(false);
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <ProduceForm warehouseId={warehouseId} products={products} rawWarehouses={rawWarehouses} onDone={load} />

      <div className="card flex flex-col gap-3 p-5">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-semibold">Qoldiqlar</h2>
          <button className="btn !px-3 !py-1.5 text-xs" onClick={() => setShowMove((v) => !v)}>
            <Plus size={13} className="inline" /> Kirim / Chiqim
          </button>
        </div>

        {showMove && (
          <form className="flex flex-col gap-3 rounded-xl p-4" style={{ border: "1px dashed var(--border)" }} onSubmit={submitMove}>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="label">Mahsulot</label>
                <select className="input" value={move.product} onChange={(e) => setMove({ ...move, product: e.target.value, variant: "" })}>
                  <option value="">Tanlang…</option>
                  {products.map((p) => (
                    <option key={p.id} value={p.id}>{p.name_uz}</option>
                  ))}
                </select>
              </div>
              {selectedProduct?.variants?.length > 0 && (
                <div>
                  <label className="label">Variant (ixtiyoriy)</label>
                  <select className="input" value={move.variant} onChange={(e) => setMove({ ...move, variant: e.target.value })}>
                    <option value="">Barcha variantlar uchun umumiy</option>
                    {selectedProduct.variants.map((v) => (
                      <option key={v.id} value={v.id}>{v.name}</option>
                    ))}
                  </select>
                </div>
              )}
              <div>
                <label className="label">Turi</label>
                <select className="input" value={move.movement_type} onChange={(e) => setMove({ ...move, movement_type: e.target.value })}>
                  <option value="in">Kirim</option>
                  <option value="out">Chiqim</option>
                </select>
              </div>
              <div>
                <label className="label">Miqdor (dona)</label>
                <input className="input" type="number" step="1" min="0" value={move.quantity}
                  onChange={(e) => setMove({ ...move, quantity: e.target.value })} required />
              </div>
              <div className="sm:col-span-2">
                <label className="label">Izoh (ixtiyoriy)</label>
                <input className="input" value={move.note} onChange={(e) => setMove({ ...move, note: e.target.value })} />
              </div>
            </div>
            {error && <div className="error">{error}</div>}
            <div className="flex gap-2">
              <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
                {busy ? "Saqlanmoqda…" : "Saqlash"}
              </button>
              <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setShowMove(false)}>Bekor</button>
            </div>
          </form>
        )}

        {!showMove && error && <div className="error">{error}</div>}

        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th>Mahsulot</th>
                <th>Variant</th>
                <th>Qoldiq (dona)</th>
              </tr>
            </thead>
            <tbody>
              {stocks.map((s) => (
                <tr key={s.id}>
                  <td className="font-medium">{s.product_name}</td>
                  <td>{s.variant_name || "—"}</td>
                  <td>{Number(s.quantity).toLocaleString()}</td>
                </tr>
              ))}
              {stocks.length === 0 && (
                <tr><td colSpan={3} style={{ color: "var(--muted)" }}>Hali qoldiq yo'q.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      <MovementHistory movements={movements} qtyLabel="product_name" />
    </div>
  );
}

function ProduceForm({ warehouseId, products, rawWarehouses, onDone }) {
  const [show, setShow] = useState(false);
  const [form, setForm] = useState({ product: "", variant: "", quantity: "", material_warehouse: "" });
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const [busy, setBusy] = useState(false);

  const selectedProduct = products.find((p) => p.id === form.product);

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setResult(null);
    if (!form.product || !form.material_warehouse) {
      setError("Mahsulot va xom ashyo omborini tanlang");
      return;
    }
    setBusy(true);
    try {
      const units = await api(`/warehouses/${warehouseId}/produce/`, {
        method: "POST",
        body: { ...form, variant: form.variant || null, quantity: Number(form.quantity) || 0 },
      });
      const unitCost = units[0]?.total_cost;
      setResult(`${units.length} dona ishlab chiqarildi — dona tannarxi: ${Number(unitCost).toLocaleString()} so'm`);
      setForm({ product: "", variant: "", quantity: "", material_warehouse: "" });
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="card flex flex-col gap-3 p-5">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-1.5 text-base font-semibold">
          <Hammer size={16} /> Ishlab chiqarish
        </span>
        <button className="btn !px-3 !py-1.5 text-xs" onClick={() => setShow((v) => !v)}>
          {show ? "Yopish" : "Yangi partiya"}
        </button>
      </div>
      <p className="text-xs" style={{ color: "var(--muted)" }}>
        Mahsulotning retsepti (Bill of Materials) bo'yicha xom ashyo avtomatik kamaytiriladi va har bir
        dona o'z tannarxi bilan alohida yozib olinadi.
      </p>

      {show && (
        <form className="flex flex-col gap-3 rounded-xl p-4" style={{ border: "1px dashed var(--border)" }} onSubmit={submit}>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label className="label">Mahsulot</label>
              <select className="input" value={form.product} onChange={(e) => setForm({ ...form, product: e.target.value, variant: "" })} required>
                <option value="">Tanlang…</option>
                {products.map((p) => (
                  <option key={p.id} value={p.id}>{p.name_uz}</option>
                ))}
              </select>
            </div>
            {selectedProduct?.variants?.length > 0 && (
              <div>
                <label className="label">Variant (ixtiyoriy)</label>
                <select className="input" value={form.variant} onChange={(e) => setForm({ ...form, variant: e.target.value })}>
                  <option value="">Barcha variantlar uchun umumiy</option>
                  {selectedProduct.variants.map((v) => (
                    <option key={v.id} value={v.id}>{v.name}</option>
                  ))}
                </select>
              </div>
            )}
            <div>
              <label className="label">Soni</label>
              <input className="input" type="number" min="1" value={form.quantity}
                onChange={(e) => setForm({ ...form, quantity: e.target.value })} required />
            </div>
            <div>
              <label className="label">Xom ashyo ombori</label>
              <select className="input" value={form.material_warehouse} onChange={(e) => setForm({ ...form, material_warehouse: e.target.value })} required>
                <option value="">Tanlang…</option>
                {rawWarehouses.map((w) => (
                  <option key={w.id} value={w.id}>{w.name}</option>
                ))}
              </select>
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <div className="flex gap-2">
            <button className="btn !px-3 !py-1.5 text-xs" type="submit" disabled={busy}>
              {busy ? "Ishlab chiqarilmoqda…" : "Ishlab chiqarish"}
            </button>
            <button className="btn-ghost !px-3 !py-1.5 text-xs" type="button" onClick={() => setShow(false)}>Bekor</button>
          </div>
        </form>
      )}
      {result && <span className="badge">{result}</span>}
    </div>
  );
}

function MovementHistory({ movements, qtyLabel }) {
  if (movements.length === 0) return null;
  return (
    <div className="card flex flex-col gap-3 p-5">
      <h2 className="text-base font-semibold">Harakatlar tarixi</h2>
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Sana</th>
              <th>Nomi</th>
              <th>Turi</th>
              <th>Miqdor</th>
              <th>Izoh</th>
              <th>Kim</th>
            </tr>
          </thead>
          <tbody>
            {movements.map((m) => (
              <tr key={m.id}>
                <td style={{ color: "var(--muted)" }}>{new Date(m.created_at).toLocaleString()}</td>
                <td className="font-medium">{m[qtyLabel]}{m.variant_name ? ` — ${m.variant_name}` : ""}</td>
                <td>
                  <span className={m.movement_type === "in" ? "badge" : "badge badge-off"}>
                    {m.movement_type_display}
                  </span>
                </td>
                <td>{Number(m.quantity).toLocaleString()}</td>
                <td style={{ color: "var(--muted)" }}>{m.note || "—"}</td>
                <td style={{ color: "var(--muted)" }}>{m.created_by_name || "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
