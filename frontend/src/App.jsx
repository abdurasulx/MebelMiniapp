import { useState } from "react";
import { Link, Navigate, Route, Routes, useLocation } from "react-router-dom";
import { useAuth } from "./auth";
import PortalLayout from "./layouts/PortalLayout";
import { PORTAL } from "./portal";
import { getActivePosition } from "./positions";
import RolePicker from "./pages/firma/RolePicker";
import { useTheme } from "./theme";
import AdminCategories from "./pages/admin/AdminCategories";
import AdminCompanies from "./pages/admin/AdminCompanies";
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminOrders from "./pages/admin/AdminOrders";
import AdminUsers from "./pages/admin/AdminUsers";
import Cart from "./pages/Cart";
import Catalog from "./pages/Catalog";
import Liked from "./pages/Liked";
import Employees from "./pages/Employees";
import FirmaDashboard from "./pages/firma/FirmaDashboard";
import FirmaLeads from "./pages/firma/FirmaLeads";
import FirmaOrders from "./pages/firma/FirmaOrders";
import FirmaPayroll from "./pages/firma/FirmaPayroll";
import FirmaProduction from "./pages/firma/FirmaProduction";
import FirmaProducts from "./pages/firma/FirmaProducts";
import FirmaSettings from "./pages/firma/FirmaSettings";
import Login from "./pages/Login";
import MyOrders from "./pages/MyOrders";
import ProductDetail from "./pages/ProductDetail";
import Register from "./pages/Register";
import Shop from "./pages/Shop";
import Viewer from "./pages/Viewer";
import ThemeSwitch from "./components/ThemeSwitch";
import { cartCount, getCart } from "./cart";
import { useEffect } from "react";
import {
  LayoutDashboard,
  Factory,
  Users,
  FolderTree,
  Package,
  Wallet,
  Sofa,
  Target,
  Hammer,
  HardHat,
  Settings,
  Construction,
  ShoppingBasket,
  Heart,
} from "lucide-react";

const ADMIN_MENU = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true, group: "Asosiy" },
  { to: "/companies", icon: Factory, label: "Kompaniyalar", group: "Boshqaruv" },
  { to: "/users", icon: Users, label: "Foydalanuvchilar", group: "Boshqaruv" },
  { to: "/categories", icon: FolderTree, label: "Kategoriyalar", group: "Boshqaruv" },
  { to: "/orders", icon: Package, label: "Buyurtmalar", group: "Savdo" },
  { to: "/finance", icon: Wallet, label: "Moliya", soon: true, group: "Savdo" },
];

const FIRMA_MENU = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true, group: "Asosiy" },
  { to: "/products", icon: Sofa, label: "Mahsulotlar", group: "Katalog" },
  { to: "/leads", icon: Target, label: "Leadlar (CRM)", group: "Savdo" },
  { to: "/orders", icon: Package, label: "Buyurtmalar", group: "Savdo" },
  { to: "/production", icon: Hammer, label: "Ishlab chiqarish", group: "Ishlab chiqarish" },
  { to: "/employees", icon: HardHat, label: "Xodimlar", group: "Xodimlar" },
  { to: "/payroll", icon: Wallet, label: "Ish haqi", group: "Xodimlar" },
  { to: "/settings", icon: Settings, label: "Sozlamalar", group: "Tizim" },
];

function Protected({ children, roles }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="p-8" style={{ color: "var(--muted)" }}>Yuklanmoqda…</div>;
  if (!user) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user.role))
    return (
      <div className="p-8">
        <div className="error">
          Bu portal siz uchun emas ({user.email} — {user.role}).
        </div>
      </div>
    );
  return children;
}

/** Firma portali: multi-role xodim avval rolini tanlaydi. */
function FirmaShell() {
  const { user } = useAuth();
  const [active, setActive] = useState(getActivePosition());

  if (user.role === "employee" && user.positions?.length > 0) {
    const valid = active && user.positions.includes(active);
    if (!valid) return <RolePicker onPicked={setActive} />;
  }
  return (
    <PortalLayout
      title="Firma kabineti"
      menu={FIRMA_MENU}
      activePosition={user.role === "employee" ? active : null}
      onSwitchPosition={setActive}
    />
  );
}

function Soon({ label }) {
  return (
    <div className="card mx-auto max-w-md p-8 text-center">
      <Construction className="mx-auto mb-2" size={32} style={{ color: "var(--muted)" }} />
      <h2 className="mb-1 text-lg font-semibold">{label}</h2>
      <p className="text-sm" style={{ color: "var(--muted)" }}>
        Bu modul tez orada qo'shiladi.
      </p>
    </div>
  );
}

/* ===== Market (mijozlar) ===== */
function MarketLayout({ children }) {
  const { user, logout } = useAuth();
  const { dark, toggle } = useTheme();
  const [count, setCount] = useState(cartCount(getCart()));

  useEffect(() => {
    const onChange = () => setCount(cartCount(getCart()));
    window.addEventListener("cart-changed", onChange);
    return () => window.removeEventListener("cart-changed", onChange);
  }, []);

  return (
    <>
      <header
        className="sticky top-0 z-40 flex items-center justify-between gap-3 px-4 py-3 lg:px-8"
        style={{ background: "var(--brand-surface)", color: "var(--brand-surface-text)" }}
      >
        <Link to="/" className="flex items-center gap-2 font-bold">
          <Sofa size={22} /> Furniture Platform
        </Link>
        <nav className="flex items-center gap-1 text-sm">
          <Link to="/" className="rounded-lg px-3 py-1.5 transition hover:bg-black/10">
            Katalog
          </Link>
          <Link to="/cart" className="relative flex items-center rounded-lg px-3 py-1.5 transition hover:bg-black/10">
            <ShoppingBasket size={18} />
            {count > 0 && (
              <span
                className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[10px] font-bold"
                style={{ background: "#e74c3c", color: "#fff" }}
              >
                {count}
              </span>
            )}
          </Link>
          {user && (
            <>
              <Link to="/liked" className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 transition hover:bg-black/10">
                <Heart size={16} /> Sevimlilar
              </Link>
              <Link to="/orders" className="rounded-lg px-3 py-1.5 transition hover:bg-black/10">
                Buyurtmalarim
              </Link>
            </>
          )}
          {user ? (
            <button onClick={logout} className="rounded-lg px-3 py-1.5 transition hover:bg-black/10">
              Chiqish
            </button>
          ) : (
            <>
              <Link to="/login" className="rounded-lg px-3 py-1.5 transition hover:bg-black/10">
                Kirish
              </Link>
              <Link
                to="/register"
                className="ml-1 rounded-lg px-3 py-1.5 font-medium transition"
                style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
              >
                Ro'yxatdan o'tish
              </Link>
            </>
          )}
          <ThemeSwitch dark={dark} onToggle={toggle} surface />
        </nav>
      </header>
      {children}
    </>
  );
}

export default function App() {
  const location = useLocation();

  // Mustaqil 3D-viewer havolasi — qaysi subdomen (portal)dan ochilishidan qat'i
  // nazar, portal chrome'siz to'g'ridan-to'g'ri ko'rsatiladi (bazissoft.ru uslubida).
  if (location.pathname.startsWith("/viewer/")) {
    return (
      <Routes>
        <Route path="/viewer/:token" element={<Viewer />} />
      </Routes>
    );
  }

  if (PORTAL === "admin")
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <Protected roles={["platform_admin"]}>
              <PortalLayout title="Platforma boshqaruvi" menu={ADMIN_MENU} />
            </Protected>
          }
        >
          <Route path="/" element={<AdminDashboard />} />
          <Route path="/companies" element={<AdminCompanies />} />
          <Route path="/users" element={<AdminUsers />} />
          <Route path="/categories" element={<AdminCategories />} />
          <Route path="/orders" element={<AdminOrders />} />
          <Route path="/finance" element={<Soon label="Moliya" />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );

  if (PORTAL === "firma")
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route
          element={
            <Protected roles={["company_owner", "employee"]}>
              <FirmaShell />
            </Protected>
          }
        >
          <Route path="/" element={<FirmaDashboard />} />
          <Route path="/products" element={<FirmaProducts />} />
          <Route path="/leads" element={<FirmaLeads />} />
          <Route path="/employees" element={<Employees />} />
          <Route path="/orders" element={<FirmaOrders />} />
          <Route path="/production" element={<FirmaProduction />} />
          <Route path="/payroll" element={<FirmaPayroll />} />
          <Route path="/settings" element={<FirmaSettings />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );

  return (
    <MarketLayout>
      <Routes>
        <Route path="/" element={<Catalog />} />
        <Route path="/products/:id" element={<ProductDetail />} />
        <Route path="/shop/:slug" element={<Shop />} />
        <Route path="/cart" element={<Cart />} />
        <Route
          path="/liked"
          element={
            <Protected>
              <Liked />
            </Protected>
          }
        />
        <Route
          path="/orders"
          element={
            <Protected>
              <MyOrders />
            </Protected>
          }
        />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </MarketLayout>
  );
}
