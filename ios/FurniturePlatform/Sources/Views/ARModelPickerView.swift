import SwiftUI

/// AR'ga joylashtiriladigan model — mahsulot 3D fayli (bitta) + tanlangan
/// birinchi variantning rang/naqsh/o'lcham ma'lumoti bilan.
struct ARModelItem: Identifiable {
    let id: String
    let title: String
    let usdzURL: URL
    let colorHex: String?
    let textureURL: URL?
}

/// Bir nechta mahsulotni AR sessiyasiga olib kirish uchun — faqat o'z
/// firmasining (3D fayli tayyor) mahsulotlaridan belgilab, keyin AR'da
/// birma-bir joylashtirib chiqish uchun ro'yxat.
struct ARModelPickerView: View {
    let companySlug: String

    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var selectedIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false
    @State private var showAR = false

    private var arReadyProducts: [Product] {
        products.filter { $0.model3d?.usdzUrl != nil }
    }

    private var selectedItems: [ARModelItem] {
        arReadyProducts
            .filter { selectedIds.contains($0.id) }
            .compactMap { product in
                guard let urlString = product.model3d?.usdzUrl, let url = URL(string: urlString) else { return nil }
                let variant = product.variants.first
                return ARModelItem(
                    id: product.id, title: product.nameUz, usdzURL: url,
                    colorHex: variant?.colorHex,
                    textureURL: variant?.textureUrl.flatMap(URL.init(string:))
                )
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isOffline && products.isEmpty && !isLoading {
                    OfflineView(onRetry: { Task { await load() } })
                } else if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else if arReadyProducts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arkit").font(.largeTitle).foregroundStyle(.secondary)
                        Text("3D modeli tayyor mahsulot yo'q").foregroundStyle(.secondary)
                    }
                } else {
                    List(arReadyProducts) { product in
                        Button {
                            if selectedIds.contains(product.id) {
                                selectedIds.remove(product.id)
                            } else {
                                selectedIds.insert(product.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedIds.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIds.contains(product.id) ? Color.brandDeep : .secondary)
                                Text(product.nameUz).foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("AR uchun tanlang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("AR'da ochish (\(selectedIds.count))") { showAR = true }
                        .disabled(selectedIds.isEmpty)
                }
            }
            .task { await load() }
            .fullScreenCover(isPresented: $showAR) {
                MultiARPlacementView(models: selectedItems)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let page: Paginated<Product> = try await APIClient.shared.get(
                "/products/?company=\(companySlug)", auth: true
            )
            products = page.results
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
