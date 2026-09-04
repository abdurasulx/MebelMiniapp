import CryptoKit
import DeviceCheck
import Foundation

/// Apple App Attest — Play Integrity'ning iOS ekvivalenti (docs §8: "Ilova
/// integrity va qurilma xavfsizligi bo'yicha mavjud Apple mexanizmlaridan
/// foydalanish"). To'liq oqim: kalit generatsiya qilish → Apple'dan
/// attestatsiya olish → har bir so'rovda assertion generatsiya qilish →
/// backendga yuborish (backend Apple serverlari bilan tekshiradi).
///
/// Capability Apple Developer portalida yoqilmagan yoki qurilma qo'llab-
/// quvvatlamasa (`DCAppAttestService.isSupported == false`, masalan
/// Simulator'da doim shunday) — bu holatda `nil` qaytaradi, chaqiruvchi
/// (`AttendanceStore`) buni jim qabul qilib `integrity_token`siz davom
/// etadi (backend "not_configured" deb belgilaydi, check-in bloklanmaydi).
enum AppAttestService {
    private static let keyIdDefaultsKey = "app_attest_key_id"

    static func currentAssertion(clientData: Data) async -> String? {
        guard DCAppAttestService.shared.isSupported else { return nil }
        do {
            let keyId = try await keyId()
            let clientHash = Data(SHA256Digest(clientData))
            let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientHash)
            return assertion.base64EncodedString()
        } catch {
            return nil
        }
    }

    private static func keyId() async throws -> String {
        if let saved = UserDefaults.standard.string(forKey: keyIdDefaultsKey) {
            return saved
        }
        let newKeyId = try await DCAppAttestService.shared.generateKey()
        UserDefaults.standard.set(newKeyId, forKey: keyIdDefaultsKey)
        return newKeyId
    }
}

private func SHA256Digest(_ data: Data) -> [UInt8] {
    Array(SHA256.hash(data: data))
}
