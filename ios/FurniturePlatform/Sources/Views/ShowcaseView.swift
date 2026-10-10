import SwiftUI

/// Vitrina (demo) mahsuloti — firmasiz, faqat ko'rish uchun (`/showcase/products/`).
/// `name`/`description` so'ralgan til (`?lang=`) bo'yicha backend tomonidan tayyorlanadi.
struct ShowcaseProduct: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let imageUrl: String?
    let images: [String]?
    let priceFrom: String?

    var priceValue: Double? { priceFrom.flatMap(Double.init) }

    /// Bosh rasm + qo'shimcha rasmlar (takrorsiz, tartib saqlanadi).
    var gallery: [String] {
        var seen = Set<String>(), out: [String] = []
        for u in ([imageUrl].compactMap { $0 } + (images ?? [])) where seen.insert(u).inserted { out.append(u) }
        return out
    }
}

/// Faol firma yo'q hududdagi foydalanuvchi ilova imkoniyatlarini ko'rishi uchun
/// test mahsulotlar. Buyurtma/savat YO'Q (backendda ham firmasiz).
struct ShowcaseView: View {
    @EnvironmentObject private var locale: LocaleStore
    @State private var items: [ShowcaseProduct]?
    @State private var failed = false
    @State private var loadedLang: String?

    var body: some View {
        VStack(spacing: 0) {
            DemoBanner()
            Group {
                if failed {
                    Button(locale.t("loc_retry")) { Task { await load() } }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let items {
                    if items.isEmpty {
                        Text(locale.t("showcase_empty"))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                                ForEach(items) { item in
                                    NavigationLink(destination: ShowcaseDetailView(product: item)) {
                                        ShowcaseCard(product: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color.appBackground)
        .navigationTitle(locale.t("showcase_title"))
        .navigationBarTitleDisplayMode(.inline)
        // Til almashganda nomlar ham shu tilda qayta yuklanadi.
        .task(id: locale.code) { await load() }
    }

    private func load() async {
        failed = false
        do {
            let page: Paginated<ShowcaseProduct> = try await APIClient.shared.get(
                "/showcase/products/?lang=\(locale.code)"
            )
            items = page.results
            loadedLang = locale.code
        } catch {
            failed = true
        }
    }
}

private struct DemoBanner: View {
    @EnvironmentObject private var locale: LocaleStore
    var body: some View {
        Text(locale.t("showcase_demo_banner"))
            .font(.footnote).fontWeight(.bold)
            .foregroundStyle(Color.onAccent)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accent, ignoresSafeAreaEdges: [])
    }
}

private struct ShowcaseCard: View {
    let product: ShowcaseProduct
    @EnvironmentObject private var locale: LocaleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: URL(string: product.imageUrl ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().padding(8)
                } else {
                    ZStack {
                        Color.appBackgroundAlt
                        Image(systemName: "sofa.fill").font(.system(size: 34)).foregroundStyle(Color.textDisabled)
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 140)
            .background(Color.appBackgroundAlt)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                if let price = product.priceValue {
                    Text("\(String(format: "%.0f", price).formattedSom) \(locale.t("currency_som"))\(locale.t("price_from_suffix"))")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(10)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
    }
}

struct ShowcaseDetailView: View {
    let product: ShowcaseProduct
    @EnvironmentObject private var locale: LocaleStore
    @State private var index = 0

    var body: some View {
        VStack(spacing: 0) {
            DemoBanner()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    let urls = product.gallery
                    if urls.isEmpty {
                        ZStack {
                            Color.appBackgroundAlt
                            Image(systemName: "sofa.fill").font(.system(size: 44)).foregroundStyle(Color.textDisabled)
                        }
                        .frame(height: 280)
                    } else {
                        TabView(selection: $index) {
                            ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFit().padding(12)
                                    } else {
                                        Color.appBackgroundAlt
                                    }
                                }
                                .tag(i)
                            }
                        }
                        .tabViewStyle(.page)
                        .frame(height: 300)
                        .background(Color.appBackgroundAlt)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name).font(.title2).bold()
                        if let price = product.priceValue {
                            Text("\(String(format: "%.0f", price).formattedSom) \(locale.t("currency_som"))\(locale.t("price_from_suffix"))")
                                .font(.title3).fontWeight(.bold)
                        }
                        if let description = product.description, !description.isEmpty {
                            Text(description).font(.body).foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(locale.t("showcase_title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
