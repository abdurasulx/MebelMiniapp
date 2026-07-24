import Foundation

/// Til holati — profil ekranidan tanlanadi, qurilmada saqlanadi.
/// Flutter'dagi `lib/locale_store.dart` bilan bir xil.
@MainActor
final class LocaleStore: ObservableObject {
    private static let prefKey = "fp.locale"

    @Published private(set) var code: String

    init() {
        code = UserDefaults.standard.string(forKey: Self.prefKey) ?? defaultLocaleCode
    }

    func setLocale(_ code: String) {
        self.code = code
        UserDefaults.standard.set(code, forKey: Self.prefKey)
    }

    func t(_ key: String) -> String { translate(code, key) }
}
