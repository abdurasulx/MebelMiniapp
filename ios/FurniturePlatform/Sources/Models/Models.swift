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
    let phoneVerified: Bool?
    let hasGoogle: Bool?
    let hasTelegram: Bool?
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
    // Odatda geometriya mahsulot darajasida bitta (Product.model3d) — har
    // rang uchun alohida model shart emas, `colorHex`/`textureUrl` runtime
    // tint sifatida yetarli. Lekin ko'p materialli mahsulotlarda firma
    // ma'lum bir variant uchun butunlay alohida 3D fayl yuklashi mumkin —
    // shu holatda `model3d` (variant darajasida, `status == "ready"`)
    // Product.model3d o'rniga ishlatiladi (qarang ProductDetailView.activeModel3d,
    // web'dagi ProductDetail.jsx bilan bir xil naqsh).
    let colorHex: String?
    let textureUrl: String?
    let model3d: Model3D?

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
    let instagramUrl: String?
    let telegramUrl: String?
    let facebookUrl: String?
    let websiteUrl: String?
    // Backend DecimalField — string sifatida keladi (masalan "41.311081").
    let latitude: String?
    let longitude: String?

    /// Do'kon sahifasida bosiladigan ikonkalar — bo'sh havolalar chiqarib
    /// tashlanadi, tartib doim bir xil (Instagram, Telegram, Facebook, sayt).
    var socialLinks: [(label: String, url: URL)] {
        [
            ("Instagram", instagramUrl), ("Telegram", telegramUrl),
            ("Facebook", facebookUrl), ("Veb-sayt", websiteUrl),
        ].compactMap { label, raw in
            guard let raw, !raw.isEmpty, let url = URL(string: raw) else { return nil }
            return (label, url)
        }
    }

    /// Google Maps'da shu nuqtani ochadigan havola — lat/lng bo'lmasa nil.
    var mapURL: URL? {
        guard let latitude, let longitude else { return nil }
        return URL(string: "https://www.google.com/maps?q=\(latitude),\(longitude)")
    }
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
    // Rasmdan avtomatik aniqlangan asosiy rang (masalan "jigarrang") —
    // kartochkada o'lcham bilan birga qisqa xususiyat qatorida ko'rsatiladi
    // (qarang `attributeSummary`), Android/web bilan bir xil.
    let colorTag: String?
    let variants: [Variant]
    let images: [ProductImage]
    let isLiked: Bool?
    let model3d: Model3D?
    // Faqat "rasm bilan qidirish" natijalarida keladi.
    let similarityPercent: Double?

    var liked: Bool { isLiked ?? false }

    /// Kartochkada nomdan keyin ko'rsatiladigan qisqa xususiyat qatori —
    /// masalan "kulrang · 60×90×60 sm".
    var attributeSummary: String? {
        var parts: [String] = []
        if let colorTag, !colorTag.isEmpty { parts.append(colorTag) }
        if let v = variants.first {
            let w = Int((v.widthValue * 100).rounded())
            let h = Int((v.heightValue * 100).rounded())
            let d = Int((v.depthValue * 100).rounded())
            if w > 1, h > 1, d > 1 { parts.append("\(w)×\(h)×\(d) sm") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

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
    // "Usta sahifasi" (`/workflow-instances/`dan to'g'ridan-to'g'ri kelganda) —
    // Order ichidagi nested holatda bular kerak emas, shuning uchun ixtiyoriy.
    let order: String?
    let orderDisplay: String?
    let orderStatus: String?
    let deadline: String?
    let isManual: Bool?

    var isOverdue: Bool {
        guard let deadline, status != "completed" else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: deadline) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }
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

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

// Backend (DRF) xato javobi ikki xil shaklda kelishi mumkin:
// 1. View'da qo'lda `ValidationError("xabar")` ko'tarilganda — `{"detail":
//    ["xabar"]}` (matn EMAS, ro'yxat — DRF shunday normallashtiradi).
// 2. Serializer maydon validatsiyasi muvaffaqiyatsiz bo'lganda (masalan
//    bo'sh telefon) — `"detail"` kaliti umuman yo'q, javob to'g'ridan-to'g'ri
//    `{"phone": ["Bu maydon bo'sh bo'lmasligi kerak."]}` kabi maydon
//    xatolari lug'ati. Ikkalasini ham hisobga olmasa, asl xabar o'rniga
//    umumiy "Xatolik (kod)" ko'rsatilib qolardi.
struct APIErrorPayload: Decodable {
    let detail: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        if let key = DynamicCodingKey(stringValue: "detail") {
            if let text = try? container.decode(String.self, forKey: key) {
                detail = text
                return
            }
            if let list = try? container.decode([String].self, forKey: key), let first = list.first {
                detail = first
                return
            }
        }
        var parts: [String] = []
        for key in container.allKeys {
            if let list = try? container.decode([String].self, forKey: key) {
                parts.append("\(key.stringValue): \(list.joined(separator: ", "))")
            } else if let text = try? container.decode(String.self, forKey: key) {
                parts.append("\(key.stringValue): \(text)")
            }
        }
        detail = parts.isEmpty ? nil : parts.joined(separator: "; ")
    }
}
