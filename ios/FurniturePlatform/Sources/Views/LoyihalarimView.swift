import SwiftUI

/// Usta bir marta yaratadigan, keyin qayta-qayta ochib turadigan AR
/// mahsulot to'plamlari ("loyihalar") ro'yxati — har birida fazoviy
/// (joylashuv) ma'lumot SAQLANMAYDI, faqat "qaysi mahsulot+rang loyihaga
/// tegishli" (qarang backend apps.ar_collections va ARCollectionDetailView).
struct LoyihalarimView: View {
    let companySlug: String

    @State private var collections: [ARCollection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isOffline = false
    @State private var showCreate = false
    @State private var newName = ""
    @State private var creating = false

    var body: some View {
        // DIQQAT: bu View WorkerHomeView'ning NavigationStack'i ichidan
        // NavigationLink orqali ochiladi — shuning uchun bu yerda YANA bir
        // NavigationStack o'ralmaydi (ichma-ich NavigationStack SwiftUI'da
        // NavigationLink bosilganda hech narsa qilmay qolish kabi jimgina
        // ishlamay qolish holatlariga olib keladi).
        Group {
            if isOffline && collections.isEmpty && !isLoading {
                OfflineView(onRetry: { Task { await load() } })
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).padding()
            } else if collections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arkit").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Hali loyiha yo'q").foregroundStyle(.secondary)
                    Text("Mahsulotlarni AR'da ko'rsatish uchun avval loyiha yarating.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
            } else {
                List(collections) { collection in
                    NavigationLink(
                        destination: ARCollectionDetailView(
                            companySlug: companySlug, collectionId: collection.id, initialName: collection.name
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(collection.name).bold()
                            Text("\(collection.itemCount) ta mahsulot").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Loyihalarim")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .alert("Yangi loyiha", isPresented: $showCreate) {
            TextField("Loyiha nomi", text: $newName)
            Button("Bekor", role: .cancel) { newName = "" }
            Button("Yaratish") { Task { await create() } }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        isOffline = false
        do {
            let result: Paginated<ARCollection> = try await APIClient.shared.get("/ar-collections/", auth: true)
            collections = result.results
        } catch {
            if OfflineView.isOffline(error) {
                isOffline = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func create() async {
        guard !creating else { return }
        creating = true
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        struct Body: Encodable { let name: String }
        let body = Body(name: trimmed.isEmpty ? "Yangi loyiha" : trimmed)
        if let _: ARCollection = try? await APIClient.shared.post("/ar-collections/", body: body, auth: true) {
            newName = ""
            await load()
        }
        creating = false
    }
}
