import Foundation

enum APIError: LocalizedError, Equatable {
    // `statusCode` — masalan 403'ni aniq tekshirish uchun (qarang
    // CartView.checkout: telefon tasdiqlanmagan xatosini ushlash).
    case server(String, statusCode: Int)
    case decoding
    case unauthorized
    // Server umuman javob bermadi (internet yo'q, backend o'chiq, DNS
    // topilmadi, so'rov vaqti tugadi) — HTTP status kodli javoblardan farqli,
    // bu holatda "oflayn" ekrani ko'rsatiladi (qarang Views/OfflineView.swift).
    case offline

    var errorDescription: String? {
        switch self {
        case .server(let msg, _): return msg
        case .decoding: return "Ma'lumotni o'qib bo'lmadi"
        case .unauthorized: return "Avval tizimga kiring"
        case .offline: return "Internetga ulanib bo'lmadi"
        }
    }
}

/// Simulatorda Mac'ning localhost'i to'g'ridan-to'g'ri ko'rinadi, lekin haqiqiy
/// qurilma (masalan USB orqali ulangan iPhone) o'zining tarmog'ida ishlaydi —
/// shuning uchun Mac'ning **Tailscale** IP manziliga ulanadi (Flutter/Android
/// bilan bir xil sabab: oddiy LAN Wi-Fi IP ba'zi tarmoqlarda — AP-izolyatsiya
/// va h.k. — sekin/beqaror bo'lib chiqdi, Tailscale VPN orqali bundan qat'iy
/// nazar barqaror ulanadi). Backend shu tarmoqda ishlab turishi kerak.
enum APIConfig {
    static let baseURL: URL = {
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000/api/v1")!
        #else
        return URL(string: "http://100.69.182.71:8000/api/v1")!
        #endif
    }()

    /// `baseURL.appendingPathComponent(path)` ishlatilmaydi — u `path`ni
    /// fayl-yo'li segmenti deb hisoblab, `?`/`&` kabi so'rov-satr belgilarini
    /// ham foizli kodlab yuboradi (masalan "?lat=1" -> "%3Flat=1"), natijada
    /// `lat`/`lng` parametrli so'rovlar 404 bilan qaytardi. Oddiy string
    /// birlashtirish + `URL(string:)` esa `?`ni to'g'ri so'rov ajratkichi
    /// sifatida tushunadi.
    static func url(for path: String) -> URL {
        URL(string: baseURL.absoluteString + path)!
    }
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

    /// Javob tanasi bo'sh (204) bo'lgan o'chirish so'rovlari uchun — `Data`
    /// qaytaradi, chaqiruvchi odatda natijaga e'tibor bermaydi.
    @discardableResult
    func delete(_ path: String, auth: Bool = true) async throws -> Data {
        try await rawRequest(path: path, method: "DELETE", body: nil, auth: auth)
    }

    /// `multipart/form-data` — rasm yuklash kerak bo'lgan amallar uchun
    /// (masalan bosh sahifa/katalogdagi "rasm bilan qidirish").
    func postMultipartImage<T: Decodable>(
        _ path: String,
        imageData: Data,
        imageFieldName: String = "image",
        fileName: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        fields: [String: String] = [:],
        auth: Bool = false
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"\(imageFieldName)\"; filename=\"\(fileName)\"\r\n"
                .data(using: .utf8)!
        )
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: APIConfig.url(for: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if auth, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("Server bilan bog'lanib bo'lmadi", statusCode: 0)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorPayload.self, from: data).detail) ?? nil
            throw APIError.server(message ?? "Xatolik (\(http.statusCode))", statusCode: http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    // `.cancelled` bundan mustasno: u so'rov eskirib (masalan ekran qayta
    // render bo'lganda yangi so'rov eskisini almashtirganda) URLSession
    // tomonidan bekor qilinganda tashlanadi, server bilan aloqa yo'qligini
    // anglatmaydi. Buni ham `.offline`ga aylantirsak, oddiy ekran o'tishida
    // ham (hatto server 404/200 qaytarayotgan bo'lsa ham) noto'g'ri
    // "oflayn" ko'rsatilar edi.
    private static let nonConnectivityErrorCodes: Set<URLError.Code> = [.cancelled]

    /// Transport darajasidagi xatoni (server umuman topilmadi/javob bermadi)
    /// `.offline`ga aylantiradi — HTTP status kodli javoblar (400/401/500 va
    /// h.k.) bunga tegmaydi, chunki ular `URLSession.data(for:)` muvaffaqiyatli
    /// qaytgandan KEYIN alohida tekshiriladi (qarang `rawRequest`), bu yerga
    /// umuman kirmaydi. Oldin faqat bir nechta aniq `URLError.Code` (masalan
    /// `.notConnectedToInternet`) ushlanardi — Tailscale VPN qayta ulanish
    /// paytida boshqa kodlar (yoki hatto boshqa xato turlari) ham chiqishi
    /// mumkin edi, ular ushlanmasdan yuqoriga chiqib, `AuthStore.loadMe()`ning
    /// umumiy `catch` blokida "sessiya eskirgan" deb noto'g'ri talqin
    /// qilinib, foydalanuvchi bekorga chiqarib yuborilardi — shuning uchun
    /// endi ro'yxatga OLINMAGAN har qanday xato "oflayn" deb hisoblanadi
    /// (faqat `.cancelled` bundan mustasno).
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let result = try await URLSession.shared.data(for: request)
            NotificationCenter.default.post(name: .connectivityChanged, object: true)
            return result
        } catch let error as URLError where Self.nonConnectivityErrorCodes.contains(error.code) {
            throw error
        } catch {
            NotificationCenter.default.post(name: .connectivityChanged, object: false)
            throw APIError.offline
        }
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
        var request = URLRequest(url: APIConfig.url(for: path))
        request.httpMethod = method
        // 3s juda tez edi — mobil tarmoqda oddiy kechikish ham "oflayn" deb
        // noto'g'ri aniqlanardi (endi zararsiz bo'lsa ham — RootView'ni
        // yo'q qilmaydi — keraksiz to'liq ekranli uzilishlarni oldini olamiz).
        request.timeoutInterval = 6
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if auth, let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server("Server bilan bog'lanib bo'lmadi", statusCode: 0)
        }

        if http.statusCode == 401, auth, !isRetry {
            let refreshed = await refreshAccessToken()
            if refreshed == true {
                return try await rawRequest(path: path, method: method, body: body, auth: auth, isRetry: true)
            }
            if refreshed == nil {
                // Yangilash so'rovi tarmoq xatosi bilan muvaffaqiyatsiz tugadi —
                // sessiya haqiqatan ham eskirganini bilmaymiz, shuning uchun bu
                // holatni "chiqib ketilgan" emas, "oflayn" deb hisoblaymiz.
                throw APIError.offline
            }
            // refreshed == false: refresh tokeni haqiqatan ham eskirgan/yaroqsiz —
            // pastda asl 401 javobi bo'yicha APIError.server tashlanadi.
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorPayload.self, from: data).detail) ?? nil
            throw APIError.server(message ?? "Xatolik (\(http.statusCode))", statusCode: http.statusCode)
        }
        return data
    }

    /// `true` — yangilandi. `false` — refresh tokeni haqiqatan ham yaroqsiz
    /// (chiqib ketish kerak). `nil` — tarmoq xatosi bilan tekshirib
    /// bo'lmadi (oflayn — chiqib yubormaslik kerak, keyinroq qayta urinamiz).
    private func refreshAccessToken() async -> Bool? {
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
        } catch let error as APIError where error == .offline {
            return nil
        } catch {
            return false
        }
    }
}

extension Notification.Name {
    static let authTokensRotated = Notification.Name("authTokensRotated")
    /// `object` — `Bool` (`true`: so'rov muvaffaqiyatli, `false`: tarmoq xatosi).
    static let connectivityChanged = Notification.Name("connectivityChanged")
}
