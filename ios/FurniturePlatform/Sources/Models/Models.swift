import Foundation

// Backend DRF DecimalField/serializer maydonlari string sifatida keladi
// (masalan "1500000.00"), shuning uchun ko'p maydon String va `Double` hisoblab olinadi.

struct TokenPair: Codable {
    let access: String
    let refresh: String
}

struct CompanyRef: Codable {
    let id: String
    let slug: String
    let name: String
}

struct User: Codable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let dateOfBirth: String?
    let role: String
    // Doimiy, kompaniyalararo qidiruvchi ID — firma egasi shu orqali ishga taklif
    // qiladi (profilda ko'rsatiladi, boshqa kompaniyaga ham amal qiladi).
    let workerId: String?
    let company: CompanyRef?
    let positions: [String]?
}

struct EmployeeInvitation: Codable, Identifiable {
    let id: String
    let company: String
    let companyName: String
    let positions: [String]
    let baseSalary: String
    let bonusPerTask: String
    let status: String
    let statusDisplay: String
    let respondedAt: String?
    let createdAt: String
}

struct CareerEntry: Codable, Identifiable {
    let companyName: String
    let companySlug: String
    let positions: [String]
    let isActive: Bool
    let joinedAt: String
    let leftAt: String?

    var id: String { companySlug + joinedAt }
}

struct Category: Codable, Identifiable {
    let id: String
    let nameUz: String
    let nameRu: String?
    let slug: String
}

struct Variant: Codable, Identifiable {
    let id: String
    let name: String
    let basePrice: String
    let width: String
    let height: String
    let depth: String
    // Geometriya mahsulot darajasida bitta (Product.model3d) — har rang uchun
    // alohida model shart emas. Variant faqat shu bitta modelga runtime'da
    // qo'llanadigan material ma'lumotini olib yuradi: `colorHex` (oddiy rang
    // tint) yoki `textureUrl` (yog'och naqshi surati) — ARni ModelLoader
    // shu ikkalasini RealityKit material sifatida qo'llaydi.
    let colorHex: String?
    let textureUrl: String?

    var basePriceValue: Double { Double(basePrice) ?? 0 }
    var widthValue: Double { Double(width) ?? 1 }
    var heightValue: Double { Double(height) ?? 1 }
    var depthValue: Double { Double(depth) ?? 1 }
}

struct ProductImage: Codable, Identifiable {
    let id: String
    let imageUrl: String?
    let sortOrder: Int?
}

struct Model3D: Codable {
    let id: String
    let glbUrl: String?
    let usdzUrl: String?
    let status: String
    let statusDisplay: String
}

struct CompanyTier: Codable {
    let key: String
    let label: String
    let color: String
    let completedOrders: Int
    let rating: Double?
    let reviewCount: Int
}

struct Company: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let phone: String?
    let address: String?
    let viloyat: String?
    let viloyatDisplay: String?
    let logoUrl: String?
    let tier: CompanyTier?
}

struct Review: Codable, Identifiable {
    let id: String
    let customerName: String?
    let rating: Int
    let comment: String?
    let createdAt: String
}

struct Product: Codable, Identifiable {
    let id: String
    let company: String
    let companyName: String
    let companySlug: String?
    let companyViloyat: String?
    let companyViloyatDisplay: String?
    let companyAddress: String?
    let category: String?
    let nameUz: String
    let nameRu: String?
    let slug: String
    let description: String?
    let imageUrl: String?
    let videoUrl: String?
    let isPublished: Bool
    let variants: [Variant]
    let images: [ProductImage]
    let isLiked: Bool?
    let model3d: Model3D?
    // Faqat "rasm bilan qidirish" natijalarida keladi.
    let similarityPercent: Double?

    var liked: Bool { isLiked ?? false }

    /// Galereya: bosh rasm + qo'shimcha rasmlar.
    var galleryUrls: [String] {
        var urls: [String] = []
        if let imageUrl { urls.append(imageUrl) }
        urls.append(contentsOf: images.compactMap(\.imageUrl))
        return urls
    }

    /// Kartochka (Bosh sahifa/Katalog/Sevimlilar)da bitta rasm ko'rsatiladi —
    /// asosiy rasm bo'lmasa, galereyadagi birinchi rasm ishlatiladi.
    var cardImageUrl: String? { imageUrl ?? images.first?.imageUrl }
}

struct Like: Codable, Identifiable {
    let id: String
    let product: String
    let productDetail: Product
    let createdAt: String
}

struct OrderItemSummary: Codable, Identifiable {
    let id: String
    let productName: String
    let variantName: String
    let quantity: Int
    let subtotal: String

    var subtotalValue: Double { Double(subtotal) ?? 0 }
}

struct WorkflowStepInstance: Codable, Identifiable {
    let id: String
    let name: String
    let roleDisplay: String?
    let status: String
    let statusDisplay: String
    let isAvailable: Bool
    let photoRequirement: String
}

/// Buyurtma statusi bo'yicha kompaniya tomonidan ruxsat etilgan keyingi
/// o'tishlar (backend `Order.TRANSITIONS` bilan bir xil, web `orderStatus.jsx`ga mos).
let nextOrderStatus: [String: [String]] = [
    "new": ["accepted", "cancelled"],
    "accepted": ["in_production", "cancelled"],
    "in_production": ["ready"],
    "ready": ["delivering", "completed"],
    "delivering": ["completed"],
]

let orderStatusLabel: [String: String] = [
    "new": "Kutilmoqda",
    "accepted": "Qabul qilindi",
    "in_production": "Ishlab chiqarilmoqda",
    "ready": "Tayyor",
    "delivering": "Yetkazilmoqda",
    "completed": "Yakunlandi",
    "cancelled": "Bekor qilindi",
]

struct Order: Codable, Identifiable {
    let id: String
    let companyName: String
    let status: String
    let statusDisplay: String
    let totalPrice: String
    let phone: String
    let address: String
    let items: [OrderItemSummary]
    let workflowSteps: [WorkflowStepInstance]
    let progressPercent: Int?
}

struct Paginated<T: Codable>: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

struct APIErrorPayload: Codable {
    let detail: String?
}
