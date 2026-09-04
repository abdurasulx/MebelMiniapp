import { useState } from "react";
import { Link, NavLink, Navigate, Route, Routes, useLocation } from "react-router-dom";
import { useAuth } from "./auth";
import PortalLayout from "./layouts/PortalLayout";
import { BRAND_NAME, PORTAL, portalURLFor } from "./portal";
import { getActivePosition, setActivePosition } from "./positions";
import RolePicker from "./pages/firma/RolePicker";
import { useTheme } from "./theme";
import AdminCategories from "./pages/admin/AdminCategories";
import AdminCompanies from "./pages/admin/AdminCompanies";
import AdminDashboard from "./pages/admin/AdminDashboard";
import AdminFinance from "./pages/admin/AdminFinance";
import AdminOrders from "./pages/admin/AdminOrders";
import AdminTariffPlans from "./pages/admin/AdminTariffPlans";
import AdminUsers from "./pages/admin/AdminUsers";
import Cart from "./pages/Cart";
import Catalog from "./pages/Catalog";
import CompleteRegistration from "./pages/CompleteRegistration";
import Liked from "./pages/Liked";
import Employees from "./pages/Employees";
import FirmaDashboard from "./pages/firma/FirmaDashboard";
import FirmaLeads from "./pages/firma/FirmaLeads";
import FirmaOrders from "./pages/firma/FirmaOrders";
import FirmaOrderDetail from "./pages/firma/FirmaOrderDetail";
import FirmaPayroll from "./pages/firma/FirmaPayroll";
import FirmaPayStandards from "./pages/firma/FirmaPayStandards";
import FirmaProduction from "./pages/firma/FirmaProduction";
import FirmaProductDetail from "./pages/firma/FirmaProductDetail";
import FirmaProducts from "./pages/firma/FirmaProducts";
import FirmaSettings from "./pages/firma/FirmaSettings";
import FirmaSiteSurveys from "./pages/firma/FirmaSiteSurveys";
import FirmaSuppliers from "./pages/firma/FirmaSuppliers";
import FirmaWarehouses from "./pages/firma/FirmaWarehouses";
import FirmaWarehouseDetail from "./pages/firma/FirmaWarehouseDetail";
import Login from "./pages/Login";
import MyOrders from "./pages/MyOrders";
import MyProjects from "./pages/MyProjects";
import ProductDetail from "./pages/ProductDetail";
import Profile from "./pages/Profile";
import ProjectComposer from "./pages/ProjectComposer";
import ProjectViewer from "./pages/ProjectViewer";
import Shop from "./pages/Shop";
import Viewer from "./pages/Viewer";
import ThemeSwitch from "./components/ThemeSwitch";
import NotificationBell from "./components/NotificationBell";
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
  FolderKanban,
  Warehouse,
  TrendingUp,
  Truck,
  UserCircle,
  Banknote,
  MapPinned,
} from "lucide-react";

const ADMIN_MENU = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true, group: "Asosiy" },
  { to: "/companies", icon: Factory, label: "Kompaniyalar", group: "Boshqaruv" },
  { to: "/users", icon: Users, label: "Foydalanuvchilar", group: "Boshqaruv" },
  { to: "/categories", icon: FolderTree, label: "Kategoriyalar", group: "Boshqaruv" },
  { to: "/tariff-plans", icon: Banknote, label: "Tarif rejalari", group: "Boshqaruv" },
  { to: "/orders", icon: Package, label: "Buyurtmalar", group: "Savdo" },
  { to: "/finance", icon: Wallet, label: "Moliya", group: "Savdo" },
];

const FIRMA_MENU = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true, group: "Asosiy" },
  { to: "/products", icon: Sofa, label: "Mahsulotlar", group: "Katalog" },
  { to: "/leads", icon: Target, label: "Leadlar (CRM)", group: "Savdo" },
  { to: "/orders", icon: Package, label: "Buyurtmalar", group: "Savdo" },
  { to: "/site-surveys", icon: MapPinned, label: "Joy o'rganish", group: "Ishlab chiqarish" },
  { to: "/production", icon: Hammer, label: "Ishlab chiqarish", group: "Ishlab chiqarish" },
  { to: "/warehouses", icon: Warehouse, label: "Omborlar", group: "Ishlab chiqarish" },
  { to: "/suppliers", icon: Truck, label: "Ta'minot", group: "Ishlab chiqarish" },
  { to: "/employees", icon: HardHat, label: "Xodimlar", group: "Xodimlar" },
  { to: "/payroll", icon: Wallet, label: "Ish haqi", group: "Xodimlar" },
  { to: "/pay-standards", icon: HardHat, label: "Ish haqi standartlari", group: "Xodimlar" },
  { to: "/finance", icon: TrendingUp, label: "Moliya", group: "Savdo" },
  { to: "/settings", icon: Settings, label: "Sozlamalar", group: "Tizim" },
];

// Xodim (usta) uchun — faqat o'z ishiga tegishli bo'limlar. Xodimlar/Ish
// haqi/Moliya/Sozlamalar/Omborlar/Ta'minot firma egasi darajasidagi
// boshqaruv bo'limlari (maosh, moliya, kompaniya sozlamalari) — xodimga
// ko'rsatilmasligi kerak (backend'da ham shunga mos cheklov qo'yilgan,
// qarang apps/companies/views.py::EmployeeViewSet.get_queryset).
const EMPLOYEE_FIRMA_MENU = FIRMA_MENU.filter((m) =>
  ["/", "/orders", "/site-surveys", "/production"].includes(m.to)
);

// Firma egasi darajasidagi bo'limlar (xodimlar/maosh/moliya/sozlamalar/
// omborlar/ta'minot) — menyudan yashirilgan, lekin to'g'ridan-to'g'ri URL
// kiritilsa ham xodim ko'rmasligi kerak (backend baribir bloklaydi, bu esa
// shunchaki chalkash bo'sh/xato sahifa o'rniga toza yo'naltirish beradi).
function OwnerOnly({ children }) {
  const { user } = useAuth();
  if (user?.role === "employee") return <Navigate to="/" replace />;
  return children;
}

function Protected({ children, roles }) {
  const { user, loading, logout } = useAuth();
  if (loading) return <div className="p-8" style={{ color: "var(--muted)" }}>Yuklanmoqda…</div>;
  if (!user) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user.role)) {
    const marketURL = portalURLFor("market");
    return (
      <div className="flex min-h-[70vh] items-center justify-center p-4">
        <div className="card flex w-full max-w-sm flex-col items-center gap-3 p-8 text-center">
          <div
            className="flex h-14 w-14 items-center justify-center rounded-full"
            style={{ background: "color-mix(in srgb, var(--primary) 20%, transparent)" }}
          >
            <HardHat size={26} style={{ color: "var(--secondary)" }} />
          </div>
          <h1 className="text-lg font-bold">Kirish faqat xodimlarga</h1>
          <p className="text-sm" style={{ color: "var(--muted)" }}>
            Bu bo'lim faqat firma egasi va xodimlari uchun. Sizning hisobingiz ({user.email}) mijoz sifatida ro'yxatdan o'tgan.
          </p>
          <div className="flex w-full flex-col gap-2">
            {marketURL && (
              <a className="btn btn-brand w-full" href={marketURL}>
                Asosiy saytga o'tish
              </a>
            )}
            <button className="btn w-full" onClick={logout}>
              Chiqish
            </button>
          </div>
        </div>
      </div>
    );
  }
  return children;
}

/** Firma portali: faqat multi-role xodim rolini tanlaydi — bitta kasbi
 * bo'lsa, RolePicker'ni ko'rsatmasdan to'g'ridan-to'g'ri o'sha rol bilan
 * kiritiladi (tanlov keraksiz, bitta variant bo'lgani uchun). */
function FirmaShell() {
  const { user } = useAuth();
  const [active, setActive] = useState(getActivePosition());

  if (user.role === "employee" && user.positions?.length > 0) {
    if (user.positions.length === 1 && active !== user.positions[0]) {
      setActivePosition(user.positions[0]);
      setActive(user.positions[0]);
    } else {
      const valid = active && user.positions.includes(active);
      if (!valid) return <RolePicker onPicked={setActive} />;
    }
  }
  return (
    <PortalLayout
      title="Firma kabineti"
      menu={user.role === "employee" ? EMPLOYEE_FIRMA_MENU : FIRMA_MENU}
      activePosition={user.role === "employee" ? active : null}
      onSwitchPosition={setActive}
      showNotifications
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
          <Sofa size={22} /> {BRAND_NAME}
        </Link>
        <nav className="flex items-center gap-1 text-sm">
          <NavLink to="/" end className={({ isActive }) => `top-link ${isActive ? "active" : ""}`}>
            Katalog
          </NavLink>
          <NavLink to="/cart" className={({ isActive }) => `top-link relative flex items-center ${isActive ? "active" : ""}`}>
            <ShoppingBasket size={18} />
            {count > 0 && (
              <span
                className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[10px] font-bold"
                style={{ background: "var(--danger)", color: "#fff" }}
              >
                {count}
              </span>
            )}
          </NavLink>
          {user && (
            <>
              <NavLink to="/liked" className={({ isActive }) => `top-link flex items-center gap-1.5 ${isActive ? "active" : ""}`}>
                <Heart size={16} /> Sevimlilar
              </NavLink>
              <NavLink to="/projects" className={({ isActive }) => `top-link flex items-center gap-1.5 ${isActive ? "active" : ""}`}>
                <FolderKanban size={16} /> Loyihalarim
              </NavLink>
              <NavLink to="/orders" className={({ isActive }) => `top-link ${isActive ? "active" : ""}`}>
                Buyurtmalarim
              </NavLink>
              <NavLink to="/profile" className={({ isActive }) => `top-link flex items-center gap-1.5 ${isActive ? "active" : ""}`}>
                <UserCircle size={16} /> Profil
              </NavLink>
              <NotificationBell surface />
            </>
          )}
          {user ? (
            <button onClick={logout} className="rounded-lg px-3 py-1.5 transition hover:bg-black/10">
              Chiqish
            </button>
          ) : (
            <Link
              to="/login"
              className="ml-1 rounded-lg px-3 py-1.5 font-medium transition"
              style={{ background: "var(--brand-cta-bg)", color: "var(--brand-cta-text)" }}
            >
              Kirish
            </Link>
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
  const { user, loading } = useAuth();

  // Mustaqil 3D-viewer havolasi — qaysi subdomen (portal)dan ochilishidan qat'i
  // nazar, portal chrome'siz to'g'ridan-to'g'ri ko'rsatiladi (bazissoft.ru uslubida).
  if (location.pathname.startsWith("/viewer/")) {
    return (
      <Routes>
        <Route path="/viewer/project/:token" element={<ProjectViewer />} />
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
          <Route path="/tariff-plans" element={<AdminTariffPlans />} />
          <Route path="/orders" element={<AdminOrders />} />
          <Route path="/finance" element={<AdminFinance />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );

  if (PORTAL === "firma")
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <Protected roles={["company_owner", "employee"]}>
              <FirmaShell />
            </Protected>
          }
        >
          <Route path="/" element={<FirmaDashboard />} />
          <Route path="/products" element={<FirmaProducts />} />
          <Route path="/products/:id" element={<FirmaProductDetail />} />
          <Route path="/leads" element={<FirmaLeads />} />
          <Route path="/employees" element={<OwnerOnly><Employees /></OwnerOnly>} />
          <Route path="/orders" element={<FirmaOrders />} />
          <Route path="/orders/:id" element={<FirmaOrderDetail />} />
          <Route path="/site-surveys" element={<FirmaSiteSurveys />} />
          <Route path="/production" element={<FirmaProduction />} />
          <Route path="/warehouses" element={<OwnerOnly><FirmaWarehouses /></OwnerOnly>} />
          <Route path="/warehouses/:id" element={<OwnerOnly><FirmaWarehouseDetail /></OwnerOnly>} />
          <Route path="/suppliers" element={<OwnerOnly><FirmaSuppliers /></OwnerOnly>} />
          <Route path="/payroll" element={<OwnerOnly><FirmaPayroll /></OwnerOnly>} />
          <Route path="/pay-standards" element={<OwnerOnly><FirmaPayStandards /></OwnerOnly>} />
          <Route path="/finance" element={<OwnerOnly><AdminFinance /></OwnerOnly>} />
          <Route path="/settings" element={<OwnerOnly><FirmaSettings /></OwnerOnly>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    );

  // Google/Telegram orqali yangi hisob ochilgan-u, hali rol/profil
  // to'ldirilmagan bo'lsa — qayerga borishga urinmasin, avval shuni
  // yakunlashi kerak (faqat market'da: Google/Telegram tugmalari,
  // demak yangi-hisob holati, faqat shu yerda paydo bo'ladi).
  if (
    !loading &&
    user &&
    !user.registration_completed &&
    location.pathname !== "/complete-registration"
  ) {
    return <Navigate to="/complete-registration" replace />;
  }

  return (
    <MarketLayout>
      <Routes>
        <Route path="/" element={<Catalog />} />
        <Route path="/complete-registration" element={<CompleteRegistration />} />
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
        <Route
          path="/profile"
          element={
            <Protected>
              <Profile />
            </Protected>
          }
        />
        <Route
          path="/projects"
          element={
            <Protected>
              <MyProjects />
            </Protected>
          }
        />
        <Route
          path="/projects/:id"
          element={
            <Protected>
              <ProjectComposer />
            </Protected>
          }
        />
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </MarketLayout>
  );
}
