import SwiftUI

/// Bitta loyihaning mahsulotlari (rasmli) — mahsulot qo'shish/o'chirish shu
/// yerda, AR joylashtirish esa alohida seans sifatida ochiladi (pozitsiyalar
/// hech qachon saqlanmaydi, qarang MultiARPlacementView).
struct ARCollectionDetailView: View {
    let companySlug: String
    let collectionId: String
    let initialName: String

    @State private var items: [ARCollectionItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false
    @State private var showPicker = false
    @State private var showAR = false

    private var arModels: [ARModelItem] {
        items.compactMap { item in
            guard let urlString = item.activeModel3d?.usdzUrl, let url = URL(string: urlString) else { return nil }
            return ARModelItem(
                id: item.id, title: item.product.nameUz, usdzURL: url,
                colorHex: item.variant?.colorHex,
                textureURL: item.variant?.textureUrl.flatMap(URL.init(string:))
            )
        }
    }

    var body: some View {
        Group {
            if isOffline && items.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Hali mahsulot qo'shilmagan").foregroundStyle(.secondary)
                    Button("+ Mahsulot qo'shish") { showPicker = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                        ForEach(items) { item in
                            ARCollectionItemCard(item: item) { Task { await remove(item) } }
                        }
                    }
                    .padding()
                    // AR tugmasi bilan qoplanib qolmasligi uchun pastdan bo'sh joy.
                    Color.clear.frame(height: arModels.isEmpty ? 0 : 70)
                }
            }
        }
        .navigationTitle(initialName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showPicker = true } label: { Image(systemName: "plus") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !arModels.isEmpty {
                Button {
                    showAR = true
                } label: {
                    Label("AR'da ochish (\(arModels.count))", systemImage: "arkit")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showPicker, onDismiss: { Task { await load() } }) {
            ARProductPickerView(companySlug: companySlug, collectionId: collectionId)
        }
        .fullScreenCover(isPresented: $showAR) {
            MultiARPlacementView(models: arModels)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let result: Paginated<ARCollectionItem> = try await APIClient.shared.get(
                "/ar-collections/\(collectionId)/items/", auth: true
            )
            items = result.results
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func remove(_ item: ARCollectionItem) async {
        _ = try? await APIClient.shared.delete("/ar-collections/\(collectionId)/items/\(item.id)/", auth: true)
        await load()
    }
}

private struct ARCollectionItemCard: View {
    let item: ARCollectionItem
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.product.cardImageUrl ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.brandPrimary.opacity(0.3)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.system(size: 20))
                }
                .padding(6)
            }
            Text(item.product.nameUz).font(.caption).bold().lineLimit(1)
            if let variant = item.variant {
                HStack(spacing: 4) {
                    if let hex = variant.colorHex, !hex.isEmpty, let color = UIColor(hex: hex) {
                        Circle().fill(Color(color)).frame(width: 10, height: 10)
                    }
                    Text(variant.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
