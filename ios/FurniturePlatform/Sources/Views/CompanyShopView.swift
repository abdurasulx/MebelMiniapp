import SwiftUI

/// Firma do'kon sahifasi (marketplace uslubida) — mahsulot sahifasidan firma
/// nomiga bosilganda ochiladi: tavsif, ishonch darajasi, boshqa mahsulotlari
/// va mijoz sharhlari (web'dagi `Shop.jsx` bilan bir xil endpointlar).
struct CompanyShopView: View {
    let companySlug: String

    @EnvironmentObject private var auth: AuthStore
    @State private var company: Company?
    @State private var products: [Product] = []
    @State private var reviews: [Review] = []
    @State private var errorMessage: String?
    @State private var rating = 5
    @State private var comment = ""
    @State private var submitBusy = false
    @State private var submitMessage: String?

    var body: some View {
        ScrollView {
            if let company {
                VStack(alignment: .leading, spacing: 20) {
                    header(company)
                    productsSection
                    reviewsSection
                    if auth.isAuthenticated {
                        if company.canReview == true {
                            reviewForm(company)
                        } else {
                            Text("Faqat shu firmadan yakunlangan buyurtmangiz bo'lsa baho qoldira olasiz.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 24)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle(company?.name ?? "Do'kon")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: company.logoUrl ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack { Color.brandPrimary.opacity(0.4); Image(systemName: "building.2.fill") }
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(company.name).font(.title3).bold()
                    if let tier = company.tier {
                        TierBadge(tier: tier)
                    }
                }
            }
            if let description = company.description, !description.isEmpty {
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            if (company.address?.isEmpty == false) || company.mapURL != nil {
                HStack(spacing: 4) {
                    if let address = company.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary)
                    }
                    if let mapURL = company.mapURL {
                        Link("Xaritada ko'rish", destination: mapURL)
                            .font(.caption).underline()
                    }
                }
            }
            if !company.socialLinks.isEmpty {
                SocialLinksRow(links: company.socialLinks)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandPrimary.opacity(0.15))
    }

    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mahsulotlar").font(.headline).padding(.horizontal)
            if products.isEmpty {
                Text("Hozircha mahsulotlar yo'q").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(products) { product in
                        NavigationLink(destination: ProductDetailView(productId: product.id)) {
                            VStack(alignment: .center, spacing: 4) {
                                AsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.brandPrimary.opacity(0.3)
                                    }
                                }
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(product.nameUz).font(.caption).bold().lineLimit(1)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.leading, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mijoz baholari (\(reviews.count))").font(.headline).padding(.horizontal)
            if reviews.isEmpty {
                Text("Hali baho yo'q").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(reviews) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.customerName?.isEmpty == false ? r.customerName! : "Mijoz").font(.subheadline).bold()
                                Spacer()
                                Text(String(repeating: "⭐", count: r.rating)).font(.caption)
                            }
                            if let comment = r.comment, !comment.isEmpty {
                                Text(comment).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func reviewForm(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Baho qoldirish").font(.headline)
            Picker("Baho", selection: $rating) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { n in
                    Text("\(String(repeating: "⭐", count: n)) (\(n))").tag(n)
                }
            }
            .pickerStyle(.menu)
            TextField("Izoh (ixtiyoriy)", text: $comment, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
            if let submitMessage {
                Text(submitMessage).font(.caption).foregroundStyle(.secondary)
            }
            Button {
                Task { await submitReview(company) }
            } label: {
                if submitBusy { ProgressView() } else { Text("Baho qoldirish").bold() }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(submitBusy)
            Text("Faqat shu firmadan yakunlangan buyurtmangiz bo'lsa baho qoldira olasiz.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func load() async {
        do {
            async let companyResult: Company = APIClient.shared.get("/companies/\(companySlug)/", auth: auth.isAuthenticated)
            async let productsResult: Paginated<Product> = APIClient.shared.get("/products/?company=\(companySlug)", auth: auth.isAuthenticated)
            async let reviewsResult: Paginated<Review> = APIClient.shared.get("/reviews/?company=\(companySlug)", auth: auth.isAuthenticated)
            let (c, p, r) = try await (companyResult, productsResult, reviewsResult)
            company = c
            products = p.results
            reviews = r.results
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitReview(_ company: Company) async {
        submitBusy = true
        submitMessage = nil
        struct Body: Encodable { let company: String; let rating: Int; let comment: String }
        do {
            let _: Review = try await APIClient.shared.post(
                "/reviews/", body: Body(company: company.id, rating: rating, comment: comment)
            )
            submitMessage = "Rahmat! Bahoyingiz saqlandi."
            comment = ""
            await load()
        } catch {
            submitMessage = error.localizedDescription
        }
        submitBusy = false
    }
}

private struct TierBadge: View {
    let tier: CompanyTier

    var body: some View {
        HStack(spacing: 6) {
            Text(tier.label)
                .font(.caption2).bold()
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: tier.color)?.opacity(0.2) ?? Color.gray.opacity(0.2))
                .foregroundStyle(Color(hex: tier.color) ?? .gray)
                .clipShape(Capsule())
            if let rating = tier.rating {
                Text("⭐ \(String(format: "%.1f", rating)) (\(tier.reviewCount))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private extension Color {
    init?(hex: String) {
        guard let uiColor = UIColor(hex: hex) else { return nil }
        self.init(uiColor: uiColor)
    }
}
