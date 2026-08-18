import SwiftUI

/// Katalog hammaga ochiq (web'dagi kabi); buyurtma berishda login talab qilinadi.
/// To'rt bo'lim: Bosh sahifa (landing, "Plank" uslubi) — Katalog (do'kon, "Darix" uslubi)
/// — Sevimlilar (serverda saqlangan) — Profil.
struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var connectivity: ConnectivityStore
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
                    .task {
                        try? await Task.sleep(nanoseconds: 1_300_000_000)
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
    }

    private var mainTabs: some View {
        TabView {
            if auth.appMode == .worker && auth.user?.company != nil {
                WorkerHomeView()
                    .tabItem { Label("Usta paneli", systemImage: "hammer.fill") }

                WorkerOrdersView()
                    .tabItem { Label("Buyurtmalar", systemImage: "list.bullet.clipboard.fill") }
            } else {
                HomeView()
                    .tabItem { Label("Bosh sahifa", systemImage: "house.fill") }

                NavigationStack {
                    ShopView()
                }
                .tabItem { Label("Katalog", systemImage: "square.grid.2x2.fill") }

                LikesView()
                    .tabItem { Label("Sevimlilar", systemImage: "heart.fill") }

                CartView()
                    .tabItem { Label("Savat", systemImage: "cart.fill") }
                    .badge(cart.count)
            }

            AccountView()
                .tabItem { Label("Profil", systemImage: "person.circle") }
        }
        .tint(Color.brandDeep)
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated { likes.clear() }
        }
    }
}
