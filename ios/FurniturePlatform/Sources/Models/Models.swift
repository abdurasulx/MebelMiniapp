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
    let phoneVerified: Bool?
    let hasGoogle: Bool?
    let hasTelegram: Bool?
    // Faol ish o'rnining to'lov turi (fixed/fixed_bonus/commission/hourly/
    // piecework) — Davomat (check-in/check-out) faqat "hourly" (soatbay)
    // xodimlar uchun ko'rsatiladi (qarang WorkerHomeView.swift).
    let payType: String?
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

/// Backend hisoblagan narx bloki (`pricing`): chegirmani klient O'ZI hisoblamaydi.
struct PricingInfo: Codable {
    let originalPrice: Double
    let discountPercent: Double
    let discountAmount: Double
    let finalPrice: Double

    var hasDiscount: Bool { discountAmount > 0 && finalPrice < originalPrice }
}

/// Firmaning yetkazib berish shartlari; sozlanmagan bo'lsa backend `null` beradi.
struct DeliveryInfo: Codable {
    let free: Bool
    let price: Double
    let minDays: Int
    let maxDays: Int
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
    // Omborda tayyor turgan dona soni (qarang backend VariantSerializer.
    // get_available_quantity) — mijozga darhol berish mumkinligini bildiradi.
    let availableQuantity: Int?
    // Chegirma (backend `VariantSerializer`): faol bo'lsa kartada eski narx
    // chizilgan holda va foiz bilan ko'rsatiladi.
    let discountActive: Bool?
    let effectiveBasePrice: String?
    let discountPercent: String?
    /// Backend `pricing` bloki (bo'lsa — yagona haqiqat manbai).
    let pricing: PricingInfo?

    /// `pricing` bor bo'lsa shu, aks holda eski maydonlardan yig'iladi (orqaga moslik).
    var effectivePricing: PricingInfo {
        if let pricing { return pricing }
        let original = basePriceValue
        guard discountActive == true, let eff = effectiveBasePrice.flatMap(Double.init), eff < original else {
            return PricingInfo(originalPrice: original, discountPercent: 0, discountAmount: 0, finalPrice: original)
        }
        return PricingInfo(
            originalPrice: original,
            discountPercent: discountPercent.flatMap(Double.init) ?? 0,
            discountAmount: original - eff,
            finalPrice: eff
        )
    }

    /// Chegirma hisobga olingan yakuniy narx (1 m³ uchun) — hisob-kitoblarda shu ishlatiladi.
    var effectivePriceValue: Double { effectivePricing.finalPrice }
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
    // Model faylining o'zidan (geometriyadan) avtomatik hisoblangan haqiqiy
    // o'lcham (backend `apps/assets/geometry.py::extract_bbox`) — `Variant.width/
    // height/depth`dan farqli, bu qo'lda kiritiladigan/o'zgartiriladigan
    // maydon emas, doim 3D modelning o'ziga mos keladi.
    let bboxWidth: String?
    let bboxHeight: String?
    let bboxDepth: String?

    var bboxWidthValue: Double? { bboxWidth.flatMap(Double.init) }
    var bboxHeightValue: Double? { bboxHeight.flatMap(Double.init) }
    var bboxDepthValue: Double? { bboxDepth.flatMap(Double.init) }
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
    // Faqat shu firmadan YAKUNLANGAN buyurtmasi bor mijozga true (qarang
    // backend CompanySerializer.get_can_review) — "Baho qoldirish" formasi
    // shunga qarab ko'rsatiladi/yashiriladi (CompanyShopView).
    let canReview: Bool?

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

/// Server render qilgan bitta rakurs (hero/front/side/back/top).
struct RenderShot: Codable {
    let key: String
    let urls: [String: [String: String]]?

    func url(_ size: String) -> String? { urls?[size]?["webp"] }
}

/// Bitta variantning render rasmlari (3D modeldan).
struct RenderGroup: Codable {
    let variant: String
    let slug: String
    let variantId: String?
    let shots: [RenderShot]
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
    // Butun mahsulot bo'yicha (variantga bog'lanmaganlar ham) omborda
    // tayyor turgan dona soni — kartochkada belgisi uchun (qarang backend
    // ProductSerializer.get_available_quantity).
    let availableQuantity: Int?
    // Marketplace maydonlari (backend: pricing/company_is_verified/delivery/category_image_url).
    let pricing: PricingInfo?
    let companyIsVerified: Bool?
    let delivery: DeliveryInfo?
    let categoryImageUrl: String?
    /// 3D modeldan server render qilgan rasmlar (variantlar bo'yicha); render tayyor bo'lmasa bo'sh.
    let renders: [RenderGroup]?

    var liked: Bool { isLiked ?? false }
    var isVerified: Bool { companyIsVerified ?? false }

    /// Kartochka/sahifada ko'rsatiladigan narx: backend `pricing` (eng arzon variant),
    /// bo'lmasa birinchi variantdan.
    var displayPricing: PricingInfo? { pricing ?? variants.first?.effectivePricing }

    /// Kartochkada nomdan keyin ko'rsatiladigan qisqa xususiyat qatori —
    /// masalan "kulrang · 60×90×60 sm".
    var attributeSummary: String? {
        var parts: [String] = []
        if let colorTag, !colorTag.isEmpty { parts.append(colorTag) }
        // O'lcham endi variantning qo'lda kiritiladigan (hozir doim standart
        // 1x1x1 bo'lib qolgan) maydonidan emas — 3D model faylining o'zidan
        // (geometriyadan) hisoblangan haqiqiy o'lchamdan (`bbox_*`) olinadi,
        // model hali tayyor bo'lmasa variantning o'z qiymatiga tushamiz.
        let model = variants.first?.model3d ?? model3d
        let v = variants.first
        let w = model?.bboxWidthValue ?? v?.widthValue
        let h = model?.bboxHeightValue ?? v?.heightValue
        let d = model?.bboxDepthValue ?? v?.depthValue
        if let w, let h, let d {
            let wi = Int((w * 100).rounded())
            let hi = Int((h * 100).rounded())
            let di = Int((d * 100).rounded())
            if wi > 1, hi > 1, di > 1 { parts.append("\(wi)×\(hi)×\(di) sm") }
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

    /// Tanlangan variantning galereyasi: server render (hero → front → side → back → top),
    /// so'ng sotuvchining haqiqiy fotolari; render bo'lmasa — eski galereya.
    func galleryUrls(for variant: Variant?) -> [String] {
        guard let renders, !renders.isEmpty else { return galleryUrls }
        func slugify(_ v: String) -> String {
            v.lowercased()
                .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        var group: RenderGroup?
        if let variant {
            group = renders.first { $0.variantId == variant.id } ?? renders.first { $0.slug == slugify(variant.name) }
        }
        let g = group ?? renders[0]
        let order = ["hero", "front", "side", "back", "top"]
        let shots = g.shots.sorted { (order.firstIndex(of: $0.key) ?? 99) < (order.firstIndex(of: $1.key) ?? 99) }
        return shots.compactMap { $0.url("1600") } + images.compactMap(\.imageUrl)
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
    let description: String?
    let stageDisplay: String?
    let roleDisplay: String?
    let employeeName: String?
    let status: String
    let statusDisplay: String
    let isAvailable: Bool
    let photoRequirement: String
    let commentRequirement: String?
    // "Usta sahifasi" (`/workflow-instances/`dan to'g'ridan-to'g'ri kelganda) —
    // Order ichidagi nested holatda bular kerak emas, shuning uchun ixtiyoriy.
    let order: String?
    let orderDisplay: String?
    let orderStatus: String?
    let deadline: String?
    let isManual: Bool?
    let updates: [WorkflowProgressUpdate]?
    let openApplicationsCount: Int?
    let myApplicationStatus: String?
    // Ish turi (WorkTypes katalogi) va xom ashyo — backendda avtomatik
    // narx/ombor hisobi uchun ishlatiladi, bu yerda faqat ko'rsatish uchun.
    let workTypeName: String?
    let workTypeUnitDisplay: String?
    let rawMaterialName: String?
    let rawMaterialUnit: String?
    let cuttingInstruction: String?
    let quantity: String?
    let materialConsumed: Bool?
    let approvedAt: String?
    let approvedByName: String?
    let cancelledAt: String?
    let cancelledByName: String?

    // "Bajarildi", "Tasdiqlangan" va "Bekor qilindi" — barchasi yakuniy
    // holatlar, ular bo'yicha muddat o'tganini ko'rsatish ma'nosiz.
    var isOverdue: Bool {
        guard let deadline, !Self.terminalStatuses.contains(status) else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: deadline) else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    static let terminalStatuses: Set<String> = ["completed", "approved", "cancelled"]
}

/// Bosqich bo'yicha usta qo'shgan yangilanish (rasm + izoh) — mijoz
/// tomonida faqat o'qish uchun (web'dagi WorkflowPanel bilan bir xil).
struct WorkflowProgressUpdate: Codable, Identifiable {
    let id: String
    let imageUrl: String?
    let comment: String?
    let employeeName: String?
    let isCompletion: Bool?
    let createdAt: String?
}

/// Ombor — faqat ko'rish uchun (mobil'da hozircha faqat o'qish, boshqaruv
/// veb-portalda).
struct Warehouse: Codable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let kindDisplay: String
    let address: String
}

struct MaterialStock: Codable, Identifiable {
    let id: String
    let materialName: String
    let materialUnit: String
    let quantity: String
    let materialUnitCost: String
}

/// Qayta ishlatsa bo'ladigan bo'lak — `width` bo'lsa VARAQ (eni x bo'yi),
/// bo'lmasa CHIZIQLI (faqat uzunlik) qoldiq.
struct MaterialRemnantItem: Codable, Identifiable {
    let id: String
    let materialName: String
    let materialUnit: String
    let length: String
    let width: String?
    let quantity: Int
}

/// AR uchun bir marta yaratilib, keyin qayta-qayta ochib turiladigan
/// mahsulotlar to'plami ("loyiha") — FAZOVIY (position/rotation) ma'lumot
/// ATAYIN saqlanmaydi: ARKit dunyo koordinatasi har safar yangi seansda
/// noldan boshlanadi va faqat o'sha fizik xonada ma'noli, shuning uchun har
/// safar AR ochilganda foydalanuvchi mahsulotlarni xonaga qaytadan
/// joylashtiradi (qarang MultiARPlacementView).
struct ARCollection: Codable, Identifiable {
    let id: String
    let name: String
    let items: [ARCollectionItem]
    let itemCount: Int
    let createdAt: String
}

struct ARCollectionItem: Codable, Identifiable {
    let id: String
    let product: Product
    let variantId: String?
    let createdAt: String

    var variant: Variant? {
        guard let variantId else { return product.variants.first }
        return product.variants.first(where: { $0.id == variantId }) ?? product.variants.first
    }

    /// Ko'p materialli mahsulotlarda variant o'zining alohida 3D faylini
    /// olishi mumkin (qarang ProductDetailView.activeModel3d bilan bir xil naqsh).
    var activeModel3d: Model3D? {
        if let vm = variant?.model3d, vm.status == "ready" { return vm }
        return product.model3d
    }
}

/// Ilova-ichi xabarnoma — mijozga buyurtma holati, xodimga vazifa
/// tayinlash/tayyorlik xabarlari (qarang backend apps.notifications).
struct AppNotification: Codable, Identifiable {
    let id: String
    let notifType: String
    let notifTypeDisplay: String
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
}

/// Xodimning oylik ish haqi hisob-kitobi — web'dagi `MyPayslips`
/// (FirmaPayroll.jsx) bilan bir xil maydonlar, faqat o'ziniki
/// (`GET /payslips/` xodim uchun avtomatik shu bilan cheklangan).
struct Payslip: Codable, Identifiable {
    let id: String
    let period: String
    let payType: String
    let payTypeDisplay: String
    let baseSalary: String
    let tasksCompleted: Int
    let bonusPerTask: String
    let bonusAmount: String
    let commissionSales: String
    let commissionAmount: String
    let workedHours: String
    let hourlyAmount: String
    let workflowEarnings: String
    let completedTasksAmount: String
    let kpiMet: Bool
    let kpiBonusAmount: String
    let totalAmount: String
    let isPaid: Bool
    /// Avans/to'lovlar yig'indisi (backend `Payslip.paid_total`); eski javoblarda bo'lmasligi mumkin.
    let paidTotal: String?
}

/// Maosh varaqasi bo'yicha bitta to'lov (avans yoki yakuniy) — `/payslips/<id>/payments/`.
struct PayslipPayment: Codable, Identifiable {
    let id: String
    let kind: String
    let kindDisplay: String
    let amount: String
    let paidAt: String
    let note: String?
    let recordedByName: String?
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

// Backend (DRF) xato javobi UCH xil shaklda kelishi mumkin:
// 1. View'da qo'lda `ValidationError("xabar")` ko'tarilganda — javob
//    to'g'ridan-to'g'ri BUTUN TANASI bo'yicha `["xabar"]` (matn EMAS,
//    ro'yxat — DRF `exc.detail` list bo'lganda uni "detail" kaliti bilan
//    o'rab qo'ymaydi, bevosita shu ro'yxatni qaytaradi). Aynan shu shaklni
//    hisobga olmagani uchun avval doim umumiy "Xatolik (400)" ko'rsatilib
//    qolgan edi (masalan "bu Telegram hisobi allaqachon bog'langan" kabi
//    aniq xabarlar o'rniga).
// 2. `{"detail": "xabar"}` yoki `{"detail": ["xabar"]}` — APIException'ning
//    boshqa pastki sinflari (masalan qo'lda `Response({"detail": ...})`).
// 3. Serializer maydon validatsiyasi muvaffaqiyatsiz bo'lganda (masalan
//    bo'sh telefon) — `"detail"` kaliti umuman yo'q, javob to'g'ridan-to'g'ri
//    `{"phone": ["Bu maydon bo'sh bo'lmasligi kerak."]}` kabi maydon
//    xatolari lug'ati. Uchalasini ham hisobga olmasa, asl xabar o'rniga
//    umumiy "Xatolik (kod)" ko'rsatilib qolardi.
struct APIErrorPayload: Decodable {
    let detail: String?

    init(from decoder: Decoder) throws {
        // 1-holat: butun javob tanasi bevosita ro'yxat.
        if let single = try? decoder.singleValueContainer(),
           let list = try? single.decode([String].self), let first = list.first {
            detail = first
            return
        }
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

