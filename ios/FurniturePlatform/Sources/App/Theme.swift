import SwiftUI
import UIKit

/// Web'dagi (`frontend/src/index.css`) bilan bir xil brend ranglari.
extension Color {
    static let brandPrimary = Color(red: 0xEC / 255, green: 0xC2 / 255, blue: 0x99 / 255)   // #ECC299 — cream
    static let brandDeep = Color(red: 0x4C / 255, green: 0x2C / 255, blue: 0x24 / 255)       // #4C2C24 — jigarrang
    static let brandSecondary = Color(red: 0x34 / 255, green: 0x98 / 255, blue: 0xDB / 255)  // #3498DB
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
