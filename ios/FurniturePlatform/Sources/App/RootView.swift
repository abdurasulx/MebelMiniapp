import SwiftUI

/// Katalog hammaga ochiq (web'dagi kabi); buyurtma berishda login talab qilinadi.
/// To'rt bo'lim: Bosh sahifa (endi katalog vazifasini ham bajaradi, qarang
/// HomeView) — Sevimlilar (serverda saqlangan) — Savat — Profil.
struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var connectivity: ConnectivityStore
    @EnvironmentObject private var locale: LocaleStore
    @EnvironmentObject private var appVersion: AppVersionStore
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .task {
                        // Versiya tekshiruvi splash bilan parallel; asosiy UI
                        // undan oldin ochilmaydi (xato bo'lsa bloklamaydi).
                        async let check: Void = appVersion.checkOnStartup()
                        try? await Task.sleep(nanoseconds: 1_300_000_000)
                        await check
                        withAnimation { showSplash = false }
                    }
            } else {
                // `mainTabs` doim daraxtda qoladi (hech qachon yo'q
                // qilinmaydi) — oflaynda `OfflineView` faqat USTIDAN
                // qoplanadi. Ilgari bu `if/else` bilan almashtirilardi,
                // natijada har safar oflayn holati tebransa (masalan bitta
                // sekin so'rov tufayli), barcha tablarning keshlangan
                // holati yo'qolib, ulanish tiklanganda hammasi qaytadan
                // "Loading..." holatidan boshlanardi.
                ZStack {
                    mainTabs
                    if connectivity.isOffline {
                        OfflineView(onRetry: connectivity.retry)
                            .background(Color(uiColor: .systemBackground))
                    }
                }
            }
        }
        .overlay {
            if appVersion.forcedPolicy != nil {
                ForceUpdateView().transition(.opacity)
            }
        }
        .alert(
            locale.t("update_available_title") + (appVersion.optionalUpdateVersion.map { ": \($0)" } ?? ""),
            isPresented: Binding(
                get: { appVersion.optionalUpdateVersion != nil },
                set: { if !$0 { appVersion.optionalUpdateVersion = nil } }
            )
        ) {
            Button(locale.t("update_later"), role: .cancel) {}
            Button(locale.t("update_button")) { _ = appVersion.openStore() }
        }
    }

    private var mainTabs: some View {
        TabView {
            if auth.appMode == .worker, let slug = auth.user?.company?.slug {
                WorkerHomeView()
                    .appScreenBackground()
                    .tabItem { Label(locale.t("worker_panel_tab"), systemImage: "hammer.fill") }

                NavigationStack {
                    LoyihalarimView(companySlug: slug)
                }
                .tabItem { Label(locale.t("tab_projects"), systemImage: "arkit") }

                WorkerOrdersView()
                    .appScreenBackground()
                    .tabItem { Label(locale.t("worker_orders_tab"), systemImage: "list.bullet.clipboard.fill") }
            } else {
                HomeView()
                    .appScreenBackground()
                    .tabItem { Label(locale.t("nav_home"), systemImage: "house.fill") }

                LikesView()
                    .appScreenBackground()
                    .tabItem { Label(locale.t("nav_likes"), systemImage: "heart.fill") }

                CartView()
                    .appScreenBackground()
                    .tabItem { Label(locale.t("nav_cart"), systemImage: "cart.fill") }
                    .badge(cart.count)
            }

            AccountView()
                .appScreenBackground()
                .tabItem { Label(locale.t("nav_profile"), systemImage: "person.circle") }
        }
        .tint(Color.brand)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.appCard, for: .tabBar)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated { likes.clear() }
        }
    }
}
