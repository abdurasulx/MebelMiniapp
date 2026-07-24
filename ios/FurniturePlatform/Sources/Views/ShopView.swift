import SwiftUI

enum SortOption: String, CaseIterable, Identifiable {
    case popular = "Ommabop"
    case top = "Top tovarlar"
    case priceLow = "Arzon avval"
    case priceHigh = "Qimmat avval"
    case nameAZ = "Nomi (A-Z)"
    var id: String { rawValue }
}

/// Do'kon / katalog sahifasi — Shopify "Darix" mavzusiga mos: qidiruv,
/// filtr chiplar, saralash va mahsulot to'ri.
struct ShopView: View {
    var initialCategory: Category?

    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var location: LocationStore
    @State private var products: [Product] = []
    @State private var categories: [Category] = []
    @State private var selectedCategory: String?
    @State private var search = ""
    @State private var sort: SortOption = .popular
    @State private var onlyWithAR = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showFilters = false
    @State private var showViloyatPicker = false

    private var filtered: [Product] {
        var list = products
        if let selectedCategory {
            list = list.filter { $0.category == selectedCategory }
        }
        if onlyWithAR {
            list = list.filter { p in p.model3d?.glbUrl != nil }
        }
        if !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = search.lowercased()
            list = list.filter { $0.nameUz.lowercased().contains(q) || $0.companyName.lowercased().contains(q) }
        }
        switch sort {
        case .popular, .top:
            break // backend `?ordering=top` orqali serverda saralanadi, mahalliy tartib o'zgarmaydi
        case .priceLow:
            list.sort { ($0.variants.first?.basePriceValue ?? 0) < ($1.variants.first?.basePriceValue ?? 0) }
        case .priceHigh:
            list.sort { ($0.variants.first?.basePriceValue ?? 0) > ($1.variants.first?.basePriceValue ?? 0) }
        case .nameAZ:
            list.sort { $0.nameUz.localizedCaseInsensitiveCompare($1.nameUz) == .orderedAscending }
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                searchBar

                if !categories.isEmpty {
                    categoryRow
                }

                viloyatChip

                HStack {
                    Text("\(filtered.count) ta mahsulot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    sortMenu
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: onlyWithAR ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(onlyWithAR ? Color.brandDeep : .primary)
                    }
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding(.horizontal)
                }

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Mahsulot topilmadi").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(filtered) { product in
                            // LikeButton `NavigationLink`ning label'i ICHIDA emas, sibling
                            // sifatida joylashtiriladi — aks holda yurakchaga bosish, tugma
                            // o'z harakatini bajarish o'rniga, navigatsiyani ishga tushirib
                            // yuboradi (SwiftUI: Button ichidagi NavigationLink taplarni
                            // yutib yuboradigan holat).
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                    ShopProductCard(product: product)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 6) {
                                    if product.model3d?.glbUrl != nil {
                                        ARBadge()
                                    }
                                    LikeButton(productId: product.id)
                                }
                                .padding(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Katalog")
        .task {
            selectedCategory = initialCategory?.id
            await load()
        }
        .refreshable { await load() }
        .onChange(of: sort) { _, _ in Task { await load() } }
        .onChange(of: location.viloyat) { _, _ in Task { await load() } }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
        .confirmationDialog("Viloyat", isPresented: $showViloyatPicker, titleVisibility: .visible) {
            Button("Barchasi") { location.setViloyat(nil) }
            Button("📍 GPS orqali aniqlash") { location.detectFromGps() }
            ForEach(viloyatlar) { v in
                Button(v.label) { location.setViloyat(v.code) }
            }
        }
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
        .padding(.horizontal)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Mahsulot yoki firma qidirish…", text: $search)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("clearSearchButton")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Barchasi", isSelected: selectedCategory == nil) { selectedCategory = nil }
                ForEach(categories) { cat in
                    chip(title: cat.nameUz, isSelected: selectedCategory == cat.id) { selectedCategory = cat.id }
                }
            }
            .padding(.horizontal)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    sort = option
                } label: {
                    if sort == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sort.rawValue).font(.caption).bold()
                Image(systemName: "chevron.down").font(.caption2)
            }
            .foregroundStyle(Color.brandSecondary)
        }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Qo'shimcha filtrlar") {
                    Toggle("Faqat 🧊 AR / 3D mavjud", isOn: $onlyWithAR)
                }
            }
            .navigationTitle("Filtrlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tayyor") { showFilters = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .bold()
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(isSelected ? Color.brandDeep : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.brandPrimary : .primary)
                .clipShape(Capsule())
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        var params: [String] = []
        if let viloyat = location.viloyat {
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ShopProductCard: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: product.imageUrl ?? "")) { phase in
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
