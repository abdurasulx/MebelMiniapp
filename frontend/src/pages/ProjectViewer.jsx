import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import { Lock } from "lucide-react";
import { api } from "../api";
import RoomScene from "../components/RoomScene";

/**
 * Mustaqil ulashish havolasi (bazissoft.ru uslubida): /viewer/project/:token —
 * faqat ko'rish (joylashtirish/aylantirish yo'q), portal chrome'siz.
 */
export default function ProjectViewer() {
  const { token } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [needsLogin, setNeedsLogin] = useState(false);

  useEffect(() => {
    api(`/viewer/project/${token}/`)
      .then(setData)
      .catch((e) => {
        setError(e.message);
        setNeedsLogin(!!e.body?.requires_login);
      });
  }, [token]);

  if (error) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-3 p-6 text-center" style={{ background: "#0d0d15", color: "#eaeaea" }}>
        <Lock size={36} style={{ color: "#8a8f98" }} />
        <h1 className="text-lg font-bold">Kirish mumkin emas</h1>
        <p className="max-w-sm text-sm" style={{ color: "#8a8f98" }}>{error}</p>
        {needsLogin && <a href="/login" className="btn btn-brand mt-2">Tizimga kirish</a>}
      </div>
    );
  }

  if (!data) {
    return (
      <div className="flex min-h-screen items-center justify-center" style={{ background: "#0d0d15", color: "#8a8f98" }}>
        Yuklanmoqda…
      </div>
    );
  }

  return (
    <div className="flex h-screen flex-col" style={{ background: "#0d0d15" }}>
      <div className="px-5 py-4">
        <div className="text-sm font-bold text-white">{data.name}</div>
        <div className="text-xs" style={{ color: "#9a9aa5" }}>{data.items.length} ta element</div>
      </div>
      <div className="flex-1">
        <RoomScene items={data.items} editable={false} />
      </div>
    </div>
  );
}
