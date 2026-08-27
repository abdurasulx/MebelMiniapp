import SwiftUI

/// Loyihaga mahsulot qo'shish — rasmli katalog (faqat AR fayli tayyor, o'z
/// firmasiga tegishli mahsulotlar). DIQQAT: rang/variant BU YERDA
/// tanlanmaydi — mahsulot variantsiz (rangsiz) qo'shiladi, rang esa AR'da
/// JOYLASHTIRISH vaqtida tanlanadi (qarang ARSessionVariantPickerView).
/// Sabab: agar rang shu yerda "qulflab" qo'yilsa, mijoz keyin "boshqa rangda
/// ham ko'ray" desa, usta uchun qiyinchilik tug'iladi — loyihaga qo'shish
/// bir marta, rang tanlash esa har safar joylashtirishda erkin bo'lishi kerak.
struct ARProductPickerView: View {
    let companySlug: String
    let collectionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingProductId: String?

    private var arReadyProducts: [Product] { products.filter { $0.model3d?.usdzUrl != nil } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).padding()
                } else if arReadyProducts.isEmpty {
                    Text("3D modeli tayyor mahsulot yo'q").foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        // .adaptive — kenglik qancha bo'lsa shuncha ustun
                        // sig'adi (iPhone'da 2, iPad landscape'da 4-5 ustun).
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                            ForEach(arReadyProducts) { product in
                                Button {
                                    Task { await add(product: product) }
                                } label: {
                                    ARProductPickerCard(product: product, isAdding: addingProductId == product.id)
                                }
                                .buttonStyle(.plain)
                                .disabled(addingProductId != nil)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Mahsulot qo'shish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Yopish") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result: Paginated<Product> = try await APIClient.shared.get(
                "/products/?company=\(companySlug)", auth: true
            )
            products = result.results
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func add(product: Product) async {
        guard addingProductId == nil else { return }
        addingProductId = product.id
        struct Body: Encodable { let productId: String }
        let body = Body(productId: product.id)
        let result: ARCollectionItem? = try? await APIClient.shared.post(
            "/ar-collections/\(collectionId)/items/", body: body, auth: true
        )
        addingProductId = nil
        if result != nil {
            dismiss()
        }
    }
}

private struct ARProductPickerCard: View {
    let product: Product
    var isAdding: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                AsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.brandPrimary.opacity(0.3)
                    }
                }
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(isAdding ? 0.4 : 1)

                if isAdding { ProgressView() }
            }
            Text(product.nameUz).font(.caption).bold().lineLimit(1).foregroundStyle(.primary)
        }
    }
}

/// AR'da JOYLASHTIRISH boshlanishidan oldin, bir nechta rangga ega
/// mahsulotlar uchun rangni RASM orqali tanlash — BIR NECHTA mahsulot bir
/// ekranda ko'rsatiladi (loyihada bir necha rang tanlash kerak bo'lgan
/// mahsulot bo'lsa, hammasi shu yerda, birma-bir sheet ochib
/// o'tirmasdan). Tanlov FAQAT shu AR seansi uchun (xotirada) — backendga
/// yozilmaydi, chunki rang har safar joylashtirishda erkin o'zgarishi kerak
/// (qarang ARProductPickerView izohi).
struct ARSessionVariantPickerView: View {
    let items: [ARCollectionItem]
    let initialSelections: [String: Variant]
    let onConfirm: ([String: Variant]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selections: [String: Variant]

    init(items: [ARCollectionItem], initialSelections: [String: Variant], onConfirm: @escaping ([String: Variant]) -> Void) {
        self.items = items
        self.initialSelections = initialSelections
        self.onConfirm = onConfirm
        _selections = State(initialValue: initialSelections)
    }

    var body: some View {
        NavigationStack {
            List(items) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.product.nameUz).bold()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(item.product.variants) { variant in
                                VariantSwatch(variant: variant, isSelected: selections[item.id]?.id == variant.id) {
                                    selections[item.id] = variant
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Rangni tanlang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Davom etish") {
                        onConfirm(selections)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct VariantSwatch: View {
    let variant: Variant
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Group {
                    if let textureUrl = variant.textureUrl, let url = URL(string: textureUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                    } else if let hex = variant.colorHex, !hex.isEmpty, let color = UIColor(hex: hex) {
                        Color(color)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(isSelected ? Color.brandDeep : .clear, lineWidth: 3))

                Text(variant.name).font(.caption2).lineLimit(1).frame(maxWidth: 60)
            }
        }
        .foregroundStyle(.primary)
    }
}
