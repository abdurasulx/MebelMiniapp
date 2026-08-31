import Foundation

@MainActor
final class LikesStore: ObservableObject {
    @Published private(set) var likedIds: Set<String> = []

    func isLiked(_ productId: String) -> Bool { likedIds.contains(productId) }

    /// Mahsulotlar ro'yxati serverdan kelganda ularning `is_liked` bayrog'ini sinxronlaydi.
    func sync(from products: [Product]) {
        for p in products where p.liked { likedIds.insert(p.id) }
    }

    func clear() {
        likedIds.removeAll()
    }

    /// Muvaffaqiyatli bo'lsa `nil`, aks holda ko'rsatish uchun xato matnini
    /// qaytaradi — avval bu yerda xato jim yutilardi, natijada tugma
    /// bosilganda (masalan tarmoq xatosi yoki sessiya eskirgan bo'lsa)
    /// hech narsa o'zgarmagandek ko'rinar, sababi hech qayerda ko'rinmasdi.
    @discardableResult
    func toggle(_ productId: String) async -> String? {
        struct Body: Encodable { let product: String }
        struct Response: Decodable { let liked: Bool }
        do {
            let res: Response = try await APIClient.shared.post(
                "/likes/toggle/", body: Body(product: productId), auth: true
            )
            if res.liked { likedIds.insert(productId) } else { likedIds.remove(productId) }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
