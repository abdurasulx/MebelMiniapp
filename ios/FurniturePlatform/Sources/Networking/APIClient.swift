import Foundation

enum APIError: LocalizedError {
    case server(String)
    case decoding
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .decoding: return "Ma'lumotni o'qib bo'lmadi"
        case .unauthorized: return "Avval tizimga kiring"
        }
    }
}

/// Simulatorda Mac'ning localhost'i to'g'ridan-to'g'ri ko'rinadi, lekin haqiqiy
/// qurilma (masalan USB orqali ulangan iPhone) o'zining tarmog'ida ishlaydi —
/// shuning uchun Mac'ning LAN IP manziliga ulanadi (backend shu tarmoqda ishlab turishi kerak).
enum APIConfig {
    static let baseURL: URL = {
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000/api/v1")!
        #else
        return URL(string: "http://192.168.100.185:8000/api/v1")!
        #endif
    }()
}

actor APIClient {
    static let shared = APIClient()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private var accessToken: String?
    private var refreshToken: String?

    func setTokens(_ tokens: TokenPair?) {
        accessToken = tokens?.access
        refreshToken = tokens?.refresh
    }

    // MARK: - Public API

    func get<T: Decodable>(_ path: String, auth: Bool = false) async throws -> T {
        try await send(path: path, method: "GET", body: Data?.none, auth: auth)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool = false) async throws -> T {
        try await send(path: path, method: "POST", body: try encoder.encode(body), auth: auth)
    }

    func post<T: Decodable>(_ path: String, auth: Bool = true) async throws -> T {
        try await send(path: path, method: "POST", body: Data?.none, auth: auth)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B, auth: Bool = true) async throws -> T {
        try await send(path: path, method: "PATCH", body: try encoder.encode(body), auth: auth)
    }

    // MARK: - Core

    private func send<T: Decodable>(path: String, method: String, body: Data?, auth: Bool) async throws -> T {
        let data = try await rawRequest(path: path, method: method, body: body, auth: auth)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func rawRequest(path: String, method: String, body: Data?, auth: Bool, isRetry: Bool = false) async throws -> Data {
        var request = URLRequest(url: APIConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("Server bilan bog'lanib bo'lmadi")
        }

        if http.statusCode == 401, auth, !isRetry, await refreshAccessToken() {
            return try await rawRequest(path: path, method: method, body: body, auth: auth, isRetry: true)
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorPayload.self, from: data).detail) ?? nil
            throw APIError.server(message ?? "Xatolik (\(http.statusCode))")
        }
        return data
    }

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken else { return false }
        struct Body: Encodable { let refresh: String }
        // ROTATE_REFRESH_TOKENS=True bo'lgani uchun javobda yangi refresh ham kelishi mumkin.
        struct RefreshResponse: Decodable { let access: String; let refresh: String? }
        do {
            let tokens: RefreshResponse = try await post("/auth/token/refresh/", body: Body(refresh: refreshToken), auth: false)
            self.accessToken = tokens.access
            if let newRefresh = tokens.refresh {
                self.refreshToken = newRefresh
                NotificationCenter.default.post(name: .authTokensRotated, object: TokenPair(access: tokens.access, refresh: newRefresh))
            }
            return true
        } catch {
            return false
        }
    }
}

extension Notification.Name {
    static let authTokensRotated = Notification.Name("authTokensRotated")
}
