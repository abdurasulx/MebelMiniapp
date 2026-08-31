import { useState } from "react";
import { NavLink, Outlet, useLocation } from "react-router-dom";
import { Menu, Sofa } from "lucide-react";
import { useAuth } from "../auth";
import { POSITIONS, setActivePosition } from "../positions";
import { useTheme } from "../theme";
import { BRAND_NAME } from "../portal";
import ThemeSwitch from "../components/ThemeSwitch";
import NotificationBell from "../components/NotificationBell";

/**
 * ERP uslubidagi layout (Dream ERP tuzilishiga mos): chapda brend sidebar
 * (light: cream, dark: jigarrang) guruhlangan menyu bilan, tepada topbar.
 * menu: [{to, icon, label, end, soon, group}] — `group` bo'yicha kichik
 * sarlavhalar ostida bo'linadi (masalan "Asosiy", "Boshqaruv").
 * activePosition: multi-role xodimning hozir tanlagan roli.
 */
export default function PortalLayout({ title, menu, activePosition, onSwitchPosition, showNotifications }) {
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
    <div className="flex h-screen overflow-hidden">
      {/* Sidebar — desktopda mustaqil o'z holicha scroll bo'ladi (butun
          sahifa bilan birga emas), shuning uchun uzun ro'yxatli
          sahifalarda ham navigatsiya doim ko'rinib turadi. */}
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-64 flex-col overflow-y-auto p-4 transition-transform lg:sticky lg:top-0 lg:flex lg:h-screen lg:translate-x-0 ${
          open ? "flex translate-x-0" : "hidden lg:flex -translate-x-full"
        }`}
        style={{ background: "var(--brand-surface)" }}
      >
        <div className="mb-8 flex items-center gap-2 px-2 pt-2">
          <Sofa size={26} style={{ color: "var(--brand-surface-text)" }} />
          <div>
            <div className="text-sm font-bold" style={{ color: "var(--brand-surface-text)" }}>
              {BRAND_NAME}
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
          © {new Date().getFullYear()} {BRAND_NAME}
        </div>
      </aside>

      {/* Overlay (mobil) */}
      {open && (
        <div className="fixed inset-0 z-30 bg-black/40 lg:hidden" onClick={() => setOpen(false)} />
      )}

      {/* Content — o'zining alohida scroll konteksti, sidebar bilan
          sinxronlanmaydi. */}
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <header
          className="z-20 flex shrink-0 items-center gap-3 px-4 py-3 lg:px-6"
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
          {/* Menyu (drawer) mobilda ochiq bo'lganda bu boshqaruvlar
              (bildirishnoma, tema, chiqish va h.k.) qorong'ilashtirilgan
              fon ustida hamon to'liq yorqin/aniq ko'rinib, chalkash va
              "singan" taassurot qoldirardi — endi shu holatda yashiriladi. */}
          <div className={`ml-auto ${open ? "hidden lg:flex" : "flex"} items-center gap-2`}>
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
            {showNotifications && <NotificationBell />}
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
        <main className="flex-1 overflow-y-auto p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
