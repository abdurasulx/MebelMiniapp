import Combine
import Foundation

/// Foydalanuvchi profilida tanlaydigan ko'rinish rejimi — bitta hisob ham
/// xaridor, ham (agar biror firmada ishlasa) usta sifatida ilovadan foydalana
/// oladi. Faqat mahalliy UI holati, backend `role`ga bog'liq emas.
enum AppMode: String {
    case customer, worker
}

struct OTPRequestResult {
    let debugCode: String?
    let resendAfter: Int
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isNewUser = false
    @Published var errorMessage: String?
    @Published var appMode: AppMode = .customer {
        didSet { defaults.set(appMode.rawValue, forKey: appModeKey) }
    }
    // Multi-role xodim qaysi kasb bilan ishlayotgani (web'dagi "active_position"
    // bilan bir xil naqsh) — bitta kasbi bo'lsa avtomatik shu qiymat, bir
    // nechtasi bo'lsa Profil ekranidagi RolePicker orqali tanlanadi.
    @Published var activePosition: String? {
        didSet {
            if let activePosition {
                defaults.set(activePosition, forKey: activePositionKey)
            } else {
                defaults.removeObject(forKey: activePositionKey)
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let tokensKey = "fp.tokens"
    private let appModeKey = "fp.appMode"
    private let activePositionKey = "fp.activePosition"
    private var cancellable: AnyCancellable?

    init() {
        // UITest'lar har bir test mustaqil bo'lishi uchun oldingi sessiyani tozalab boshlaydi.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetState") {
            defaults.removeObject(forKey: tokensKey)
        }
        if let saved = defaults.string(forKey: appModeKey), let mode = AppMode(rawValue: saved) {
            appMode = mode
        }
        activePosition = defaults.string(forKey: activePositionKey)
        if let data = defaults.data(forKey: tokensKey),
           let tokens = try? JSONDecoder().decode(TokenPair.self, from: data) {
            Task {
                await APIClient.shared.setTokens(tokens)
                await self.loadMe()
            }
        }
        cancellable = NotificationCenter.default
            .publisher(for: .authTokensRotated)
            .compactMap { $0.object as? TokenPair }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tokens in self?.persist(tokens) }
    }

    func login(email: String, password: String) async {
        struct Body: Encodable { let email: String; let password: String }
        errorMessage = nil
        do {
            let tokens: TokenPair = try await APIClient.shared.post(
                "/auth/token/", body: Body(email: email, password: password), auth: false
            )
            await APIClient.shared.setTokens(tokens)
            persist(tokens)
            await loadMe()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register(email: String, password: String, firstName: String, phone: String) async {
        struct Body: Encodable {
            let email: String; let password: String
            let firstName: String; let phone: String; let role: String
        }
        errorMessage = nil
        do {
            let _: User = try await APIClient.shared.post(
                "/auth/register/",
                body: Body(email: email, password: password, firstName: firstName, phone: phone, role: "customer"),
                auth: false
            )
            await login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// SMS-tasdiqlash: kod so'raladi. Hozircha SMS provayder ulanmagani uchun
    /// backend kodni javobda ham qaytaradi (`debug_code`) — ekranda shu ko'rsatiladi.
    /// `resend_after` — qayta yuborishgacha eng kam kutish vaqti (countdown shundan boshlanadi).
    func requestOTP(phone: String) async -> OTPRequestResult? {
        struct Body: Encodable { let phone: String }
        struct Resp: Decodable { let detail: String; let debugCode: String?; let resendAfter: Int? }
        errorMessage = nil
        do {
            let resp: Resp = try await APIClient.shared.post("/auth/otp/request/", body: Body(phone: phone), auth: false)
            return OTPRequestResult(debugCode: resp.debugCode, resendAfter: resp.resendAfter ?? 60)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Muvaffaqiyatli tasdiqlangach `isNewUser` yangilanadi — birinchi marta
    /// kirgan foydalanuvchidan ism/familiya so'rash kerakligini bildiradi.
    @discardableResult
    func verifyOTP(phone: String, code: String) async -> Bool {
        struct Body: Encodable { let phone: String; let code: String }
        struct Resp: Decodable { let access: String; let refresh: String; let isNewUser: Bool }
        errorMessage = nil
        do {
            let resp: Resp = try await APIClient.shared.post(
                "/auth/otp/verify/", body: Body(phone: phone, code: code), auth: false
            )
            let tokens = TokenPair(access: resp.access, refresh: resp.refresh)
            isNewUser = resp.isNewUser
            await APIClient.shared.setTokens(tokens)
            persist(tokens)
            await loadMe()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Birinchi marta kirgan foydalanuvchi ismini to'ldirishda ishlatiladi.
    @discardableResult
    func completeProfile(firstName: String, lastName: String, dateOfBirth: String?) async -> Bool {
        struct Body: Encodable {
            let firstName: String; let lastName: String; let dateOfBirth: String?
        }
        errorMessage = nil
        do {
            let me: User = try await APIClient.shared.patch(
                "/users/me/", body: Body(firstName: firstName, lastName: lastName, dateOfBirth: dateOfBirth), auth: true
            )
            user = me
            isNewUser = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() {
        defaults.removeObject(forKey: tokensKey)
        Task { await APIClient.shared.setTokens(nil) }
        user = nil
        isAuthenticated = false
        appMode = .customer
        activePosition = nil
    }

    /// Xodim rejimiga o'tish — bitta kasbi bo'lsa shu avtomatik, bir
    /// nechtasi bo'lsa RolePicker orqali tanlangan `position` beriladi.
    func enterWorkerMode(_ position: String) {
        activePosition = position
        appMode = .worker
    }

    func refreshUser() async {
        await loadMe()
    }

    private func loadMe() async {
        do {
            let me: User = try await APIClient.shared.get("/users/me/", auth: true)
            self.user = me
            self.isAuthenticated = true
        } catch {
            logout()
        }
    }

    private func persist(_ tokens: TokenPair) {
        if let data = try? JSONEncoder().encode(tokens) {
            defaults.set(data, forKey: tokensKey)
        }
    }
}
