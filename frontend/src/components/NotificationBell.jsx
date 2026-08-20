import { useEffect, useRef, useState } from "react";
import { Bell } from "lucide-react";
import { api } from "../api";

function timeAgo(iso) {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "hozir";
  if (mins < 60) return `${mins} daq oldin`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} soat oldin`;
  return `${Math.floor(hours / 24)} kun oldin`;
}

/// Xabarnomalar qo'ng'irog'i — mijozga buyurtma holati, xodimga vazifa
/// tayinlash/tayyorlik xabarlarini ko'rsatadi (qarang backend
/// apps.notifications). Push hali yo'q — 30s'da bir marta so'raladi.
export default function NotificationBell({ surface = false }) {
  const [count, setCount] = useState(0);
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const ref = useRef(null);

  useEffect(() => {
    const loadCount = () => {
      api("/notifications/unread_count/")
        .then((d) => setCount(d.count || 0))
        .catch(() => {});
    };
    loadCount();
    const interval = setInterval(loadCount, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const onClickOutside = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  const toggleOpen = () => {
    const next = !open;
    setOpen(next);
    if (next && !loaded) {
      api("/notifications/")
        .then((d) => {
          setItems(d.results || []);
          setLoaded(true);
        })
        .catch(() => {});
    }
  };

  const markAllRead = async () => {
    try {
      await api("/notifications/mark_all_read/", { method: "POST" });
      setItems((prev) => prev.map((n) => ({ ...n, is_read: true })));
      setCount(0);
    } catch {
      // jim o'tkazamiz
    }
  };

  const markRead = async (notif) => {
    if (notif.is_read) return;
    try {
      await api(`/notifications/${notif.id}/mark_read/`, { method: "POST" });
      setItems((prev) => prev.map((n) => (n.id === notif.id ? { ...n, is_read: true } : n)));
      setCount((c) => Math.max(0, c - 1));
    } catch {
      // jim o'tkazamiz
    }
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={toggleOpen}
        className={`relative flex items-center rounded-lg p-2 transition ${surface ? "hover:bg-black/10" : "hover:bg-black/5"}`}
        aria-label="Xabarnomalar"
      >
        <Bell size={18} />
        {count > 0 && (
          <span
            className="absolute right-0 top-0 flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[10px] font-bold"
            style={{ background: "#e74c3c", color: "#fff" }}
          >
            {count > 99 ? "99+" : count}
          </span>
        )}
      </button>
      {open && (
        <div
          className="absolute right-0 top-full z-50 mt-2 w-80 max-w-[90vw] overflow-hidden rounded-xl shadow-lg"
          style={{ background: "var(--card)", border: "1px solid var(--border)", color: "var(--text)" }}
        >
          <div className="flex items-center justify-between px-3 py-2" style={{ borderBottom: "1px solid var(--border)" }}>
            <span className="text-sm font-semibold">Xabarnomalar</span>
            {count > 0 && (
              <button onClick={markAllRead} className="text-xs" style={{ color: "var(--muted)" }}>
                Hammasini o'qilgan qilish
              </button>
            )}
          </div>
          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 && (
              <div className="p-4 text-center text-sm" style={{ color: "var(--muted)" }}>
                Hali xabarnoma yo'q.
              </div>
            )}
            {items.map((n) => (
              <button
                key={n.id}
                onClick={() => markRead(n)}
                className="block w-full px-3 py-2.5 text-left text-sm transition hover:bg-black/5"
                style={{
                  borderBottom: "1px solid var(--border)",
                  background: n.is_read ? "transparent" : "color-mix(in srgb, var(--brand-cta-bg) 8%, transparent)",
                }}
              >
                <div className="font-medium">{n.title}</div>
                {n.body && (
                  <div className="mt-0.5 text-xs" style={{ color: "var(--muted)" }}>
                    {n.body}
                  </div>
                )}
                <div className="mt-1 text-[10px]" style={{ color: "var(--muted)" }}>
                  {timeAgo(n.created_at)}
                </div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
