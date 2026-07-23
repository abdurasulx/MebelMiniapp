import { HardHat, Hand } from "lucide-react";
import { POSITIONS, setActivePosition } from "../../positions";
import { useAuth } from "../../auth";

/** Multi-role xodim kirganda qaysi rolda ishlashini tanlaydi. */
export default function RolePicker({ onPicked }) {
  const { user, logout } = useAuth();

  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <div className="card w-full max-w-md p-8">
        <div className="mb-6 text-center">
          <Hand className="mx-auto mb-1" size={30} style={{ color: "var(--secondary)" }} />
          <h1 className="text-lg font-bold">Xush kelibsiz, {user.first_name || user.email}!</h1>
          <p className="text-xs" style={{ color: "var(--muted)" }}>
            Bugun qaysi rolda ishlaysiz?
          </p>
        </div>
        <div className="flex flex-col gap-2">
          {user.positions.map((p) => {
            const Icon = POSITIONS[p]?.icon || HardHat;
            return (
            <button
              key={p}
              className="flex items-center gap-3 rounded-xl p-4 text-left transition hover:-translate-y-0.5"
              style={{ border: "1px solid var(--border)", background: "var(--card)" }}
              onClick={() => {
                setActivePosition(p);
                onPicked(p);
              }}
            >
              <span
                className="flex h-11 w-11 items-center justify-center rounded-xl"
                style={{ background: "color-mix(in srgb, var(--primary) 30%, transparent)" }}
              >
                <Icon size={20} />
              </span>
              <span>
                <span className="block text-sm font-semibold">{POSITIONS[p]?.label || p}</span>
                <span className="block text-xs" style={{ color: "var(--muted)" }}>
                  {POSITIONS[p]?.desc}
                </span>
              </span>
            </button>
          );
          })}
        </div>
        <button className="btn-ghost mt-4 w-full" onClick={logout}>
          Boshqa hisob bilan kirish
        </button>
      </div>
    </div>
  );
}
