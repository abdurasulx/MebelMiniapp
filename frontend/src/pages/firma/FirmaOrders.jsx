import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Phone, MapPin, MessageSquare, X, Workflow, Upload } from "lucide-react";
import { api } from "../../api";
import { useAuth } from "../../auth";
import { NEXT_STATUS, ORDER_STATUS, StatusBadge } from "../../orderStatus";
import LoadMoreButton from "../../components/LoadMoreButton";

export default function FirmaOrders() {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [products, setProducts] = useState([]);
  const [filter, setFilter] = useState("");
  const [error, setError] = useState("");
  const [nextPage, setNextPage] = useState(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [showNew, setShowNew] = useState(false);

  const load = () => {
    const companySlug = user?.company?.slug;
    return Promise.all([
      api("/orders/"),
      api("/employees/"),
      companySlug ? api(`/products/?company=${companySlug}`) : Promise.resolve({ results: [] }),
    ])
      .then(([d, emp, prod]) => {
        setOrders(d.results || []);
        setNextPage(d.next || null);
        setEmployees((emp.results || []).filter((e) => e.pay_type === "commission"));
        setProducts(prod.results || []);
      })
      .catch((e) => setError(e.message));
  };

  const setSoldBy = async (o, employeeId) => {
    try {
      await api(`/orders/${o.id}/set_sold_by/`, { method: "POST", body: { employee: employeeId || null } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const loadMore = async () => {
    if (!nextPage) return;
    setLoadingMore(true);
    try {
      const d = await api(nextPage);
      setOrders((prev) => [...prev, ...(d.results || [])]);
      setNextPage(d.next || null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoadingMore(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const setStatus = async (o, status) => {
    const label = ORDER_STATUS[status]?.label || status;
    if (status === "cancelled" && !confirm(`Buyurtma bekor qilinsinmi?`)) return;
    try {
      await api(`/orders/${o.id}/set_status/`, { method: "POST", body: { status } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  const shown = filter ? orders.filter((o) => o.status === filter) : orders;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <button
          className="rounded-full px-3 py-1.5 text-xs font-medium transition"
          style={
            filter === ""
              ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
              : { border: "1px solid var(--border)", color: "var(--muted)" }
          }
          onClick={() => setFilter("")}
        >
          Barchasi ({orders.length})
        </button>
        {Object.entries(ORDER_STATUS).map(([k, s]) => {
          const n = orders.filter((o) => o.status === k).length;
          if (n === 0) return null;
          const Icon = s.icon;
          return (
            <button
              key={k}
              className="inline-flex items-center gap-1 rounded-full px-3 py-1.5 text-xs font-medium transition"
              style={
                filter === k
                  ? { background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }
                  : { border: "1px solid var(--border)", color: "var(--muted)" }
              }
              onClick={() => setFilter(k)}
            >
              <Icon size={13} /> {s.label} ({n})
            </button>
          );
        })}
        <button className="btn !px-3 !py-1.5 text-xs ml-auto" onClick={() => setShowNew(true)}>
          + Yangi buyurtma
        </button>
      </div>
      {error && <div className="error">{error}</div>}
      {showNew && (
        <NewCustomOrderModal
          products={products}
          onClose={() => setShowNew(false)}
          onDone={() => { setShowNew(false); load(); }}
        />
      )}
      {shown.length === 0 && (
        <p className="text-sm" style={{ color: "var(--muted)" }}>Buyurtmalar yo'q.</p>
      )}

      {shown.map((o) => (
        <div key={o.id} className="card flex flex-col gap-3 p-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <span className="font-semibold">{o.customer_name || o.customer_email}</span>
              <span className="ml-2 inline-flex flex-wrap items-center gap-1 text-xs" style={{ color: "var(--muted)" }}>
                <Phone size={12} /> {o.phone} · <MapPin size={12} /> {o.address} · {new Date(o.created_at).toLocaleString("uz-UZ")}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {o.order_type === "custom_project" && <span className="badge badge-brand">{o.order_type_display}</span>}
              <StatusBadge status={o.status} />
            </div>
          </div>
          <div className="text-sm">
            {o.items.map((it) => (
              <div key={it.id} className="flex justify-between py-0.5">
                <span>
                  {it.product_name} {it.variant_name && `(${it.variant_name})`} · {it.width}×{it.height}×{it.depth} m ×{it.quantity}
                </span>
                <span className="font-medium">{Number(it.subtotal).toLocaleString()} so'm</span>
              </div>
            ))}
          </div>
          {user?.role === "company_owner" && employees.length > 0 && (
            <div className="flex items-center gap-2 text-xs" style={{ color: "var(--muted)" }}>
              <span>Sotuvchi (komissiya uchun):</span>
              <select
                className="input !w-auto !py-1 text-xs"
                value={o.sold_by || ""}
                onChange={(e) => setSoldBy(o, e.target.value)}
              >
                <option value="">— tanlanmagan —</option>
                {employees.map((emp) => (
                  <option key={emp.id} value={emp.id}>{emp.user_name || emp.user_email}</option>
                ))}
              </select>
            </div>
          )}
          {o.note && (
            <div className="flex items-center gap-1.5 rounded-lg px-3 py-2 text-xs" style={{ background: "color-mix(in srgb, var(--primary) 18%, transparent)" }}>
              <MessageSquare size={13} /> {o.note}
            </div>
          )}
          <div className="flex flex-wrap items-center justify-between gap-3 border-t pt-3" style={{ borderColor: "var(--border)" }}>
            <span className="text-lg font-bold">{Number(o.total_price).toLocaleString()} so'm</span>
            <div className="flex flex-wrap gap-2">
              {o.workflow_steps?.length > 0 && (
                <Link
                  to={`/orders/${o.id}`}
                  className="btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                >
                  <Workflow size={13} /> Ishlab chiqarish ({o.progress_percent ?? 0}%)
                </Link>
              )}
              {/* Buyurtma holatini o'zgartirish (qabul/bekor) — menejerlik
                  qarori, faqat firma egasi uchun (backend ham shunday
                  cheklaydi, qarang OrderViewSet.set_status). */}
              {user?.role === "company_owner" && (NEXT_STATUS[o.status] || []).map((s) => {
                const Icon = ORDER_STATUS[s].icon;
                return s === "cancelled" ? (
                  <button key={s} className="btn-danger inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(o, s)}>
                    <X size={13} /> Bekor qilish
                  </button>
                ) : (
                  <button key={s} className="btn inline-flex items-center gap-1 !px-3 !py-1.5 text-xs" onClick={() => setStatus(o, s)}>
                    <Icon size={13} /> {ORDER_STATUS[s].label}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      ))}
      <div className="flex justify-center">
        <LoadMoreButton next={nextPage} busy={loadingMore} onClick={loadMore} />
      </div>
    </div>
  );
}

function emptyItem() {
  return {
    product: "", variant: "", isFree: false, customName: "",
    width: "1", height: "1", depth: "1", quantity: "1",
  };
}

function NewCustomOrderModal({ products, onClose, onDone }) {
  const [customerWorkerId, setCustomerWorkerId] = useState("");
  const [address, setAddress] = useState("");
  const [it, setIt] = useState(emptyItem());
  const [bazisFile, setBazisFile] = useState(null);
  const [bazisGroups, setBazisGroups] = useState(null);
  const [bazisLoading, setBazisLoading] = useState(false);
  const [bazisError, setBazisError] = useState("");
  // Har guruh (masalan "Teshish Ø8mm") uchun: pullikmi va narxi — qarang
  // pickBazisFile (fayl tanlangach avtomatik to'ldiriladi, agar shu
  // guruh nomi bilan "Ish turlari"da narx allaqachon bo'lsa).
  const [groupPay, setGroupPay] = useState({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const patchItem = (patch) => setIt((prev) => ({ ...prev, ...patch }));

  const pickBazisFile = async (file) => {
    setBazisFile(file);
    setBazisGroups(null);
    setBazisError("");
    if (!file) return;
    setBazisLoading(true);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const d = await api("/custom-orders/parse-bazis/", { method: "POST", body: fd, isForm: true });
      setBazisGroups(d.groups || []);
      const initial = {};
      for (const g of d.groups || []) {
        const existing = Number(g.price_per_unit) || 0;
        initial[g.name] = { paid: existing > 0, price: existing > 0 ? String(existing) : "" };
      }
      setGroupPay(initial);
    } catch (err) {
      setBazisError(err.message);
    } finally {
      setBazisLoading(false);
    }
  };

  const submit = async (e) => {
    e.preventDefault();
    setError("");
    setBusy(true);
    try {
      const body = {
        customer_worker_id: customerWorkerId,
        address,
        items: [
          {
            ...(it.isFree ? { custom_name: it.customName.trim() } : { product: it.product }),
            variant: it.isFree ? null : it.variant || null,
            width: it.width,
            height: it.height,
            depth: it.depth,
            quantity: Number(it.quantity) || 1,
            // Katalogdan tanlangan (erkin bo'lmagan) va variant biriktirilgan
            // band — narx variantning standart narxidan avtomatik hisoblanadi
            // (o'lchamlar ham o'sha variantdan olingan, qarang patchItem
            // "product"/"variant" chaqiruvlari). Erkin nomli band uchun narx
            // avtomatik hisoblanmaydi — admin keyin qo'lda kiritadi.
            is_custom_size: it.isFree || !it.variant,
          },
        ],
      };
      const order = await api("/custom-orders/create/", { method: "POST", body });

      if (bazisFile && it.isFree) {
        const fd = new FormData();
        fd.append("file", bazisFile);
        const prices = {};
        for (const [name, g] of Object.entries(groupPay)) {
          if (g.paid && g.price) prices[name] = g.price;
        }
        fd.append("prices", JSON.stringify(prices));
        try {
          await api(`/custom-orders/${order.id}/import-bazis/`, { method: "POST", body: fd, isForm: true });
        } catch (err) {
          setError(`Buyurtma yaratildi, lekin Bazis fayli yuklanmadi: ${err.message}`);
          onDone();
          return;
        }
      }
      onDone();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <form
        className="card flex w-full max-w-lg flex-col gap-4 p-6"
        style={{ maxHeight: "90vh", overflowY: "auto" }}
        onClick={(e) => e.stopPropagation()}
        onSubmit={submit}
      >
        <h3 className="text-lg font-semibold">Yangi buyurtma (individual loyiha)</h3>

        <label className="flex flex-col gap-1 text-sm">
          Mijoz qidiruvchi ID yoki telefon raqami
          <input
            className="input" required placeholder="masalan 1234567890 yoki +998901234567"
            value={customerWorkerId}
            onChange={(e) => setCustomerWorkerId(e.target.value)}
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          Manzil (ixtiyoriy)
          <input className="input" value={address} onChange={(e) => setAddress(e.target.value)} />
        </label>

        <div className="flex flex-col gap-3">
          {(() => {
            const product = products.find((p) => p.id === it.product);
            return (
              <div className="flex flex-col gap-2 rounded-lg border p-3" style={{ borderColor: "var(--border)" }}>
                <div className="flex items-center gap-2">
                  {it.isFree ? (
                    <input
                      className="input flex-1" required placeholder="Mahsulot nomi (erkin)"
                      value={it.customName}
                      onChange={(e) => patchItem({ customName: e.target.value })}
                    />
                  ) : (
                    <select
                      className="input flex-1" required value={it.product}
                      onChange={(e) => {
                        const p = products.find((x) => x.id === e.target.value);
                        const v = p?.variants?.[0];
                        patchItem({
                          product: e.target.value,
                          variant: v?.id || "",
                          width: v?.width ?? it.width,
                          height: v?.height ?? it.height,
                          depth: v?.depth ?? it.depth,
                        });
                      }}
                    >
                      <option value="">Mahsulot tanlang…</option>
                      {products.filter((p) => p.category_slug !== "individual-boshqa").map((p) => (
                        <option key={p.id} value={p.id}>{p.name_uz}</option>
                      ))}
                    </select>
                  )}
                  <button
                    type="button"
                    className={it.isFree ? "btn !px-2.5 !py-1.5 text-xs" : "btn-ghost !px-2.5 !py-1.5 text-xs"}
                    title="Katalogda yo'q mahsulot uchun nomni qo'lda kiriting"
                    onClick={() => patchItem({
                      isFree: !it.isFree, product: "", variant: "",
                      width: "1", height: "1", depth: "1",
                    })}
                  >
                    Erkin nom
                  </button>
                </div>
                {!it.isFree && product?.variants?.length > 0 && (
                  <select
                    className="input" value={it.variant}
                    onChange={(e) => {
                      const v = product.variants.find((x) => x.id === e.target.value);
                      patchItem({
                        variant: e.target.value,
                        width: v?.width ?? it.width,
                        height: v?.height ?? it.height,
                        depth: v?.depth ?? it.depth,
                      });
                    }}
                  >
                    {product.variants.map((v) => (
                      <option key={v.id} value={v.id}>{v.name}</option>
                    ))}
                  </select>
                )}
                {/* Eni/Bo'yi/Chuquri hech qachon so'ralmaydi — katalog
                    mahsuloti bo'lsa variantdan avtomatik olinadi, erkin
                    nomli band uchun esa umuman ahamiyatsiz (narxni admin
                    keyin qo'lda kiritadi) — ikkalasida ham standart "1"
                    qiymati jim yuboriladi (qarang emptyItem/submit). */}
                <label className="flex max-w-[120px] flex-col gap-0.5 text-xs" style={{ color: "var(--muted)" }}>
                  Soni
                  <input className="input" type="number" min="1" value={it.quantity} onChange={(e) => patchItem({ quantity: e.target.value })} />
                </label>
              </div>
            );
          })()}
        </div>

        {/* Bazis fayl faqat erkin (katalogda yo'q) band bo'lsa ma'noli —
            katalogdan tanlangan mahsulotning o'z ishlab chiqarish
            shabloni bor, alohida CAD fayl import qilish shart emas. */}
        {it.isFree && (
        <label className="flex flex-col gap-1 text-sm">
          Bazis fayl (ixtiyoriy)
          <div className="flex items-center gap-2">
            <label className="btn-ghost inline-flex cursor-pointer items-center gap-1.5 !px-3 !py-1.5 text-xs">
              <Upload size={13} /> {bazisFile ? bazisFile.name : "Fayl tanlash (.project)"}
              <input
                type="file" accept=".project" style={{ display: "none" }}
                onChange={(e) => pickBazisFile(e.target.files?.[0] || null)}
              />
            </label>
            {bazisFile && (
              <button type="button" className="icon-btn" onClick={() => pickBazisFile(null)}>
                <X size={14} />
              </button>
            )}
          </div>
          <span style={{ fontSize: 11, color: "var(--muted)" }}>
            CAD dasturidan eksport qilingan .project fayli — detal/teshik ma'lumotidan ishlab chiqarish
            topshiriqlari avtomatik tuziladi (dizayn tasdiqlanib "Ishlab chiqarishga" o'tganda).
          </span>

          {bazisLoading && <span style={{ fontSize: 12, color: "var(--muted)" }}>Tahlil qilinmoqda…</span>}
          {bazisError && <div className="error">{bazisError}</div>}
          {bazisGroups?.length > 0 && (
            <div className="flex flex-col gap-1.5 rounded-lg border p-2.5" style={{ borderColor: "var(--border)" }}>
              <span style={{ fontSize: 11.5, fontWeight: 600, color: "var(--muted)" }}>
                Topilgan ishlar — har biriga ixtiyoriy ravishda narx belgilang:
              </span>
              {bazisGroups.map((g) => {
                const gp = groupPay[g.name] || { paid: false, price: "" };
                return (
                  <div key={g.name} className="flex items-center gap-2 text-xs">
                    <label className="flex flex-1 items-center gap-1.5">
                      <input
                        type="checkbox" checked={gp.paid}
                        onChange={(e) => setGroupPay((prev) => ({ ...prev, [g.name]: { ...gp, paid: e.target.checked } }))}
                      />
                      {g.name} <span style={{ color: "var(--muted)" }}>({g.quantity} {g.unit})</span>
                    </label>
                    {gp.paid && (
                      <input
                        className="input !w-24 !py-1 text-xs" type="number" min="0" placeholder="narx"
                        value={gp.price}
                        onChange={(e) => setGroupPay((prev) => ({ ...prev, [g.name]: { ...gp, price: e.target.value } }))}
                      />
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </label>
        )}

        {error && <div className="error">{error}</div>}

        <div className="flex justify-end gap-2">
          <button type="button" className="btn-ghost" onClick={onClose}>Bekor qilish</button>
          <button type="submit" className="btn" disabled={busy}>{busy ? "Yaratilmoqda…" : "Yaratish"}</button>
        </div>
      </form>
    </div>
  );
}
