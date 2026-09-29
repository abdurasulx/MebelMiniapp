import { useEffect, useState } from "react";
import { Hammer } from "lucide-react";
import { api } from "../api";

/// Mahsulot retsepti (Bill of Materials) bo'yicha xom ashyoni kamaytirib,
/// N dona yangi ManufacturedUnit (tayyor mahsulot) yaratadi — har biri o'z
/// haqiqiy tannarxi bilan. `warehouseId` berilsa (Ombor sahifasidan
/// chaqirilganda) aynan shu tayyor mahsulot omboriga ishlab chiqariladi;
/// berilmasa (Ishlab chiqarish sahifasidan chaqirilganda) firmaning tayyor
/// mahsulot omborlari o'zi yuklanadi — bitta bo'lsa avtomatik tanlanadi,
/// bir nechta bo'lsa tanlash chiqadi, umuman yo'q bo'lsa ombor yaratishga
/// yo'naltiriladi.
export default function ProduceForm({ warehouseId, onDone }) {
  const [show, setShow] = useState(false);
  const [products, setProducts] = useState([]);
  const [rawWarehouses, setRawWarehouses] = useState([]);
  const [finishedWarehouses, setFinishedWarehouses] = useState([]);
  const [loaded, setLoaded] = useState(!!warehouseId);
  const [form, setForm] = useState({
    product: "", variant: "", quantity: "", material_warehouse: "",
    finished_warehouse: warehouseId || "",
  });
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (warehouseId) return; // ombor allaqachon berilgan — omborlar ro'yxati kerak emas
    Promise.all([api("/products/"), api("/warehouses/")])
      .then(([p, wh]) => {
        setProducts(p.results || []);
        const all = wh.results || [];
        setRawWarehouses(all.filter((w) => w.kind === "raw_material"));
        const finished = all.filter((w) => w.kind === "finished_goods");
        setFinishedWarehouses(finished);
        if (finished.length === 1) setForm((f) => ({ ...f, finished_warehouse: finished[0].id }));
      })
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));
  }, [warehouseId]);

  useEffect(() => {
    if (!warehouseId) return;
    api("/products/").then((p) => setProducts(p.results || [])).catch((e) => setError(e.message));
    api("/warehouses/")
      .then((wh) => setRawWarehouses((wh.results || []).filter((w) => w.kind === "raw_material")))
      .catch((e) => setError(e.message));
  }, [warehouseId]);

  const selectedProduct = products.find((p) => p.id === form.product);
  const targetWarehouse = warehouseId || form.finished_warehouse;

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setResult(null);
    if (!form.product || !form.material_warehouse || !targetWarehouse) {
      setError("Mahsulot, xom ashyo ombori va tayyor mahsulot omborini tanlang");
      return;
    }
    setBusy(true);
    try {
      const units = await api(`/warehouses/${targetWarehouse}/produce/`, {
        method: "POST",
        body: {
          product: form.product, variant: form.variant || null,
          quantity: Number(form.quantity) || 0, material_warehouse: form.material_warehouse,
        },
      });
      const unitCost = units[0]?.total_cost;
      setResult(`${units.length} dona ishlab chiqarildi — dona tannarxi: ${Number(unitCost).toLocaleString()} so'm`);
      setForm((f) => ({ ...f, product: "", variant: "", quantity: "", material_warehouse: "" }));
      onDone?.();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  if (loaded && !warehouseId && finishedWarehouses.length === 0) {
    return (
      <div className="card flex flex-col gap-2 p-5">
        <span className="inline-flex items-center gap-1.5 text-base font-semibold">
          <Hammer size={16} /> Ishlab chiqarish
        </span>
        <p className="text-xs" style={{ color: "var(--muted)" }}>
          Tayyor mahsulotni omborga kiritish uchun avval "Tayyor mahsulot ombori" turidagi ombor yarating
          (Omborlar bo'limida).
        </p>
      </div>
    );
  }

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
        dona o'z tannarxi bilan alohida yozib olinadi — omborga qo'shiladi, keyin buyurtmalarni shundan
        yopish mumkin bo'ladi.
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
            {!warehouseId && finishedWarehouses.length > 1 && (
              <div>
                <label className="label">Tayyor mahsulot ombori</label>
                <select className="input" value={form.finished_warehouse} onChange={(e) => setForm({ ...form, finished_warehouse: e.target.value })} required>
                  <option value="">Tanlang…</option>
                  {finishedWarehouses.map((w) => (
                    <option key={w.id} value={w.id}>{w.name}</option>
                  ))}
                </select>
              </div>
            )}
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
      {!show && error && <div className="error">{error}</div>}
      {result && <span className="badge">{result}</span>}
    </div>
  );
}
