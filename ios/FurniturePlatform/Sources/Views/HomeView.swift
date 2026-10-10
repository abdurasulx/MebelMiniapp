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
/// katalog vazifasini bajaradi: qidiruv (nom yoki rasm bo'yicha),
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
    @EnvironmentObject private var locale: LocaleStore
    @EnvironmentObject private var location: LocationStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showShowcase = false
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
            list.sort { ($0.displayPricing?.finalPrice ?? 0) < ($1.displayPricing?.finalPrice ?? 0) }
        case .priceHigh:
            list.sort { ($0.displayPricing?.finalPrice ?? 0) > ($1.displayPricing?.finalPrice ?? 0) }
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
            if !location.hasFix {
                locationGate
                    .navigationBarHidden(true)
            } else if isOffline && products.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
                    .navigationBarHidden(true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        searchBar
                        toolbarRow

                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(Color.appError).padding(.horizontal)
                        }
                        if let imageSearchError {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(imageSearchError).foregroundStyle(Color.appError)
                                Button(locale.t("common_close")) { self.imageSearchError = nil }
                            }
                            .padding(.horizontal)
                        }

                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        } else if !isFiltering && products.isEmpty && errorMessage == nil {
                            stateMessage(
                                icon: "storefront",
                                title: locale.t("showcase_prompt_title"),
                                body: locale.t("showcase_prompt_body"),
                                actionTitle: locale.t("showcase_prompt_button"),
                                action: { showShowcase = true }
                            )
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
                .background(Color.appBackground)
                .navigationTitle("")
                .navigationDestination(isPresented: $showShowcase) { ShowcaseView() }
                .navigationBarHidden(true)
                .task(id: location.hasFix ? "\(location.lat ?? 0),\(location.lng ?? 0)" : "") {
                    await load()
                }
                .refreshable { await load() }
                .onChange(of: sort) { _, _ in Task { await load() } }
                .sheet(isPresented: $showFilters) { filterSheet }
            }
        }
    }

    // MARK: - Joylashuv

    /// Joylashuv aniqlanmagan / ruxsat yo'q / GPS o'chiq holati — mahsulotlar
    /// firma xizmat radiusiga bog'liq bo'lgani uchun joylashuvsiz ko'rsatilmaydi.
    private var locationGate: some View {
        Group {
            switch location.status {
            case .idle, .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted:
                // Ruxsat bor, koordinata hali kelmayapti.
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .denied, .unavailable:
                let gpsOff = location.status == .unavailable
                stateMessage(
                    icon: "location.slash",
                    title: locale.t(gpsOff ? "loc_gps_off_title" : "loc_required_title"),
                    body: locale.t(gpsOff ? "loc_gps_off_body" : "loc_required_body"),
                    actionTitle: locale.t(location.needsSettings || gpsOff ? "loc_open_settings" : "loc_allow"),
                    action: {
                        if location.needsSettings || gpsOff,
                           let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        } else {
                            location.detectFromGps()
                        }
                    },
                    secondaryTitle: locale.t("loc_retry"),
                    secondary: { location.detectFromGps() }
                )
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Tizim sozlamalaridan ruxsat berib qaytsa — avtomatik qayta aniqlanadi.
            if phase == .active, !location.hasFix, location.status != .loading {
                location.detectFromGps()
            }
        }
    }

    private func stateMessage(
        icon: String, title: String, body: String,
        actionTitle: String? = nil, action: (() -> Void)? = nil,
        secondaryTitle: String? = nil, secondary: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Color.brandDeep)
                .frame(width: 72, height: 72)
                .background(Color.brandPrimary.opacity(0.4))
                .clipShape(Circle())
            Text(title).font(.title3).bold().multilineTextAlignment(.center)
            Text(body).font(.subheadline).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).bold().padding(.horizontal, 24).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandDeep)
                .padding(.top, 8)
            }
            if let secondaryTitle, let secondary {
                Button(secondaryTitle, action: secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Qidiruv / filtrlar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.textSecondary)
                TextField(locale.t("catalog_search_hint"), text: $query)
                    .textInputAutocapitalization(.never)
                    .onChange(of: query) { _, newValue in
                        if !newValue.isEmpty { imageResults = nil }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityIdentifier("clearSearchButton")
                }
            }
            .padding(12)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))

            ImageSearchButton { data in
                Task { await searchByImage(data) }
            }
        }
        .padding(.horizontal)
    }

    private var toolbarRow: some View {
        HStack(spacing: 8) {
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
            var fields: [String: String] = [:]
            if let lat = location.lat, let lng = location.lng {
                fields["lat"] = String(lat)
                fields["lng"] = String(lng)
            }
            let results: [Product] = try await APIClient.shared.postMultipartImage(
                "/products/search-by-image/",
                imageData: data,
                fields: fields
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
                Text(subtitle).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    /// Kategoriya nomi/slug'idagi kalit so'zga qarab SF Symbol (backend'da ikonka maydoni yo'q).
    private func categorySymbol(_ cat: Category) -> String {
        let key = "\(cat.slug) \(cat.nameUz)".lowercased()
        let table: [([String], String)] = [
            (["kitob", "javon", "polka", "shelf"], "books.vertical.fill"),
            (["divan", "sofa", "yumshoq", "mehmon", "zal"], "sofa.fill"),
            (["karavat", "krovat", "yotoq", "bed", "matras"], "bed.double.fill"),
            (["shkaf", "garderob", "jovon", "komod"], "cabinet.fill"),
            (["stol", "table", "jurnal"], "table.furniture.fill"),
            (["oshxona", "kuxn", "kitchen"], "refrigerator.fill"),
            (["bolalar", "bola", "kids", "child"], "figure.and.child.holdinghands"),
            (["bog", "tashqi", "garden", "outdoor"], "tree.fill"),
            (["ofis", "office"], "desktopcomputer"),
            (["yoritgich", "chiroq", "lamp"], "lamp.desk.fill"),
            (["kreslo", "stul", "chair"], "chair.lounge.fill"),
        ]
        for (words, symbol) in table where words.contains(where: key.contains) { return symbol }
        return "sofa.fill"
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
                                    .fill(isSelected ? Color.brand : Color.appBackgroundAlt)
                                    .frame(width: 76, height: 76)
                                Image(systemName: categorySymbol(cat))
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
                .foregroundStyle(Color.textSecondary)
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
                Image(systemName: "tray").font(.largeTitle).foregroundStyle(Color.textSecondary)
                Text(locale.t("home_nothing_found")).foregroundStyle(Color.textSecondary)
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
        guard location.hasFix, let lat = location.lat, let lng = location.lng else {
            isLoading = false
            return
        }
        var params: [String] = ["lat=\(lat)", "lng=\(lng)"]
        if sort == .top {
            params.append("ordering=top")
        }
        let query = params.isEmpty ? "" : "?\(params.joined(separator: "&"))"
        async let productsResult: Paginated<Product> = APIClient.shared.getCached(
            "/products/\(query)", auth: true,
            onRefresh: { page in
                products = page.results
                likes.sync(from: page.results)
            }
        )
        async let categoriesResult: Paginated<Category> = APIClient.shared.getCached(
            "/categories/",
            onRefresh: { page in categories = page.results }
        )
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
        ProductCardView(product: product, imageHeight: 130)
            .frame(width: 168)
    }
}

/// Grid'da ishlatiladigan kartochka (2 ustunli).
struct FeaturedGridCard: View {
    let product: Product

    var body: some View {
        ProductCardView(product: product)
    }
}

struct StockBadge: View {
    let quantity: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "shippingbox.fill").font(.caption2)
            Text("\(quantity) dona").font(.caption2).bold()
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Color.appSuccess)
        .foregroundStyle(.white)
        .clipShape(Capsule())
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
