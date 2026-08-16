import SwiftUI

/// "Sevimlilar" — marketplace'lardagi kabi, serverda saqlangan sevimli mahsulotlar
/// ro'yxati (qaysi qurilmadan kirsa ham bir xil).
struct LikesView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @State private var items: [Like] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isAuthenticated {
                    ContentUnavailableCompat(
                        icon: "heart",
                        title: "Sevimlilar uchun kiring",
                        message: "Yoqqan mahsulotlaringizni saqlash uchun Profil bo'limidan tizimga kiring."
                    )
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    ContentUnavailableCompat(
                        icon: "heart",
                        title: "Hali sevimli mahsulot yo'q",
                        message: "Katalogdan yoqqan mahsulotni yurakcha bilan belgilang."
                    )
                } else {
                    ScrollView {
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red).padding()
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(items) { like in
                                // LikeButton `NavigationLink`ning label'i ICHIDA emas, sibling
                                // sifatida joylashtiriladi — aks holda yurakchaga bosish, tugma
                                // o'z harakatini bajarish o'rniga, navigatsiyani ishga tushirib
                                // yuboradi (SwiftUI: Button ichidagi NavigationLink taplarni
                                // yutib yuboradigan holat).
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: ProductDetailView(productId: like.product)) {
                                        ShopStyleCard(product: like.productDetail)
                                    }
                                    .buttonStyle(.plain)

                                    LikeButton(productId: like.product) { liked in
                                        if !liked { items.removeAll { $0.id == like.id } }
                                    }
                                    .padding(6)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Sevimlilar")
            .onAppear { Task { await load() } }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard auth.isAuthenticated else { return }
        isLoading = true
        errorMessage = nil
        do {
            let page: Paginated<Like> = try await APIClient.shared.get("/likes/", auth: true)
            items = page.results
            likes.sync(from: page.results.map { $0.productDetail })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ShopStyleCard: View {
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
            .frame(height: 130)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(product.nameUz).font(.subheadline).bold().lineLimit(1)
            if let attributeSummary = product.attributeSummary {
                Text(attributeSummary).font(.caption2).bold().foregroundStyle(Color.brandDeep).lineLimit(1)
            }
            Text(product.companyName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if let first = product.variants.first {
                Text("\(first.basePrice.formattedSom) so'm/m³ dan")
                    .font(.caption).bold().lineLimit(1)
                    .foregroundStyle(Color.brandSecondary)
            }
        }
    }
}

/// iOS 17'dan oldingi ContentUnavailableView o'rniga oddiy versiya (deployment target 18, lekin shu View kichik va qayta ishlatiladi).
struct ContentUnavailableCompat: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
