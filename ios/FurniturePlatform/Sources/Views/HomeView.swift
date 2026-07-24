import SwiftUI

/// Bosh sahifa — yirik marketplace uslubidagi landing (hero banner + kolleksiyalar +
/// ommabop mahsulotlar), Shopify "Plank" mavzusiga mos.
struct HomeView: View {
    @EnvironmentObject private var likes: LikesStore
    @State private var products: [Product] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        if !categories.isEmpty {
                            sectionHeader("Kolleksiyalar", subtitle: "Har xona uchun")
                            collectionsRow
                        }

                        if !products.isEmpty {
                            sectionHeader("Ommabop mahsulotlar", subtitle: "Eng ko'p tanlangan")
                            featuredRow
                        }

                        banner
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.brandDeep, Color.brandDeep.opacity(0.75), Color.brandPrimary.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 340)

            VStack(alignment: .leading, spacing: 14) {
                Text("MINIMAL VA FUNKSIONAL")
                    .font(.caption).bold()
                    .tracking(1.5)
                    .foregroundStyle(Color.brandPrimary)

                Text("Uyingizga\nqulaylik va hashamat")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("O'zbekistonning eng yaxshi mebel ustalari.\nO'lchamingizga mos dizayn, uyingizga yetkazib berish.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                NavigationLink(destination: ShopView()) {
                    HStack(spacing: 6) {
                        Text("Xarid qilish").bold()
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.brandPrimary)
                    .foregroundStyle(Color.brandDeep)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .frame(height: 340)
        .clipped()
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink("Hammasi", destination: ShopView())
                .font(.caption).bold()
                .foregroundStyle(Color.brandSecondary)
        }
        .padding(.horizontal)
    }

    private var collectionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(categories) { cat in
                    NavigationLink(destination: ShopView(initialCategory: cat)) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.brandPrimary.opacity(0.28))
                                    .frame(width: 76, height: 76)
                                Image(systemName: "sofa.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(Color.brandDeep)
                            }
                            Text(cat.nameUz)
                                .font(.caption).bold()
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 92)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var featuredRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(products.prefix(10)) { product in
                    // LikeButton `NavigationLink`ning label'i ICHIDA emas, sibling
                    // sifatida joylashtiriladi — aks holda yurakchaga bosish, tugma
                    // o'z harakatini bajarish o'rniga, navigatsiyani ishga tushirib
                    // yuboradi.
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(destination: ProductDetailView(productId: product.id)) {
                            FeaturedProductCard(product: product)
                        }
                        .buttonStyle(.plain)

                        LikeButton(productId: product.id)
                            .padding(6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var banner: some View {
        NavigationLink(destination: ShopView()) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.brandPrimary.opacity(0.3))
                VStack(alignment: .leading, spacing: 6) {
                    Text("🧊 AR bilan sinab ko'ring").font(.headline)
                    Text("Xonangizga real o'lchamda joylashtiring — sotib olishdan oldin ko'zingiz bilan ko'ring.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 260, alignment: .leading)
                }
                .padding(20)
            }
            .frame(height: 120)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        async let productsResult: Paginated<Product> = APIClient.shared.get("/products/", auth: true)
        async let categoriesResult: Paginated<Category> = APIClient.shared.get("/categories/")
        do {
            let (p, c) = try await (productsResult, categoriesResult)
            products = p.results
            categories = c.results
            likes.sync(from: p.results)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct FeaturedProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.brandPrimary.opacity(0.3)
                }
            }
            .frame(width: 160, height: 130)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(product.nameUz).font(.subheadline).bold().lineLimit(1)
            if let first = product.variants.first {
                Text("\(first.basePrice.formattedSom) so'm/m³")
                    .font(.caption).bold()
                    .foregroundStyle(Color.brandSecondary)
            }
        }
        .frame(width: 160)
    }
}

struct ARBadge: View {
    var body: some View {
        Text("🧊 AR")
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
            .clipShape(Capsule())
    }
}
