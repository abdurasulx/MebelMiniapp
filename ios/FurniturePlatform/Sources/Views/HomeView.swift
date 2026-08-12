import SwiftUI

/// Bosh sahifa — kolleksiyalar + ommabop mahsulotlar + qidiruv (nom yoki
/// rasm bo'yicha). Brend hero matni endi `SplashScreenView`da — bu yerda
/// bekorchi turmasin deb olib tashlandi, "AR bilan sinab ko'ring" banneri
/// ham (foydasiz qo'shimcha reklama sifatida) olib tashlandi.
struct HomeView: View {
    @EnvironmentObject private var likes: LikesStore
    @State private var products: [Product] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var query = ""
    @State private var imageResults: [Product]?
    @State private var isImageSearching = false
    @State private var imageSearchError: String?

    private var nameMatches: [Product] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let q = query.lowercased()
        return products.filter { $0.nameUz.lowercased().contains(q) || $0.companyName.lowercased().contains(q) }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty || imageResults != nil || isImageSearching
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    searchBar

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if isSearching {
                        searchResultsSection
                    } else {
                        if !categories.isEmpty {
                            sectionHeader("Kolleksiyalar", subtitle: "Har xona uchun")
                            collectionsRow
                        }

                        if !products.isEmpty {
                            sectionHeader("Ommabop mahsulotlar", subtitle: "Eng ko'p tanlangan")
                            featuredRow
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Qidiruv

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Mahsulot yoki firma qidirish…", text: $query)
                    .textInputAutocapitalization(.never)
                    .onChange(of: query) { _, newValue in
                        if !newValue.isEmpty { imageResults = nil }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            ImageSearchButton { data in
                Task { await searchByImage(data) }
            }
        }
        .padding(.horizontal)
    }

    private func searchByImage(_ data: Data) async {
        isImageSearching = true
        imageSearchError = nil
        imageResults = nil
        query = ""
        do {
            let results: [Product] = try await APIClient.shared.postMultipartImage(
                "/products/search-by-image/",
                imageData: data
            )
            imageResults = results
        } catch {
            imageSearchError = error.localizedDescription
        }
        isImageSearching = false
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if isImageSearching {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        } else if let imageSearchError {
            VStack(alignment: .leading, spacing: 6) {
                Text(imageSearchError).foregroundStyle(.red)
                Button("Yopish") { self.imageSearchError = nil }
            }
            .padding(.horizontal)
        } else {
            let items = imageResults ?? nameMatches
            HStack {
                Text(
                    imageResults != nil
                        ? "\(items.count) ta o'xshash mahsulot"
                        : "\(items.count) ta natija"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                if imageResults != nil {
                    Button("Tozalash") { imageResults = nil }
                        .font(.caption).bold()
                }
            }
            .padding(.horizontal)

            if items.isEmpty {
                Text("Hech narsa topilmadi.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(items) { product in
                        ZStack(alignment: .topTrailing) {
                            NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                FeaturedGridCard(product: product)
                            }
                            .buttonStyle(.plain)
                            LikeButton(productId: product.id).padding(6)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
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

/// Qidiruv natijalari to'rida ishlatiladigan kartochka (2 ustunli grid).
struct FeaturedGridCard: View {
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
            Text(product.companyName).font(.caption).foregroundStyle(.secondary)
            if let first = product.variants.first {
                Text("\(first.basePrice.formattedSom) so'm/m³ dan")
                    .font(.caption).bold()
                    .foregroundStyle(Color.brandSecondary)
            }
        }
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
