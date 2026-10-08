import SwiftUI
import UIKit

/// Vida Market dizayn tokenlari — iliq, premium palitra (web `index.css` va
/// Flutter `theme.dart` bilan bir xil). Ranglar FAQAT shu yerda aniqlanadi.
private func hex(_ value: UInt32) -> Color {
    Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

extension Color {
    // Fonlar
    static let appBackground = hex(0xFAF5EF)
    static let appBackgroundAlt = hex(0xF2E6D8)
    static let appCard = Color.white

    // Brend
    static let brand = hex(0x493027)
    static let brandPressed = hex(0x38231D)
    static let brandMuted = hex(0x805C46)
    static let accent = hex(0xC58B5A)

    // Matn
    static let textPrimary = hex(0x30231E)
    static let textSecondary = hex(0x796B61)
    static let textDisabled = hex(0xA69A90)
    static let onBrand = hex(0xFAF5EF)

    // Chegara
    static let appBorder = hex(0xE5D7C8)
    static let disabledBackground = hex(0xEEE7E0)

    // Holatlar
    static let appSuccess = hex(0x27865A)
    static let appWarning = hex(0xC58A36)
    static let appError = hex(0xC94C4C)
    static let appInfo = hex(0x3979B7)

    // --- Eski nomlar (mavjud ekranlar buzilmasligi uchun; yangi kodda ishlatmang) ---
    /// Brend rangi ustidagi och rang / yumshoq fon (avval "cream").
    static let brandPrimary = appBackgroundAlt
    static let brandDeep = brand
    static let brandSecondary = brandMuted
}

/// Asosiy ekran foni (List/Form uchun tizim kulrang fonini yashiradi).
extension View {
    func appScreenBackground() -> some View {
        self.scrollContentBackground(.hidden)
            .containerBackground(Color.appBackground, for: .navigation)
            .background(Color.appBackground)
    }
}

extension UIColor {
    /// Backend `Variant.color_hex` maydonidan keladigan "#RRGGBB" qiymatini o'qiydi —
    /// AR material tint uchun (web'dagi `hexToRgba` bilan bir xil vazifa).
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
