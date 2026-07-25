import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Lock, Unlock, Link2 } from "lucide-react";
import { api } from "../api";
import ModelSceneViewer from "../components/ModelSceneViewer";

const VISIBILITY_BADGE = {
  public: { label: "Ochiq", icon: Unlock },
  restricted: { label: "Cheklangan", icon: Link2 },
  private: { label: "Yopiq", icon: Lock },
};

/**
 * Mustaqil 3D-viewer sahifasi — bazissoft.ru uslubida ulashiladigan havola.
 * /viewer/:token — login/portal talab qilinmaydi (ko'rinuvchanlikka qarab
 * backend ruxsat/rad javob beradi).
 */
export default function Viewer() {
  const { token } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [needsLogin, setNeedsLogin] = useState(false);

  useEffect(() => {
    api(`/viewer/${token}/`)
      .then(setData)
      .catch((e) => {
        setError(e.message);
        setNeedsLogin(!!e.body?.requires_login);
      });
  }, [token]);

  if (error) {
    return (
      <div
        className="flex min-h-screen flex-col items-center justify-center gap-3 p-6 text-center"
        style={{ background: "var(--bg)", color: "var(--text)" }}
      >
        <Lock size={36} style={{ color: "var(--muted)" }} />
        <h1 className="text-lg font-bold">Kirish mumkin emas</h1>
        <p className="max-w-sm text-sm" style={{ color: "var(--muted)" }}>{error}</p>
        {needsLogin && (
          <a href="/login" className="btn btn-brand mt-2">Tizimga kirish</a>
        )}
      </div>
    );
  }

  if (!data) {
    return (
      <div
        className="flex min-h-screen items-center justify-center"
        style={{ background: "var(--bg)", color: "var(--muted)" }}
      >
        Yuklanmoqda…
      </div>
    );
  }

  return (
    <div className="flex h-screen flex-col" style={{ background: "#0d0d15" }}>
      <div className="flex shrink-0 items-center justify-between px-5 py-4">
        <div>
          <div className="text-sm font-bold text-white">{data.product_name}</div>
          <div className="text-xs" style={{ color: "#9a9aa5" }}>
            {data.variant_name} · {data.company_name}
          </div>
        </div>
        {(() => {
          const v = VISIBILITY_BADGE[data.visibility];
          const VIcon = v?.icon;
          return (
            <span
              className="inline-flex items-center gap-1 rounded-full px-3 py-1 text-xs font-bold"
              style={{ background: "var(--primary)", color: "var(--primary-deep)" }}
            >
              {VIcon && <VIcon size={13} />} {v?.label}
            </span>
          );
        })()}
      </div>
      <div className="min-h-0 flex-1 px-4 pb-4">
        <ModelSceneViewer
          glb={data.glb_url}
          alt={data.product_name}
          style={{ height: "100%", width: "100%", background: "#16161f" }}
        />
      </div>
    </div>
  );
}
