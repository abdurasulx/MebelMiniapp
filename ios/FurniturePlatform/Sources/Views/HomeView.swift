import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case popular = "Ommabop"
    case top = "Top tovarlar"
    case priceLow = "Arzon avval"
    case priceHigh = "Qimmat avval"
    case nameAZ = "Nomi (A-Z)"
    var id: String { rawValue }

    /// Ekranda ko'rsatiladigan matn — `rawValue` (identifikator sifatida
    /// ishlatiladi) o'zbekchada qotib qoladi, faqat shu funksiya orqali
    /// tarjima qilinadi.
    @MainActor
    func label(_ locale: LocaleStore) -> String {
        switch self {
        case .popular: return locale.t("home_sort_popular")
        case .top: return locale.t("home_top_products")
        case .priceLow: return locale.t("home_sort_price_low")
        case .priceHigh: return locale.t("home_sort_price_high")
        case .nameAZ: return locale.t("home_sort_name_az")
        }
    }
}

/// Bosh sahifa — endi alohida "Katalog" tabi yo'q, bu ekranning o'zi
/// katalog vazifasini bajaradi: qidiruv (nom yoki rasm bo'yicha), viloyat/
/// saralash/AR filtri, kategoriya bo'yicha filtr, kolleksiyalar/ommabop
/// mahsulotlar bannerlari va to'liq mahsulotlar to'ri — bittagina umumiy
/// holat (`products`/`categories`/filtrlar) asosida, ikkita alohida
/// so'rov/state o'rniga (avval `ShopView` alohida tab bo'lib, xuddi shu
/// `/products/` so'rovini ikkinchi marta, o'z holati bilan yuklardi).
///
/// Bu ekran doim mounted holatda qoladi (qarang RootView'dagi izoh —
/// `mainTabs` hech qachon if/else bilan yo'q qilinmaydi), shuning uchun
/// qidiruv/filtr/scroll holati va yuklangan ro'yxat boshqa tabga o'tib
/// qaytganda ham saqlanib qoladi, qayta yuklanmaydi.
struct HomeView: View {
    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var location: LocationStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var products: [Product] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false

    @State private var query = ""
    @State private var selectedCategory: String?
    @State private var sort: SortOption = .popular
    @State private var onlyWithAR = false
    @State private var showFilters = false
    @State private var showViloyatPicker = false

    @State private var imageResults: [Product]?
    @State private var isImageSearching = false
    @State private var imageSearchError: String?
    @State private var didLoadOnce = false

    /// Server tomonidan allaqachon olingan `products`ning o'zidan mijoz
    /// tomonida filtrlanadi/saralanadi (bitta so'rov, bitta ro'yxat —
    /// ikkita alohida holat emas). `.top` saralash — serverga
    /// `?ordering=top` bilan qayta so'raladi (qarang `load()`), shuning
    /// uchun bu yerda qayta saralanmaydi.
    private var filtered: [Product] {
        if let imageResults { return imageResults }
        var list = products
        if let selectedCategory {
            list = list.filter { $0.category == selectedCategory }
        }
        if onlyWithAR {
            list = list.filter { p in p.model3d?.glbUrl != nil }
        }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = query.lowercased()
            list = list.filter { $0.nameUz.lowercased().contains(q) || $0.companyName.lowercased().contains(q) }
        }
        switch sort {
        case .popular, .top:
            break
        case .priceLow:
            list.sort { ($0.variants.first?.basePriceValue ?? 0) < ($1.variants.first?.basePriceValue ?? 0) }
        case .priceHigh:
            list.sort { ($0.variants.first?.basePriceValue ?? 0) > ($1.variants.first?.basePriceValue ?? 0) }
        case .nameAZ:
            list.sort { $0.nameUz.localizedCaseInsensitiveCompare($1.nameUz) == .orderedAscending }
        }
        return list
    }

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedCategory != nil
            || onlyWithAR
            || imageResults != nil
            || isImageSearching
    }

    var body: some View {
        NavigationStack {
            if isOffline && products.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
                    .navigationBarHidden(true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        searchBar
                        toolbarRow

                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
                        }
                        if let imageSearchError {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(imageSearchError).foregroundStyle(.red)
                                Button(locale.t("common_close")) { self.imageSearchError = nil }
                            }
                            .padding(.horizontal)
                        }

                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            if !isFiltering {
                                if !categories.isEmpty {
                                    sectionHeader(locale.t("home_collections"), subtitle: locale.t("home_collections_subtitle"))
                                    collectionsRow
                                }
                                if !products.isEmpty {
                                    sectionHeader(locale.t("home_featured"), subtitle: locale.t("home_featured_subtitle"))
                                    featuredRow
                                }
                                sectionHeader(locale.t("home_all_products"), subtitle: "\(filtered.count)\(locale.t("home_products_suffix"))")
                            }
                            productsGrid
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                .task {
                    guard !didLoadOnce else { return }
                    didLoadOnce = true
                    await load()
                }
                .refreshable { await load() }
                .onChange(of: sort) { _, _ in Task { await load() } }
                .onChange(of: location.viloyat) { _, _ in Task { await load() } }
                .sheet(isPresented: $showFilters) { filterSheet }
                .confirmationDialog(locale.t("home_viloyat_title"), isPresented: $showViloyatPicker, titleVisibility: .visible) {
                    Button(locale.t("home_viloyat_all")) { location.setViloyat(nil) }
                    Button("📍 \(locale.t("home_gps_detect"))") { location.detectFromGps() }
                    ForEach(viloyatlar) { v in
                        Button(v.label) { location.setViloyat(v.code) }
                    }
                }
            }
        }
    }

    // MARK: - Qidiruv / filtrlar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(locale.t("catalog_search_hint"), text: $query)
                    .textInputAutocapitalization(.never)
                    .onChange(of: query) { _, newValue in
                        if !newValue.isEmpty { imageResults = nil }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("clearSearchButton")
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

    private var toolbarRow: some View {
        HStack(spacing: 8) {
            viloyatChip
            Spacer()
            if imageResults == nil {
                sortMenu
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: onlyWithAR ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(onlyWithAR ? Color.brandDeep : .primary)
                }
            }
        }
        .padding(.horizontal)
    }

    private var viloyatChip: some View {
        Button {
            showViloyatPicker = true
        } label: {
            HStack(spacing: 6) {
                if location.status == .loading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "mappin.circle.fill")
                }
                Text(location.viloyatLabelText).font(.caption).bold()
                Image(systemName: "chevron.down").font(.caption2)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(.secondarySystemBackground))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    sort = option
                } label: {
                    if sort == option {
                        Label(option.label(locale), systemImage: "checkmark")
                    } else {
                        Text(option.label(locale))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sort.label(locale)).font(.caption).bold()
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(Color.brandSecondary)
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section(locale.t("home_filters_extra")) {
                    Toggle("🧊 \(locale.t("home_filter_ar_only"))", isOn: $onlyWithAR)
                }
            }
            .navigationTitle(locale.t("home_filters_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(locale.t("common_done")) { showFilters = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func backToHome() {
        query = ""
        selectedCategory = nil
        onlyWithAR = false
        imageResults = nil
        imageSearchError = nil
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

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3).bold()
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var collectionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(categories) { cat in
                    let isSelected = selectedCategory == cat.id
                    Button {
                        selectedCategory = isSelected ? nil : cat.id
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.brandDeep : Color.brandPrimary.opacity(0.28))
                                    .frame(width: 76, height: 76)
                                Image(systemName: "sofa.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(isSelected ? Color.brandPrimary : Color.brandDeep)
                            }
                            Text(cat.nameUz)
                                .font(.caption).bold()
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 92)
                        }
                    }
                    .buttonStyle(.plain)
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

                        LikeButton(productId: product.id, product: product)
                            .padding(6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var productsGrid: some View {
        if isImageSearching {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        } else if isFiltering {
            HStack(spacing: 8) {
                Button {
                    backToHome()
                } label: {
                    Image(systemName: "arrow.left").foregroundStyle(Color.brandDeep)
                }
                .accessibilityLabel(locale.t("home_back_tooltip"))
                Text(
                    imageResults != nil
                        ? "\(filtered.count)\(locale.t("home_similar_suffix"))"
                        : "\(filtered.count)\(locale.t("home_results_suffix"))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            productsGridContent
        } else {
            productsGridContent
        }
    }

    @ViewBuilder
    private var productsGridContent: some View {
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                Text(locale.t("home_nothing_found")).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                ForEach(filtered) { product in
                    // LikeButton `NavigationLink`ning label'i ICHIDA emas, sibling
                    // sifatida joylashtiriladi — aks holda yurakchaga bosish, tugma
                    // o'z harakatini bajarish o'rniga, navigatsiyani ishga tushirib
                    // yuboradi (SwiftUI: Button ichidagi NavigationLink taplarni
                    // yutib yuboradigan holat).
                    ZStack(alignment: .topTrailing) {
                        NavigationLink(destination: ProductDetailView(productId: product.id)) {
                            FeaturedGridCard(product: product)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 6) {
                            if product.model3d?.glbUrl != nil {
                                ARBadge()
                            }
                            LikeButton(productId: product.id, product: product)
                        }
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
        isOffline = false
        var params: [String] = []
        if let lat = location.lat, let lng = location.lng {
            params.append("lat=\(lat)")
            params.append("lng=\(lng)")
        } else if let viloyat = location.viloyat {
            params.append("viloyat=\(viloyat)")
        }
        if sort == .top {
            params.append("ordering=top")
        }
        let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        async let productsResult: Paginated<Product> = APIClient.shared.get("/products/\(query)", auth: true)
        async let categoriesResult: Paginated<Category> = APIClient.shared.get("/categories/")
        do {
            let (p, c) = try await (productsResult, categoriesResult)
            products = p.results
            categories = c.results
            likes.sync(from: p.results)
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
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
            if let attributeSummary = product.attributeSummary {
                Text(attributeSummary).font(.caption2).bold().foregroundStyle(Color.brandDeep).lineLimit(1)
            }
            if let first = product.variants.first {
                Text("\(first.basePrice.formattedSom) so'm/m³")
                    .font(.caption).bold().lineLimit(1)
                    .foregroundStyle(Color.brandSecondary)
            }
        }
        .frame(width: 160)
    }
}

/// Grid'da ishlatiladigan kartochka (2 ustunli, markazlashtirilgan matn).
struct FeaturedGridCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
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

            Text(product.nameUz).font(.subheadline).bold().lineLimit(1).multilineTextAlignment(.center)
            if let attributeSummary = product.attributeSummary {
                Text(attributeSummary).font(.caption2).bold().foregroundStyle(Color.brandDeep).lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            Text(product.companyName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .multilineTextAlignment(.center)
            if let first = product.variants.first {
                Text("\(first.basePrice.formattedSom) so'm/m³ dan")
                    .font(.caption).bold().lineLimit(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.brandSecondary)
            }
        }
        .padding(.leading, 4)
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
