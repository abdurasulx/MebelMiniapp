import CryptoKit
import Foundation

/// GET javoblarining diskdagi + xotiradagi keshi (stale-while-revalidate uchun).
/// `APIClient.getCached` ishlatadi: saqlangan javob darhol qaytadi, server fonda
/// so'raladi va farq bo'lsa kesh yangilanadi.
final class ResponseCache: @unchecked Sendable {
    static let shared = ResponseCache()

    private let lock = NSLock()
    private var memory: [String: Data] = [:]
    private let directory: URL?
    private let maxBodyBytes = 2 * 1024 * 1024

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        directory = base?.appendingPathComponent("resp_cache", isDirectory: true)
        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(_ key: String) -> URL? {
        guard let directory else { return nil }
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest + ".json")
    }

    func read(_ key: String) -> Data? {
        lock.lock()
        if let hit = memory[key] { lock.unlock(); return hit }
        lock.unlock()
        guard let url = fileURL(key), let data = try? Data(contentsOf: url) else { return nil }
        lock.lock(); memory[key] = data; lock.unlock()
        return data
    }

    func write(_ key: String, _ data: Data) {
        guard data.count <= maxBodyBytes else { return }
        lock.lock(); memory[key] = data; lock.unlock()
        if let url = fileURL(key) { try? data.write(to: url, options: .atomic) }
    }

    /// Chiqishda (logout) barcha keshni tozalaydi.
    func clear() {
        lock.lock(); memory.removeAll(); lock.unlock()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
