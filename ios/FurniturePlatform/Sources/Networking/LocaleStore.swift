import Foundation

/// Let iOS select the bundle language instead of keeping a separate UI override.
/// Language changes go through the app's iOS Settings page.
@MainActor
final class LocaleStore: ObservableObject {
    @Published private(set) var code: String

    init() {
        code = systemAppLocaleCode()
    }

    func t(_ key: String) -> String { translate(code, key) }
    /// Server yuborgan o'zbekcha `*_display` matni o'rniga kalit bo'yicha mahalliy tarjima;
    /// kalit topilmasa (yangi holat) serverdagi matn ko'rsatiladi.
    func display(_ prefix: String, _ key: String?, fallback: String) -> String {
        guard let key, !key.isEmpty else { return fallback }
        let full = "\(prefix)_\(key)"
        let value = translate(code, full)
        return value == full ? fallback : value
    }

    /// Kasb nomi/tavsifi tanlangan tilda (`position_<kalit>` / `position_<kalit>_desc`).
    func position(_ key: String) -> PositionInfo {
        let base = positionInfo(key)
        let label = translate(code, "position_\(key)")
        let desc = translate(code, "position_\(key)_desc")
        return PositionInfo(
            label: label == "position_\(key)" ? base.label : label,
            systemImage: base.systemImage,
            desc: desc == "position_\(key)_desc" ? base.desc : desc
        )
    }

    /// Server yuborgan kasb nomi ("Usta") ni tanlangan tilga o'tkazadi (kalit kelmagani uchun
    /// o'zbekcha nom bo'yicha qidiriladi); topilmasa o'zi qaytadi.
    func localizedRole(_ display: String?) -> String? {
        guard let display else { return nil }
        if let hit = kPositions.first(where: { $0.value.label == display }) {
            return position(hit.key).label
        }
        return display
    }

    func tf(_ key: String, _ args: CVarArg...) -> String { String(format: translate(code, key), arguments: args) }
}
