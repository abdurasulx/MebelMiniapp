import { useState } from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";
import { Menu, Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { POSITIONS, setActivePosition } from "../positions";
import { useTheme } from "../theme";
import ThemeSwitch from "../components/ThemeSwitch";

/**
 * ERP uslubidagi layout (Dream ERP tuzilishiga mos): chapda brend sidebar
 * (light: cream, dark: jigarrang) guruhlangan menyu bilan, tepada topbar.
 * menu: [{to, icon, label, end, soon, group}] — `group` bo'yicha kichik
 * sarlavhalar ostida bo'linadi (masalan "Asosiy", "Boshqaruv").
 * activePosition: multi-role xodimning hozir tanlagan roli.
 */
export default function PortalLayout({ title, menu, activePosition, onSwitchPosition }) {
  const { user, logout } = useAuth();
  const { dark, toggle } = useTheme();
  const [open, setOpen] = useState(false);
  const location = useLocation();

  const current =
    menu.find((m) =>
      m.end ? location.pathname === m.to : location.pathname.startsWith(m.to)
    )?.label || title;

  const groups = [];
  for (const item of menu) {
    const key = item.group || "";
    let g = groups.find((x) => x.key === key);
    if (!g) {
      g = { key, items: [] };
      groups.push(g);
    }
    g.items.push(item);
  }

  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-64 flex-col p-4 transition-transform lg:static lg:flex lg:translate-x-0 ${
          open ? "flex translate-x-0" : "hidden lg:flex -translate-x-full"
        }`}
        style={{ background: "var(--brand-surface)" }}
      >
        <div className="mb-8 flex items-center gap-2 px-2 pt-2">
          <Sofa size={26} style={{ color: "var(--brand-surface-text)" }} />
          <div>
            <div className="text-sm font-bold" style={{ color: "var(--brand-surface-text)" }}>
              Furniture Platform
            </div>
            <div className="text-xs" style={{ color: "var(--brand-surface-muted)" }}>
              {title}
            </div>
          </div>
        </div>
        <nav className="flex flex-1 flex-col gap-1 overflow-y-auto">
          {groups.map((g) => (
            <div key={g.key}>
              {g.key && <div className="side-group-label">{g.key}</div>}
              {g.items.map((m) => (
                <NavLink
                  key={m.to}
                  to={m.to}
                  end={m.end}
                  className={({ isActive }) => `side-link ${isActive ? "active" : ""}`}
                  onClick={() => setOpen(false)}
                >
                  <m.icon size={17} />
                  {m.label}
                  {m.soon && (
                    <span
                      className="ml-auto rounded-full px-2 py-0.5 text-[10px]"
                      style={{
                        background: "color-mix(in srgb, var(--brand-surface-text) 12%, transparent)",
                        color: "var(--brand-surface-muted)",
                      }}
                    >
                      tez orada
                    </span>
                  )}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        <div className="px-2 pb-2 text-xs" style={{ color: "var(--brand-surface-muted)" }}>
          © {new Date().getFullYear()} Furniture Platform
        </div>
      </aside>

      {/* Overlay (mobil) */}
      {open && (
        <div className="fixed inset-0 z-30 bg-black/40 lg:hidden" onClick={() => setOpen(false)} />
      )}

      {/* Content */}
      <div className="flex min-w-0 flex-1 flex-col">
        <header
          className="sticky top-0 z-20 flex items-center gap-3 px-4 py-3 lg:px-6"
          style={{
            background: "var(--card)",
            borderBottom: "1px solid var(--border)",
          }}
        >
          <button
            className="rounded-lg p-2 text-lg lg:hidden"
            onClick={() => setOpen(true)}
            aria-label="Menyu"
          >
            <Menu size={20} />
          </button>
          <h1 className="text-lg font-semibold">{current}</h1>
          <div className="ml-auto flex items-center gap-2">
            {activePosition && (
              <select
                className="input !w-auto !py-1.5 text-xs"
                value={activePosition}
                onChange={(e) => {
                  setActivePosition(e.target.value);
                  onSwitchPosition?.(e.target.value);
                }}
                title="Rolni almashtirish"
              >
                {(user?.positions || []).map((p) => (
                  <option key={p} value={p}>
                    {POSITIONS[p]?.label || p}
                  </option>
                ))}
              </select>
            )}
            <ThemeSwitch dark={dark} onToggle={toggle} />
            {user && (
              <div className="flex items-center gap-2">
                <div
                  className="hidden h-8 w-8 items-center justify-center rounded-full text-sm font-bold sm:flex"
                  style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
                >
                  {(user.first_name || user.email)[0].toUpperCase()}
                </div>
                <div className="hidden text-right sm:block">
                  <div className="text-xs font-medium">{user.first_name || user.email}</div>
                  <div className="text-[10px]" style={{ color: "var(--muted)" }}>
                    {user.company?.name || user.role}
                  </div>
                </div>
                <button onClick={logout} className="btn-ghost !px-3 !py-1.5 text-xs">
                  Chiqish
                </button>
              </div>
            )}
          </div>
        </header>
        <main className="flex-1 p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
