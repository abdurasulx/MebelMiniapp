import Foundation
import SwiftUI

/// Backend `GET /app/version/` va 426 `APP_UPDATE_REQUIRED` javobi shakli.
struct AppVersionPolicy: Codable, Equatable {
    var platform: String?
    var currentVersion: String?
    var latestVersion: String?
    var minimumSupportedVersion: String?
    var status: String
    var updateAvailable: Bool?
    var forceUpdate: Bool?
    var storeUrl: String?
    var message: String?
}

/// Sof (toza) qaror mantig'i — alohida test qilish oson.
enum AppVersionDecision: Equatable {
    case allow
    case optionalUpdate(latest: String)
    case forced(AppVersionPolicy)

    static func make(policy: AppVersionPolicy) -> AppVersionDecision {
        let status = policy.status.uppercased()
        if status == "BLOCKED" || (status == "UPDATE_REQUIRED" && policy.forceUpdate == true) {
            return .forced(policy)
        }
        if policy.updateAvailable == true {
            return .optionalUpdate(latest: policy.latestVersion ?? "")
        }
        return .allow
    }
}

enum AppVersionInfo {
    static var current: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

extension Notification.Name {
    /// `object` — `AppVersionPolicy` (426 APP_UPDATE_REQUIRED).
    static let appUpdateRequired = Notification.Name("appUpdateRequired")
}

@MainActor
final class AppVersionStore: ObservableObject {
    private static let cacheKey = "fp.appVersion.policy"
    private static let cacheVersionKey = "fp.appVersion.forVersion"

    /// Bo'sh emas bo'lsa — majburiy yangilash ekrani ko'rsatiladi.
    @Published private(set) var forcedPolicy: AppVersionPolicy?
    /// Majburiy bo'lmagan yangi versiya haqida ogohlantirish (har ishga tushishda bir marta).
    @Published var optionalUpdateVersion: String?
    @Published private(set) var storeUrl: String = ""
    @Published private(set) var isChecking = false

    private var alertShown = false
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .appUpdateRequired, object: nil, queue: .main
        ) { [weak self] note in
            guard let policy = note.object as? AppVersionPolicy else { return }
            Task { @MainActor in self?.applyForced(policy) }
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    private func applyForced(_ policy: AppVersionPolicy) {
        storeUrl = policy.storeUrl ?? storeUrl
        forcedPolicy = policy
        cache(policy)
    }

    func checkOnStartup() async {
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetState") { return }
        await check()
    }

    /// Qayta tekshirish tugmasi ham shuni chaqiradi.
    func check() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let policy = try await APIClient.shared.fetchAppVersionPolicy()
            apply(policy)
            cache(policy)
        } catch {
            // Tarmoq/5xx/o'qib bo'lmadi — bloklamaymiz; kesh faqat joriy versiyaga tegishli bo'lsa.
            if let cached = loadCache(), case .forced = AppVersionDecision.make(policy: cached) {
                apply(cached)
            }
        }
    }

    private func apply(_ policy: AppVersionPolicy) {
        storeUrl = policy.storeUrl ?? ""
        switch AppVersionDecision.make(policy: policy) {
        case .allow:
            forcedPolicy = nil
        case .optionalUpdate(let latest):
            forcedPolicy = nil
            if !alertShown { alertShown = true; optionalUpdateVersion = latest }
        case .forced(let p):
            forcedPolicy = p
        }
    }

    private func cache(_ policy: AppVersionPolicy) {
        guard let data = try? JSONEncoder().encode(policy) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
        UserDefaults.standard.set(AppVersionInfo.current, forKey: Self.cacheVersionKey)
    }

    private func loadCache() -> AppVersionPolicy? {
        guard UserDefaults.standard.string(forKey: Self.cacheVersionKey) == AppVersionInfo.current,
              let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(AppVersionPolicy.self, from: data)
    }

    func openStore() -> Bool {
        guard let url = URL(string: storeUrl), !storeUrl.isEmpty else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
