import Foundation

/// Mebel firmasi xodim kasblari — backend `Employee.Position` bilan bir xil
/// (web: `frontend/src/positions.js`, Flutter: `positions.dart`ga mos).
struct PositionInfo {
    let label: String
    let systemImage: String
    let desc: String
}

let kPositions: [String: PositionInfo] = [
    "usta": PositionInfo(label: "Usta", systemImage: "hammer.fill", desc: "Ishlab chiqarish"),
    "sotuvchi": PositionInfo(label: "Sotuvchi", systemImage: "cart.fill", desc: "Savdo va mijozlar"),
    "ornatuvchi": PositionInfo(label: "O'rnatuvchi", systemImage: "wrench.fill", desc: "Montaj va o'rnatish"),
    "dizayner": PositionInfo(label: "Dizayner", systemImage: "paintpalette.fill", desc: "Loyiha va dizayn"),
    "omborchi": PositionInfo(label: "Omborchi", systemImage: "shippingbox.fill", desc: "Ombor va materiallar"),
    "haydovchi": PositionInfo(label: "Yetkazib beruvchi", systemImage: "box.truck.fill", desc: "Yetkazib berish"),
    "menejer": PositionInfo(label: "Menejer", systemImage: "list.clipboard.fill", desc: "Boshqaruv"),
]

func positionInfo(_ key: String) -> PositionInfo {
    kPositions[key] ?? PositionInfo(label: key, systemImage: "person.crop.circle", desc: "")
}
