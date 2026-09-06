import SwiftUI

/// Usta ish rejimi: faqat o'z firmasining mahsulotlari (va ularning 3D
/// modellari) ko'rinadi — mijoz sifatida butun bozorni emas, uyni loyihalashda
/// faqat o'z firmasi mahsulotlaridan foydalanadi.
struct WorkerHomeView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let company = auth.user?.company {
                    content(companySlug: company.slug, companyName: company.name)
                } else {
                    ContentUnavailableFallback()
                }
            }
            .navigationTitle("Usta paneli")
            .toolbar {
                // Davomat (check-in/check-out) faqat soatbay (payType ==
                // "hourly") xodimlar uchun mantiqiy — backend ham mustaqil
                // tekshiradi (AttendanceRecordViewSet._own_employee).
                if auth.user?.payType == "hourly" {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: AttendanceView()) {
                            Image(systemName: "clock.fill")
                        }
                    }
                }
                // Individual loyiha (CUSTOM_PROJECT) — usta mijoz uyida turib
                // to'g'ridan-to'g'ri buyurtma yaratadi, alohida "joy
                // o'rganish" tayinlash bosqichi endi yo'q (qarang backend
                // apps.custom_orders.services.create_custom_order_on_site).
                if auth.user?.positions?.contains("usta") == true {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CreateCustomOrderView()) {
                            Image(systemName: "note.text.badge.plus")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: WarehousesView()) {
                        Image(systemName: "shippingbox")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(companySlug: String, companyName: String) -> some View {
        List {
            Section {
                Text(companyName).font(.headline)
                Text("Faqat shu firma mahsulotlari — uy loyihalashda ishlatiladi.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Mahsulotlar") {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if products.isEmpty {
                    Text("Bu firmada hali mahsulot yo'q").foregroundStyle(.secondary)
                } else {
                    ForEach(products) { product in
                        NavigationLink {
                            ProductDetailView(productId: product.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.nameUz).bold()
                                    if product.model3d?.usdzUrl != nil {
                                        Label("AR mavjud", systemImage: "arkit")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .task { await load(companySlug: companySlug) }
        .refreshable { await load(companySlug: companySlug) }
    }

    private func load(companySlug: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page: Paginated<Product> = try await APIClient.shared.get(
                "/products/?company=\(companySlug)", auth: true
            )
            products = page.results
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ContentUnavailableFallback: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.2").font(.largeTitle).foregroundStyle(.secondary)
            Text("Siz hali biror firmada ishlamayapsiz").foregroundStyle(.secondary)
        }
    }
}
