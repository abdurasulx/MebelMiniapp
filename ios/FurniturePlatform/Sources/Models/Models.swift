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

struct Product: Codable, Identifiable {
    let id: String
    let company: String
    let companyName: String
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

    var liked: Bool { isLiked ?? false }
}

struct Like: Codable, Identifiable {
    let id: String
    let product: String
    let productDetail: Product
    let createdAt: String
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
