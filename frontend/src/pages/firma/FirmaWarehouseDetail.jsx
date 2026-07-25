import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Plus } from "lucide-react";
import { api } from "../../api";

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
  const [newMaterial, setNewMaterial] = useState({ name: "", unit: "dona", unit_cost: "" });
  const [busy, setBusy] = useState(false);

  const load = () =>
    Promise.all([
      api(`/warehouses/${warehouseId}/material-stocks/`),
      api(`/warehouses/${warehouseId}/material-movements/`),
      api("/materials/"),
    ])
      .then(([s, m, mat]) => {
        setStocks(s.results || []);
        setMovements(m.results || []);
        setMaterials(mat.results || []);
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
      const created = await api("/materials/", { method: "POST", body: newMaterial });
      setNewMaterial({ name: "", unit: "dona", unit_cost: "" });
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

  return (
    <div className="flex flex-col gap-4">
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

      <MovementHistory movements={movements} qtyLabel="material_name" />
    </div>
  );
}

function ProductWarehousePanel({ warehouseId }) {
  const [stocks, setStocks] = useState([]);
  const [movements, setMovements] = useState([]);
  const [products, setProducts] = useState([]);
  const [error, setError] = useState("");
  const [showMove, setShowMove] = useState(false);
  const [move, setMove] = useState({ product: "", variant: "", movement_type: "in", quantity: "", note: "" });
  const [busy, setBusy] = useState(false);

  const load = () =>
    Promise.all([
      api(`/warehouses/${warehouseId}/product-stocks/`),
      api(`/warehouses/${warehouseId}/product-movements/`),
      api("/products/"),
    ])
      .then(([s, m, p]) => {
        setStocks(s.results || []);
        setMovements(m.results || []);
        setProducts(p.results || []);
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
