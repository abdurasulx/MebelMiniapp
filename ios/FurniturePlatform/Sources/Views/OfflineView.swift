import SwiftUI

/// Server umuman javob bermaganda (internet yo'q, backend o'chiq) ko'rsatiladigan
/// to'liq ekran holati — xom `URLError` matni o'rniga. Oddiy API xatolari
/// (400/401 va h.k.) buni ishlatmaydi, chunki ular server ishlab turganini
/// bildiradi — faqat `APIError.offline` uchun (qarang `isOffline(_:)`).
struct OfflineView: View {
    let onRetry: () -> Void
    var message: String? = nil

    static func isOffline(_ error: Error?) -> Bool {
        if case .offline = error as? APIError { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandDeep.opacity(0.5))
            Text("Internet aloqasi yo'q")
                .font(.headline)
            Text(message ?? "Serverga ulanib bo'lmadi. Internetingizni tekshirib, qayta urinib ko'ring.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(action: onRetry) {
                Label("Qayta urinish", systemImage: "arrow.clockwise")
                    .font(.subheadline).bold()
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Color.brandDeep)
                    .foregroundStyle(Color.brandPrimary)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }
}
