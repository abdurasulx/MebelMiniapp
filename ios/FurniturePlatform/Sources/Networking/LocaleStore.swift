import Foundation

/// Til holati — profil ekranidan tanlanadi, qurilmada saqlanadi. Birinchi
/// marta ochilganda (hali qo'lda tanlanmagan bo'lsa) qurilma tiliga qarab
/// avtomatik aniqlanadi — qo'llab-quvvatlanmasa "O'zbekcha"ga qaytadi.
/// Flutter'dagi `lib/locale_store.dart` bilan bir xil.
@MainActor
final class LocaleStore: ObservableObject {
    private static let prefKey = "fp.locale"

    @Published private(set) var code: String

    init() {
        code = UserDefaults.standard.string(forKey: Self.prefKey) ?? Self.detectDeviceLocale()
    }

    private static func detectDeviceLocale() -> String {
        for preferred in Locale.preferredLanguages {
            let languageCode = Locale(identifier: preferred).language.languageCode?.identifier
            if let languageCode, appLocales.contains(where: { $0.code == languageCode }) {
                return languageCode
            }
        }
        return defaultLocaleCode
    }

    func setLocale(_ code: String) {
        self.code = code
        UserDefaults.standard.set(code, forKey: Self.prefKey)
    }

    func t(_ key: String) -> String { translate(code, key) }
}
