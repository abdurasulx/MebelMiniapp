import SwiftUI

/// Katalog hammaga ochiq (web'dagi kabi); buyurtma berishda login talab qilinadi.
/// To'rt bo'lim: Bosh sahifa (landing, "Plank" uslubi) — Katalog (do'kon, "Darix" uslubi)
/// — Sevimlilar (serverda saqlangan) — Profil.
struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var cart: CartStore

    var body: some View {
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
