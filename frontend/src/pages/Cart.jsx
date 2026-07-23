import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ShoppingBasket, Sofa, X, Package } from "lucide-react";
import { api } from "../api";
import { useAuth } from "../auth";
import { cartTotal, clearCart, getCart, itemSubtotal, removeFromCart, setQty } from "../cart";

export default function Cart() {
  const { user } = useAuth();
  const nav = useNavigate();
  const [items, setItems] = useState(getCart());
  const [form, setForm] = useState({ phone: "", address: "", note: "" });
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const onChange = () => setItems(getCart());
    window.addEventListener("cart-changed", onChange);
    return () => window.removeEventListener("cart-changed", onChange);
  }, []);

  const checkout = async (e) => {
    e.preventDefault();
    if (!user) {
      nav("/login");
      return;
    }
    setError("");
    setBusy(true);
    try {
      // har bir kompaniya uchun alohida buyurtma
      const byCompany = {};
      items.forEach((i) => {
        (byCompany[i.companyId] ||= []).push(i);
      });
      for (const group of Object.values(byCompany)) {
        await api("/orders/", {
          method: "POST",
          body: {
            ...form,
            items: group.map((i) => ({
              variant: i.variantId,
              width: i.width,
              height: i.height,
              depth: i.depth,
              quantity: i.qty,
            })),
          },
        });
      }
      clearCart();
      nav("/orders");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  if (items.length === 0)
    return (
      <div className="mx-auto max-w-3xl px-4 py-16 text-center">
        <ShoppingBasket className="mx-auto mb-2" size={40} style={{ color: "var(--muted)" }} />
        <h1 className="mb-2 text-xl font-bold">Savat bo'sh</h1>
        <p className="mb-4 text-sm" style={{ color: "var(--muted)" }}>
          Katalogdan mahsulot tanlang.
        </p>
        <Link to="/" className="btn btn-brand">Katalogga o'tish</Link>
      </div>
    );

  return (
    <div className="mx-auto max-w-5xl px-4 py-8">
      <h1 className="mb-6 text-2xl font-bold">Savat</h1>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="flex flex-col gap-3 lg:col-span-2">
          {items.map((i, idx) => (
            <div key={idx} className="card flex flex-wrap items-center gap-4 p-4">
              {i.image ? (
                <img src={i.image} alt="" className="h-16 w-16 rounded-xl object-cover" />
              ) : (
                <div
                  className="flex h-16 w-16 items-center justify-center rounded-xl"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  <Sofa size={22} />
                </div>
              )}
              <div className="min-w-0 flex-1">
                <div className="font-semibold">{i.productName}</div>
                <div className="text-xs" style={{ color: "var(--muted)" }}>
                  {i.variantName} · {i.width}×{i.height}×{i.depth} m · {i.companyName}
                </div>
              </div>
              <input
                className="input !w-20"
                type="number"
                min="1"
                value={i.qty}
                onChange={(e) => setQty(idx, parseInt(e.target.value) || 1)}
              />
              <div className="w-32 text-right font-bold">
                {itemSubtotal(i).toLocaleString()} so'm
              </div>
              <button className="btn-danger !px-3 !py-1.5 text-xs" onClick={() => removeFromCart(idx)}>
                <X size={14} />
              </button>
            </div>
          ))}
        </div>

        <form className="card flex h-fit flex-col gap-4 p-6" onSubmit={checkout}>
          <h2 className="text-base font-semibold">Buyurtma berish</h2>
          <div>
            <label className="label">Telefon *</label>
            <input
              className="input"
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              placeholder="+998…"
              required
            />
          </div>
          <div>
            <label className="label">Manzil *</label>
            <input
              className="input"
              value={form.address}
              onChange={(e) => setForm({ ...form, address: e.target.value })}
              required
            />
          </div>
          <div>
            <label className="label">Izoh</label>
            <textarea
              className="input"
              rows={2}
              value={form.note}
              onChange={(e) => setForm({ ...form, note: e.target.value })}
            />
          </div>
          <div className="flex items-center justify-between border-t pt-3" style={{ borderColor: "var(--border)" }}>
            <span className="text-sm" style={{ color: "var(--muted)" }}>Jami</span>
            <span className="text-xl font-bold">{cartTotal(items).toLocaleString()} so'm</span>
          </div>
          {error && <div className="error">{error}</div>}
          <button className="btn btn-brand inline-flex items-center justify-center gap-1.5" type="submit" disabled={busy}>
            {busy ? "Yuborilmoqda…" : user ? <><Package size={15} /> Buyurtma berish</> : "Kirish va buyurtma berish"}
          </button>
        </form>
      </div>
    </div>
  );
}
