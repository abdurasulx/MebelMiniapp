import SwiftUI
import UIKit

/// Vida Market dizayn tokenlari — "Forest + Lime" palitra (web `index.css` va
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
    static let appBackground = hex(0xEEECE6)
    static let appBackgroundAlt = hex(0xF2F1EC) // surface-muted
    static let appCard = Color.white

    // Brend — "Forest + Lime"
    static let brand = hex(0x1D3A2F)
    static let brandPressed = hex(0x2A5142)
    static let brandMuted = hex(0x5E6A62)
    static let accent = hex(0xD4F06B) // lime: FAQAT to'ldirish (fill)
    static let onAccent = hex(0x1D3A2F) // lime ustidagi matn
    static let star = hex(0xD9A21B) // reyting yulduzchasi

    // Matn
    static let textPrimary = hex(0x1D3A2F)
    static let textSecondary = hex(0x5E6A62)
    static let textDisabled = hex(0x9AA39D)
    static let onBrand = hex(0xD4F06B) // brend rangi ustidagi matn/ikonka

    // Chegara
    static let appBorder = hex(0xDCDAD2)
    static let disabledBackground = hex(0xE6E4DC)

    // Holatlar
    static let appSuccess = hex(0x2F7D4F)
    static let appWarning = hex(0xB9801F)
    static let appError = hex(0xC2412D)
    static let appInfo = hex(0x3979B7)

    // --- Eski nomlar (mavjud ekranlar buzilmasligi uchun; yangi kodda ishlatmang) ---
    /// Brend rangi ustidagi och rang / yumshoq fon (avval "cream").
    static let brandPrimary = onBrand
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
