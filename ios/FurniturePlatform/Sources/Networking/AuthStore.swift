import Combine
import Foundation
import GoogleSignIn
import UIKit

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
    private var connectivityCancellable: AnyCancellable?
    // Tokenlar saqlangan, lekin `/users/me/` hali muvaffaqiyatli yuklanmagan
    // (masalan ilova oflaynda ochilgan). Shu holatda ulanish tiklanganda
    // qayta urinish kerak — aks holda `user`/`isAuthenticated` doim `nil`/
    // `false` bo'lib qolib, Profil "kirilmagan" ko'rinishida qolar edi.
    private var hasStoredTokens = false
    // Google/Telegram orqali yaratilgan yangi hisob backendda
    // `registration_completed=false` bilan boshlanadi — profil to'ldirish
    // qadami shu holatda `/complete-registration/`ga (rol bilan) yuborishi
    // kerak, OTP orqali yaratilganda esa oddiy `/users/me/` PATCH bilan.
    private var needsRoleCompletion = false

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
            hasStoredTokens = true
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
        connectivityCancellable = NotificationCenter.default
            .publisher(for: .connectivityChanged)
            .compactMap { $0.object as? Bool }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in
                guard let self, online, self.hasStoredTokens, self.user == nil else { return }
                Task { await self.loadMe() }
            }
    }

    func login(email: String, password: String) async {
        struct Body: Encodable { let email: String; let password: String }
        errorMessage = nil
        do {
            let tokens: TokenPair = try await APIClient.shared.post(
                "/auth/token/", body: Body(email: email, password: password), auth: false
            )
            hasStoredTokens = true
            await APIClient.shared.setTokens(tokens)
            persist(tokens)
            await loadMe()
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
            needsRoleCompletion = false // OTP: registration_completed allaqachon true
            hasStoredTokens = true
            await APIClient.shared.setTokens(tokens)
            persist(tokens)
            await loadMe()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Google orqali kirish — native Sign-In oqimidan olingan ID token
    /// backendga (`/auth/google/`) yuboriladi, javob boshqa login usullari
    /// bilan bir xil shaklda (`access`/`refresh`/`isNewUser`) keladi.
    func loginWithGoogle() async {
        errorMessage = nil
        guard let presenter = UIApplication.topViewController else {
            errorMessage = "Amalga oshmadi. Qayta urinib ko'ring"
            return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google'dan token olinmadi"
                return
            }
            struct Body: Encodable { let credential: String }
            struct Resp: Decodable { let access: String; let refresh: String; let isNewUser: Bool }
            let resp: Resp = try await APIClient.shared.post(
                "/auth/google/", body: Body(credential: idToken), auth: false
            )
            let tokens = TokenPair(access: resp.access, refresh: resp.refresh)
            isNewUser = resp.isNewUser
            needsRoleCompletion = isNewUser
            hasStoredTokens = true
            await APIClient.shared.setTokens(tokens)
            persist(tokens)
            await loadMe()
        } catch let error as GIDSignInError where error.code == .canceled {
            // foydalanuvchi bekor qildi — xato ko'rsatilmaydi
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Telegram orqali kirish — sessiya yaratadi, botni deep-link bilan
    /// (`https://t.me/<bot>?start=<session_id>`) ochadi, so'ng natijani
    /// so'rab turadi (polling). Callback/redirect kerak emas: Telegram bot
    /// webhook'i orqa fonda sessiyani to'ldiradi, biz shu holatni tekshirib turamiz.
    func loginWithTelegram() async {
        errorMessage = nil
        struct SessionResp: Decodable { let sessionId: String }
        struct BotInfoResp: Decodable { let username: String? }
        struct PollResp: Decodable {
            let status: String
            let access: String?
            let refresh: String?
            let isNewUser: Bool?
        }
        do {
            let session: SessionResp = try await APIClient.shared.post("/auth/telegram/session/", auth: false)
            let botInfo: BotInfoResp = try await APIClient.shared.get("/auth/telegram/bot-info/", auth: false)
            guard let username = botInfo.username else {
                errorMessage = "Telegram bot hozircha sozlanmagan"
                return
            }
            guard let url = URL(string: "https://t.me/\(username)?start=\(session.sessionId)") else {
                errorMessage = "Telegram ochilmadi"
                return
            }
            let opened = await UIApplication.shared.open(url)
            if !opened {
                errorMessage = "Telegram ochilmadi"
                return
            }

            // ~5 daqiqa, 2 soniya oralig'ida — botda "/start" bosilishini kutamiz.
            for _ in 0..<150 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll: PollResp = try await APIClient.shared.get(
                    "/auth/telegram/session/\(session.sessionId)/", auth: false
                )
                guard poll.status == "done", let access = poll.access, let refresh = poll.refresh else {
                    continue
                }
                let tokens = TokenPair(access: access, refresh: refresh)
                isNewUser = poll.isNewUser ?? false
                needsRoleCompletion = isNewUser
                hasStoredTokens = true
                await APIClient.shared.setTokens(tokens)
                persist(tokens)
                await loadMe()
                return
            }
            errorMessage = "Kutish vaqti tugadi. Qayta urinib ko'ring"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Profildan Google hisobini BOG'LASH (login EMAS) — allaqachon
    /// autentifikatsiyalangan foydalanuvchi ilova ichida qo'shimcha kirish
    /// usuli sifatida Google'ni ulaydi. Muvaffaqiyatli bo'lsa `user`ni
    /// yangilaydi (`hasGoogle` true bo'lib qoladi).
    @discardableResult
    func linkGoogle() async -> Bool {
        errorMessage = nil
        guard let presenter = UIApplication.topViewController else {
            errorMessage = "Amalga oshmadi. Qayta urinib ko'ring"
            return false
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google'dan token olinmadi"
                return false
            }
            struct Body: Encodable { let credential: String }
            let me: User = try await APIClient.shared.post(
                "/users/me/google/link/", body: Body(credential: idToken), auth: true
            )
            user = me
            return true
        } catch let error as GIDSignInError where error.code == .canceled {
            return false // foydalanuvchi bekor qildi — xato ko'rsatilmaydi
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Profildan Telegram hisobini BOG'LASH — `loginWithTelegram` bilan
    /// bir xil deep-link+poll naqshi, lekin authenticated "link"
    /// endpointlariga so'rov yuboradi (login emas, joriy hisobga
    /// qo'shimcha bog'lash).
    @discardableResult
    func linkTelegram() async -> Bool {
        errorMessage = nil
        struct SessionResp: Decodable { let sessionId: String }
        struct BotInfoResp: Decodable { let username: String? }
        struct PollResp: Decodable { let status: String }
        do {
            let session: SessionResp = try await APIClient.shared.post(
                "/users/me/telegram/link/session/", auth: true
            )
            let botInfo: BotInfoResp = try await APIClient.shared.get("/auth/telegram/bot-info/", auth: false)
            guard let username = botInfo.username else {
                errorMessage = "Telegram bot hozircha sozlanmagan"
                return false
            }
            guard let url = URL(string: "https://t.me/\(username)?start=\(session.sessionId)") else {
                errorMessage = "Telegram ochilmadi"
                return false
            }
            let opened = await UIApplication.shared.open(url)
            if !opened {
                errorMessage = "Telegram ochilmadi"
                return false
            }

            for _ in 0..<150 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let poll: PollResp = try await APIClient.shared.get(
                    "/users/me/telegram/link/session/\(session.sessionId)/", auth: true
                )
                guard poll.status == "done" else { continue }
                await loadMe()
                return true
            }
            errorMessage = "Kutish vaqti tugadi. Qayta urinib ko'ring"
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Birinchi marta kirgan foydalanuvchi ismini to'ldirishda ishlatiladi.
    /// Google/Telegram orqali yaratilgan hisob uchun `/complete-registration/`
    /// (rol bilan — mobil ilovada doim "customer"), OTP orqali yaratilgan
    /// hisob uchun oddiy `/users/me/` PATCH (qarang `needsRoleCompletion`).
    @discardableResult
    func completeProfile(firstName: String, lastName: String, dateOfBirth: String?) async -> Bool {
        errorMessage = nil
        do {
            var me: User
            if needsRoleCompletion {
                struct Body: Encodable { let role: String; let firstName: String; let lastName: String }
                me = try await APIClient.shared.post(
                    "/users/me/complete-registration/",
                    body: Body(role: "customer", firstName: firstName, lastName: lastName),
                    auth: true
                )
                needsRoleCompletion = false
                // `/complete-registration/` tug'ilgan kunni qabul qilmaydi (rol/profil
                // uchun mo'ljallangan) — kerak bo'lsa alohida PATCH bilan qo'shamiz.
                if let dateOfBirth {
                    struct DobBody: Encodable { let dateOfBirth: String }
                    me = try await APIClient.shared.patch(
                        "/users/me/", body: DobBody(dateOfBirth: dateOfBirth), auth: true
                    )
                }
            } else {
                struct Body: Encodable {
                    let firstName: String; let lastName: String; let dateOfBirth: String?
                }
                me = try await APIClient.shared.patch(
                    "/users/me/", body: Body(firstName: firstName, lastName: lastName, dateOfBirth: dateOfBirth), auth: true
                )
            }
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
        // Keyingi "Google orqali kirish" bosilganda hisob tanlash oynasi qayta
        // chiqishi uchun — aks holda oxirgi Google hisobiga jimgina kirib qolar edi.
        GIDSignIn.sharedInstance.signOut()
        hasStoredTokens = false
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
        } catch let error as APIError where error == .offline {
            // Internet/serverga ulanib bo'lmadi — bu sessiya eskirgani degani
            // emas. Tokenni saqlab qolamiz (chiqarib yubormaymiz), aloqa
            // tiklanganda keyingi urinishda qayta tekshiriladi. Ilgari
            // muvaffaqiyatli kirilgan bo'lsa, foydalanuvchi hamon "kirgan"
            // holatda qoladi — individual ekranlar oflayn holatini o'zi
            // ko'rsatadi (qarang OfflineView).
            if user != nil { isAuthenticated = true }
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
