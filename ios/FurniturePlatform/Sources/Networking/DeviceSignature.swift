import CryptoKit
import Foundation

/// Backend'dagi qo'shimcha xavfsizlik qatlami (nwupdate.md §4-10) uchun
/// mijoz tomoni — Flutter'dagi `device_signature.dart` bilan bir xil
/// mantiq, faqat Swift'da: har bir API so'roviga HMAC-SHA256 imzo +
/// `day_delta` + `timesnap` + `nonce` headerlarini qo'shadi (qarang
/// `APIClient.swift`, `apps/notifications/security.py`).
///
/// MUHIM: bu ilova ichidagi "sir" reverse-engineering'dan himoyalanmagan —
/// asosiy xavfsizlik BARIBIR Access/Refresh Token orqali ta'minlanadi, bu
/// faqat qo'shimcha (replay/tampering'ni qiyinlashtiruvchi) qatlam.
actor DeviceSignature {
    static let shared = DeviceSignature()

    private static let kDeviceId = "device_signature_id"
    private static let kLastUpdated = "device_signature_last_updated_ms"
    private static let kRegistered = "device_signature_registered"

    // Backend'dagi DEVICE_HMAC_SECRET (`.env`) bilan BIR XIL bo'lishi
    // SHART — aks holda HAR BIR imzo SIGNATURE_INVALID bilan rad etiladi
    // (Flutter tomonda aynan shu sabab bilan sinovda muvaffaqiyatsiz
    // bo'lgan edi, qarang device_signature.dart).
    private static let secret = "Vida7kQ3mN9pXr2LsT8wZcF5hJyU4bE6"

    private let defaults = UserDefaults.standard
    private var deviceId: String
    private let deviceName: String
    private let vcode: Int
    private var lastUpdated: Date?
    private var registered: Bool

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Self.kDeviceId) {
            deviceId = existing
        } else {
            let generated = Self.randomHex()
            defaults.set(generated, forKey: Self.kDeviceId)
            deviceId = generated
        }
        let lastMs = defaults.double(forKey: Self.kLastUpdated)
        lastUpdated = lastMs > 0 ? Date(timeIntervalSince1970: lastMs / 1000) : nil
        registered = defaults.bool(forKey: Self.kRegistered)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        deviceName = "iOS \(version)"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        vcode = Int(buildNumber ?? "") ?? 0
    }

    private static func randomHex(_ bytes: Int = 16) -> String {
        (0..<bytes).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    var currentDeviceId: String { deviceId }
    var currentDeviceName: String { deviceName }
    var currentVcode: Int { vcode }

    /// Har bir HTTP so'roviga qo'shiladigan headerlar to'plami. Qurilma
    /// hali backend'da RO'YXATDAN O'TMAGAN bo'lsa bo'sh xarita qaytaradi —
    /// aks holda ilova ochilishida parallel ketayotgan boshqa so'rovlar
    /// `register_device`dan OLDIN backend'ga signature bilan yetib borib,
    /// hali mavjud bo'lmagan qurilma uchun "DEVICE_REVOKED" xatosi bilan
    /// rad etilar edi (qarang device_signature.dart bir xil izoh).
    func buildHeaders() -> [String: String] {
        guard registered else { return [:] }

        let now = Date()
        let dayDelta = lastUpdated.map { Self.daysBetween($0, now) } ?? 0
        let timesnap = Int(now.timeIntervalSince1970) / 300
        let nonce = Self.randomHex(12)

        let payload = "\(deviceId):\(deviceName):\(vcode):\(dayDelta):\(timesnap):\(nonce)"
        let key = SymmetricKey(data: Data(Self.secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        let signatureHex = signature.map { String(format: "%02x", $0) }.joined()

        return [
            "X-Device-Id": deviceId,
            "X-Dev-Name": deviceName,
            "X-Vcode": "\(vcode)",
            "X-Day-Delta": "\(dayDelta)",
            "X-Timesnap": "\(timesnap)",
            "X-Nonce": nonce,
            "X-Signature": signatureHex,
        ]
    }

    private static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let calendar = Calendar.current
        let da = calendar.startOfDay(for: a)
        let db = calendar.startOfDay(for: b)
        return calendar.dateComponents([.day], from: da, to: db).day ?? 0
    }

    /// So'rov MUVAFFAQIYATLI qabul qilingach (401/403 emas) chaqiriladi —
    /// server `last_seen`sini mahalliy tarzda ko'zguga oladi, shunda
    /// KEYINGI so'rovning `day_delta`si serverning kutgan qiymati bilan
    /// mos keladi (qarang apps/notifications/security.py::validate_request).
    func markSuccess() {
        let now = Date()
        lastUpdated = now
        defaults.set(now.timeIntervalSince1970 * 1000, forKey: Self.kLastUpdated)
    }

    /// `register_device` MUVAFFAQIYATLI tugagach chaqiriladi — shundan
    /// keyingina so'rovlarga imzo qo'shila boshlaydi.
    func markRegistered() {
        guard !registered else { return }
        registered = true
        defaults.set(true, forKey: Self.kRegistered)
        markSuccess()
    }

    /// Logout bo'lganda chaqiriladi — backend qurilma yozuvini butunlay
    /// o'chiradi (`unregister_device`), shuning uchun mahalliy holat ham
    /// "ro'yxatdan o'tmagan"ga qaytariladi.
    func markUnregistered() {
        registered = false
        defaults.set(false, forKey: Self.kRegistered)
    }
}
