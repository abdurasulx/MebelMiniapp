import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { Heart, Sofa } from "lucide-react";
import { api } from "../api";

export default function Liked() {
  const [likes, setLikes] = useState([]);
  const [error, setError] = useState("");
  const [loaded, setLoaded] = useState(false);

  const load = () =>
    api("/likes/")
      .then((d) => setLikes(d.results || []))
      .catch((e) => setError(e.message))
      .finally(() => setLoaded(true));

  useEffect(() => {
    load();
  }, []);

  const unlike = async (productId) => {
    try {
      await api("/likes/toggle/", { method: "POST", body: { product: productId } });
      load();
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <h1 className="mb-6 flex items-center gap-2 text-2xl font-bold">
        <Heart size={22} fill="currentColor" style={{ color: "#e74c3c" }} /> Sevimlilar
      </h1>
      {error && <div className="error mb-4">{error}</div>}
      {loaded && likes.length === 0 && (
        <div className="card flex flex-col items-center gap-3 p-10 text-center">
          <Heart size={36} style={{ color: "var(--muted)" }} />
          <p className="text-sm" style={{ color: "var(--muted)" }}>
            Hali sevimli mahsulot yo'q. Katalogdan yoqqan mahsulotni yurakcha bilan belgilang.
          </p>
          <Link to="/" className="btn btn-brand">Katalogga o'tish</Link>
        </div>
      )}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {likes.map(({ product_detail: p }) => (
          <div key={p.id} className="card relative overflow-hidden">
            <button
              onClick={() => unlike(p.id)}
              className="absolute right-2 top-2 z-10 flex h-7 w-7 items-center justify-center rounded-full shadow"
              style={{ background: "var(--card)" }}
              title="Sevimlilardan olib tashlash"
            >
              <Heart size={14} fill="currentColor" style={{ color: "#e74c3c" }} />
            </button>
            <Link to={`/products/${p.id}`}>
              {(p.image_url || p.images?.[0]?.image_url) ? (
                <img src={p.image_url || p.images[0].image_url} alt={p.name_uz} className="h-44 w-full object-cover" />
              ) : (
                <div
                  className="flex h-44 w-full items-center justify-center"
                  style={{ background: "color-mix(in srgb, var(--primary) 25%, transparent)" }}
                >
                  <Sofa size={36} />
                </div>
              )}
              <div className="flex flex-col gap-1 p-4">
                <span className="font-semibold">{p.name_uz}</span>
                <span className="text-xs" style={{ color: "var(--muted)" }}>{p.company_name}</span>
                {p.variants.length > 0 && (
                  <span className="mt-1 text-sm font-bold" style={{ color: "var(--secondary)" }}>
                    {Number(p.variants[0].base_price).toLocaleString()} so'm/m³ dan
                  </span>
                )}
              </div>
            </Link>
          </div>
        ))}
      </div>
    </div>
  );
}
