import Foundation

@MainActor
final class LikesStore: ObservableObject {
    @Published private(set) var likedIds: Set<String> = []
    // Sevimlilar ekrani (`LikesView`) endi bevosita shu ro'yxatdan
    // render qiladi — like/unlike qilinganda (qaerda bo'lmasin: Bosh
    // sahifa, mahsulot sahifasi) darhol shu yerda ham yangilanadi,
    // Sevimlilar tabiga har safar kirilganda serverdan qayta so'ralmaydi
    // (qarang `toggle`/`loadIfNeeded`).
    @Published private(set) var likedProducts: [Product] = []
    private var didLoadOnce = false

    func isLiked(_ productId: String) -> Bool { likedIds.contains(productId) }

    /// Mahsulotlar ro'yxati serverdan kelganda ularning `is_liked` bayrog'ini
    /// sinxronlaydi (faqat ID'lar — bu yerda ko'ringan mahsulotlar sevimlilar
    /// ro'yxatining TO'LIQ o'zi emas, shuning uchun `likedProducts`ga
    /// tegilmaydi, qarang `loadIfNeeded`).
    func sync(from products: [Product]) {
        for p in products where p.liked { likedIds.insert(p.id) }
    }

    func clear() {
        likedIds.removeAll()
        likedProducts.removeAll()
        didLoadOnce = false
    }

    /// Sevimlilar ekrani BIRINCHI marta ochilganda serverdan to'liq
    /// ro'yxatni yuklaydi (masalan boshqa qurilmada yoqtirilgan bo'lishi
    /// mumkin) — keyingi safar tab qayta faol bo'lganda qayta so'ralmaydi,
    /// chunki `toggle()` har bir o'zgarishni shu yerning o'zida darhol
    /// aks ettiradi.
    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        await reload()
    }

    /// Pastga-tortib-yangilash uchun — `loadIfNeeded`dan farqli, "bir marta
    /// yuklandi" bayrog'iga qaramasdan har doim serverdan qayta so'raydi.
    func reload() async {
        didLoadOnce = true
        do {
            let page: Paginated<Like> = try await APIClient.shared.get("/likes/", auth: true)
            likedProducts = page.results.map(\.productDetail)
            likedIds = Set(page.results.map(\.product))
        } catch {
            // Keyingi safar (masalan tarmoq tiklangach) qayta urinib
            // ko'rish uchun — muvaffaqiyatsiz urinishni "bir marta
            // yuklandi" deb hisoblamaymiz.
            didLoadOnce = false
        }
    }

    /// Muvaffaqiyatli bo'lsa `nil`, aks holda ko'rsatish uchun xato matnini
    /// qaytaradi — avval bu yerda xato jim yutilardi, natijada tugma
    /// bosilganda (masalan tarmoq xatosi yoki sessiya eskirgan bo'lsa)
    /// hech narsa o'zgarmagandek ko'rinar, sababi hech qayerda ko'rinmasdi.
    ///
    /// `product` — LIKE qilinganda `likedProducts`ga DARHOL qo'shish uchun
    /// (chaqiruvchida allaqachon mavjud bo'lsa, qarang LikeButton) — bermasa
    /// ham xato bo'lmaydi, faqat Sevimlilar ro'yxati keyingi `loadIfNeeded`
    /// yoki pastga-tortib-yangilashgacha shu elementni ko'rsatmaydi.
    @discardableResult
    func toggle(_ productId: String, product: Product? = nil) async -> String? {
        struct Body: Encodable { let product: String }
        struct Response: Decodable { let liked: Bool }
        do {
            let res: Response = try await APIClient.shared.post(
                "/likes/toggle/", body: Body(product: productId), auth: true
            )
            if res.liked {
                likedIds.insert(productId)
                if let product, !likedProducts.contains(where: { $0.id == productId }) {
                    likedProducts.insert(product, at: 0)
                }
            } else {
                likedIds.remove(productId)
                likedProducts.removeAll { $0.id == productId }
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
