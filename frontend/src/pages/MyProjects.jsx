import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { FolderKanban, Lock, Plus, Unlock } from "lucide-react";
import { api } from "../api";

/** Mijozning "xonamni bezash" loyihalari ro'yxati — yangi loyiha shu yerdan yaratiladi. */
export default function MyProjects() {
  const [projects, setProjects] = useState(null);
  const [error, setError] = useState("");
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);

  const load = () => api("/projects/").then((p) => setProjects(p.results || [])).catch((e) => setError(e.message));

  useEffect(() => {
    load();
  }, []);

  const createProject = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;
    setBusy(true);
    try {
      await api("/projects/", { method: "POST", body: { name: name.trim() } });
      setName("");
      await load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <h1 className="mb-1 text-2xl font-bold">Loyihalarim</h1>
      <p className="mb-6 text-sm" style={{ color: "var(--muted)" }}>
        Xonangizni istalgan do'kondagi mahsulotlar bilan to'ldirib, 3D'da joylashtirib ko'ring.
      </p>

      <form onSubmit={createProject} className="card mb-6 flex gap-2 p-4">
        <input
          className="input flex-1"
          placeholder="Loyiha nomi (masalan: Oshxonam)"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <button className="btn btn-brand inline-flex items-center gap-1.5" disabled={busy}>
          <Plus size={16} /> Yaratish
        </button>
      </form>

      {error && <div className="error mb-4">{error}</div>}

      {!projects ? (
        <p style={{ color: "var(--muted)" }}>Yuklanmoqda…</p>
      ) : projects.length === 0 ? (
        <div className="card p-8 text-center">
          <FolderKanban className="mx-auto mb-2" size={32} style={{ color: "var(--muted)" }} />
          <p style={{ color: "var(--muted)" }}>Hali loyiha yo'q — yuqoridan birinchisini yarating.</p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {projects.map((p) => (
            <Link
              key={p.id}
              to={`/projects/${p.id}`}
              className="card flex items-center justify-between p-4 transition hover:opacity-90"
            >
              <div>
                <div className="font-semibold">{p.name}</div>
                <div className="text-xs" style={{ color: "var(--muted)" }}>
                  {p.items?.length || 0} ta element
                </div>
              </div>
              <span
                className="inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-bold"
                style={{
                  background: p.is_paid
                    ? "color-mix(in srgb, #2ecc71 20%, transparent)"
                    : "color-mix(in srgb, var(--muted) 16%, transparent)",
                  color: p.is_paid ? "#1e8449" : "var(--muted)",
                }}
              >
                {p.is_paid ? <Unlock size={13} /> : <Lock size={13} />}
                {p.is_paid ? "To'langan" : "To'lanmagan"}
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
