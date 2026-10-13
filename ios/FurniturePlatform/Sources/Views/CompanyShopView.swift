import SwiftUI

/// Firma do'kon sahifasi (marketplace uslubida) — mahsulot sahifasidan firma
/// nomiga bosilganda ochiladi: tavsif, ishonch darajasi, boshqa mahsulotlari
/// va mijoz sharhlari (web'dagi `Shop.jsx` bilan bir xil endpointlar).
struct CompanyShopView: View {
    let companySlug: String

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var company: Company?
    @State private var products: [Product] = []
    @State private var reviews: [Review] = []
    @State private var errorMessage: String?
    @State private var rating = 5
    @State private var comment = ""
    @State private var submitBusy = false
    @State private var submitMessage: String?
    // UGC moderatsiya (Apple 1.2): shikoyat va bloklash.
    @State private var reportTarget: Review?
    @State private var blockTarget: Review?
    @State private var ugcMessage: String?

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
                            Text(locale.t("shop_review_locked"))
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 24)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(Color.appError).padding()
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .navigationTitle(company?.name ?? locale.t("shop_title_fallback"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func header(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: URL(string: company.logoUrl ?? "")) { phase in
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
                Text(description).font(.subheadline).foregroundStyle(Color.textSecondary)
            }
            if (company.address?.isEmpty == false) || company.mapURL != nil {
                HStack(spacing: 4) {
                    if let address = company.address, !address.isEmpty {
                        Label(address, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(Color.textSecondary)
                    } else {
                        Image(systemName: "mappin.and.ellipse").font(.caption).foregroundStyle(Color.textSecondary)
                    }
                    if let mapURL = company.mapURL {
                        Link(locale.t("shop_view_on_map"), destination: mapURL)
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
            Text(locale.t("shop_products")).font(.headline).padding(.horizontal)
            if products.isEmpty {
                Text(locale.t("shop_no_products")).font(.caption).foregroundStyle(Color.textSecondary).padding(.horizontal)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(products) { product in
                        NavigationLink(destination: ProductDetailView(productId: product.id)) {
                            VStack(alignment: .center, spacing: 4) {
                                CachedAsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
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
            Text("\(locale.t("shop_reviews_prefix"))\(reviews.count)\(locale.t("shop_reviews_suffix"))").font(.headline).padding(.horizontal)
            if reviews.isEmpty {
                Text(locale.t("shop_no_reviews")).font(.caption).foregroundStyle(Color.textSecondary).padding(.horizontal)
            } else {
                VStack(spacing: 8) {
                    ForEach(reviews) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.customerName?.isEmpty == false ? r.customerName! : locale.t("shop_anonymous_customer")).font(.subheadline).bold()
                                Spacer()
                                Text(String(repeating: "⭐", count: r.rating)).font(.caption)
                                Menu {
                                    Button(role: .destructive) { startReport(r) } label: {
                                        Label(locale.t("review_report"), systemImage: "flag")
                                    }
                                    Button(role: .destructive) { startBlock(r) } label: {
                                        Label(locale.t("review_block_user"), systemImage: "hand.raised")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis").padding(.leading, 6).foregroundStyle(Color.textSecondary)
                                }
                            }
                            if let comment = r.comment, !comment.isEmpty {
                                Text(comment).font(.caption).foregroundStyle(Color.textSecondary)
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
        .confirmationDialog(
            locale.t("review_report_title"),
            isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }),
            titleVisibility: .visible
        ) {
            ForEach([
                ("spam", "review_reason_spam"), ("abusive", "review_reason_abusive"),
                ("inappropriate", "review_reason_inappropriate"), ("false", "review_reason_false"),
                ("other", "review_reason_other"),
            ], id: \.0) { reason, key in
                Button(locale.t(key)) {
                    if let target = reportTarget { Task { await sendReport(target, reason: reason) } }
                }
            }
            Button(locale.t("common_close"), role: .cancel) {}
        }
        .alert(
            locale.t("review_block_user"),
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })
        ) {
            Button(locale.t("review_block_user"), role: .destructive) {
                if let target = blockTarget { Task { await block(target) } }
            }
            Button(locale.t("common_close"), role: .cancel) {}
        } message: {
            Text(locale.t("review_block_confirm"))
        }
        .alert(
            "",
            isPresented: Binding(get: { ugcMessage != nil }, set: { if !$0 { ugcMessage = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(ugcMessage ?? "")
        }
    }

    private func startReport(_ r: Review) {
        guard auth.isAuthenticated else { ugcMessage = locale.t("checkout_login_required"); return }
        reportTarget = r
    }

    private func startBlock(_ r: Review) {
        guard auth.isAuthenticated else { ugcMessage = locale.t("checkout_login_required"); return }
        blockTarget = r
    }

    private func sendReport(_ r: Review, reason: String) async {
        struct Body: Encodable { let reason: String }
        struct Resp: Decodable { let detail: String? }
        do {
            let _: Resp = try await APIClient.shared.post("/reviews/\(r.id)/report/", body: Body(reason: reason), auth: true)
            ugcMessage = locale.t("review_reported")
        } catch {
            ugcMessage = error.localizedDescription
        }
    }

    private func block(_ r: Review) async {
        guard let author = r.authorId else { return }
        struct Body: Encodable { let user: String }
        struct Resp: Decodable { let detail: String? }
        do {
            let _: Resp = try await APIClient.shared.post("/blocks/", body: Body(user: author), auth: true)
            reviews.removeAll { $0.authorId == author }
            ugcMessage = locale.t("review_blocked")
        } catch {
            ugcMessage = error.localizedDescription
        }
    }

    private func reviewForm(_ company: Company) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(locale.t("shop_leave_review")).font(.headline)
            Picker(locale.t("shop_leave_review"), selection: $rating) {
                ForEach([5, 4, 3, 2, 1], id: \.self) { n in
                    Text("\(String(repeating: "⭐", count: n)) (\(n))").tag(n)
                }
            }
            .pickerStyle(.menu)
            TextField(locale.t("shop_comment_label"), text: $comment, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
            if let submitMessage {
                Text(submitMessage).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Button {
                Task { await submitReview(company) }
            } label: {
                if submitBusy { ProgressView() } else { Text(locale.t("shop_leave_review")).bold() }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandDeep)
            .foregroundStyle(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(submitBusy)
            Text(locale.t("shop_review_locked"))
                .font(.caption2).foregroundStyle(Color.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func load() async {
        do {
            async let companyResult: Company = APIClient.shared.getCached(
                "/companies/\(companySlug)/", auth: auth.isAuthenticated,
                onRefresh: { fresh in company = fresh }
            )
            async let productsResult: Paginated<Product> = APIClient.shared.getCached(
                "/products/?company=\(companySlug)", auth: auth.isAuthenticated,
                onRefresh: { page in products = page.results }
            )
            async let reviewsResult: Paginated<Review> = APIClient.shared.getCached(
                "/reviews/?company=\(companySlug)", auth: auth.isAuthenticated,
                onRefresh: { page in reviews = page.results }
            )
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
            submitMessage = locale.t("shop_review_thanks")
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
                    .font(.caption2).foregroundStyle(Color.textSecondary)
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
