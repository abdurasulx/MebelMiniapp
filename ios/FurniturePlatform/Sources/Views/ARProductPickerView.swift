import SwiftUI

/// Loyihaga mahsulot qo'shish — rasmli katalog (faqat AR fayli tayyor, o'z
/// firmasiga tegishli mahsulotlar), tanlangach rangni ham RASM orqali
/// (naqsh surati yoki rang doirasi) tanlash mumkin.
struct ARProductPickerView: View {
    let companySlug: String
    let collectionId: String

    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedProduct: Product?
    @State private var adding = false

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
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                            ForEach(arReadyProducts) { product in
                                Button {
                                    selectedProduct = product
                                } label: {
                                    ARProductPickerCard(product: product)
                                }
                                .buttonStyle(.plain)
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
            .sheet(item: $selectedProduct) { product in
                ARVariantPickerSheet(product: product, isAdding: $adding) { variant in
                    Task { await add(product: product, variant: variant) }
                }
            }
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

    private func add(product: Product, variant: Variant?) async {
        guard !adding else { return }
        adding = true
        struct Body: Encodable { let productId: String; let variant: String? }
        let body = Body(productId: product.id, variant: variant?.id)
        let result: ARCollectionItem? = try? await APIClient.shared.post(
            "/ar-collections/\(collectionId)/items/", body: body, auth: true
        )
        adding = false
        if result != nil {
            selectedProduct = nil
            dismiss()
        }
    }
}

private struct ARProductPickerCard: View {
    let product: Product

    var body: some View {
        VStack(spacing: 6) {
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
            Text(product.nameUz).font(.caption).bold().lineLimit(1).foregroundStyle(.primary)
        }
    }
}

/// Mahsulot tanlangach rangni RASM orqali (naqsh surati bo'lsa o'sha,
/// bo'lmasa rang doirasi) tanlaydi — variantning o'zi alohida suratga ega
/// emas (bitta geometriyaga runtime tint qo'llanadi, qarang Variant model
/// izohi), shuning uchun naqsh surati/rang doirasi uning vizual ifodasi.
struct ARVariantPickerSheet: View {
    let product: Product
    @Binding var isAdding: Bool
    let onSelect: (Variant?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Variant?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                AsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Color.brandPrimary.opacity(0.3)
                    }
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                if !product.variants.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rangni tanlang").font(.subheadline).bold().padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(product.variants) { variant in
                                    VariantSwatch(variant: variant, isSelected: selected?.id == variant.id) {
                                        selected = variant
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()

                Button {
                    onSelect(selected ?? product.variants.first)
                } label: {
                    if isAdding {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Loyihaga qo'shish").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAdding)
                .padding()
            }
            .padding(.top)
            .navigationTitle(product.nameUz)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Bekor") { dismiss() }
                }
            }
            .onAppear { selected = product.variants.first }
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
