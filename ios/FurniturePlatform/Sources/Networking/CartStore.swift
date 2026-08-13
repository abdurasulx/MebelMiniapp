import Foundation

/// Savat elementi — checkout paytida backend `OrderCreateSerializer`ga mos
/// formatda yuboriladi. Flutter'dagi `lib/cart_store.dart` bilan bir xil naqsh.
struct CartItem: Codable, Identifiable {
    let id: UUID
    let productId: String
    let productName: String
    let imageUrl: String?
    let companyId: String
    let companyName: String
    let variantId: String
    let variantName: String
    let width: Double
    let height: Double
    let depth: Double
    let unitM3Price: Double
    var qty: Int
    // Backend `/cart-items/`dagi mos yozuv ID'si — muvaffaqiyatli
    // sinxronlangandan keyin to'ldiriladi, keyingi qty o'zgarishi/o'chirish
    // shu ID orqali serverga ham yetkaziladi (qidiruv/asosiy sahifa reytingi
    // uchun "savatda turgan aktivligi" signali, qarang backend apps/cart).
    var serverId: String?

    init(
        productId: String, productName: String, imageUrl: String?,
        companyId: String, companyName: String,
        variantId: String, variantName: String,
        width: Double, height: Double, depth: Double,
        unitM3Price: Double, qty: Int = 1, serverId: String? = nil
    ) {
        self.id = UUID()
        self.productId = productId
        self.productName = productName
        self.imageUrl = imageUrl
        self.companyId = companyId
        self.companyName = companyName
        self.variantId = variantId
        self.variantName = variantName
        self.width = width
        self.height = height
        self.depth = depth
        self.unitM3Price = unitM3Price
        self.qty = qty
        self.serverId = serverId
    }

    var subtotal: Double { unitM3Price * width * height * depth * Double(qty) }
}

/// Savat — qurilmada saqlanadi (`UserDefaults`), buyurtma berilgandagina
/// backend `Order` yaratiladi (`/orders/` — bitta buyurtmada faqat bitta
/// kompaniya bo'lishi shart, shuning uchun checkout'da kompaniya bo'yicha
/// guruhlab, har biriga alohida so'rov yuboriladi).
@MainActor
final class CartStore: ObservableObject {
    private static let prefKey = "fp.cart"

    @Published private(set) var items: [CartItem] = []

    var count: Int { items.reduce(0) { $0 + $1.qty } }
    var total: Double { items.reduce(0) { $0 + $1.subtotal } }

    var byCompany: [String: [CartItem]] {
        Dictionary(grouping: items, by: \.companyId)
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.prefKey),
              let decoded = try? JSONDecoder().decode([CartItem].self, from: data)
        else { return }
        items = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.prefKey)
        }
    }

    func addProduct(_ product: Product, variant: Variant, qty: Int = 1) {
        if let idx = items.firstIndex(where: { $0.productId == product.id && $0.variantId == variant.id }) {
            items[idx].qty += qty
            persist()
            let item = items[idx]
            if let serverId = item.serverId {
                Task { await syncPatch(serverId: serverId, qty: item.qty) }
            } else {
                Task { await syncAdd(item) }
            }
        } else {
            let item = CartItem(
                productId: product.id, productName: product.nameUz, imageUrl: product.cardImageUrl,
                companyId: product.company, companyName: product.companyName,
                variantId: variant.id, variantName: variant.name,
                width: variant.widthValue, height: variant.heightValue, depth: variant.depthValue,
                unitM3Price: variant.basePriceValue, qty: qty
            )
            items.append(item)
            persist()
            Task { await syncAdd(item) }
        }
    }

    // Serverga (`/cart-items/`) qo'shish — faqat qidiruv/asosiy sahifa
    // reytingi uchun signal, checkout shu yerga bog'liq emas, shuning uchun
    // xato bo'lsa ham jim o'tkazib yuboriladi (UI'ni bloklamaslik uchun).
    private func syncAdd(_ item: CartItem) async {
        struct Body: Encodable {
            let product: String, variant: String
            let width: Double, height: Double, depth: Double, quantity: Int
        }
        struct Response: Decodable { let id: String }
        do {
            let res: Response = try await APIClient.shared.post(
                "/cart-items/",
                body: Body(
                    product: item.productId, variant: item.variantId,
                    width: item.width, height: item.height, depth: item.depth, quantity: item.qty
                )
            )
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].serverId = res.id
                persist()
            }
        } catch {}
    }

    private func syncPatch(serverId: String, qty: Int) async {
        struct Body: Encodable { let quantity: Int }
        struct Response: Decodable {}
        do {
            let _: Response = try await APIClient.shared.patch("/cart-items/\(serverId)/", body: Body(quantity: qty))
        } catch {}
    }

    func setQty(_ item: CartItem, qty: Int) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].qty = max(1, qty)
        persist()
        if let serverId = items[idx].serverId {
            let newQty = items[idx].qty
            Task { await syncPatch(serverId: serverId, qty: newQty) }
        }
    }

    func remove(_ item: CartItem) {
        items.removeAll { $0.id == item.id }
        persist()
        if let serverId = item.serverId {
            Task { try? await APIClient.shared.delete("/cart-items/\(serverId)/") }
        }
    }

    func clear() {
        items = []
        persist()
        Task { try? await APIClient.shared.delete("/cart-items/clear/") }
    }
}
