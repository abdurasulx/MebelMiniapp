import Foundation
import UIKit

/// Apple'ning rasmiy "jailbreak aniqlash" APIsi yo'q — bu odatdagi
/// community-darajadagi heuristika (Cydia yo'llari, sandbox tashqarisiga
/// yozish imkoniyati, `cydia://` scheme) — 100% kafolat bermaydi, lekin
/// eng keng tarqalgan jailbreak vositalarini aniqlaydi (docs §8).
enum JailbreakDetector {
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/stash",
        ]
        for path in suspiciousPaths where FileManager.default.fileExists(atPath: path) {
            return true
        }

        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            return true
        }

        let testPath = "/private/jailbreak_test_\(UUID().uuidString).txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            return false
        }
        #endif
    }
}
