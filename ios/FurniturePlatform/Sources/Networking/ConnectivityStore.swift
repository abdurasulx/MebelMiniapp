import Combine
import Foundation

/// Global ulanish holati — `APIClient.performRequest` har bir so'rov
/// natijasini `.connectivityChanged` orqali e'lon qiladi, bu yerda
/// tinglanadi. `RootView` shu `isOffline`ni kuzatib, oflaynda butun ilovani
/// (tab menyusi bilan birga) to'liq ekranli `OfflineView`ga almashtiradi.
@MainActor
final class ConnectivityStore: ObservableObject {
    @Published private(set) var isOffline = false
    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default
            .publisher(for: .connectivityChanged)
            .compactMap { $0.object as? Bool }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] online in self?.note(online: online) }
    }

    // Bitta sekin/uzilgan so'rov butun ilovani "oflayn" ekran bilan yopmasin:
    // ketma-ket 3 ta muvaffaqiyatsizlikdan keyingina oflayn; bitta muvaffaqiyat tiklaydi.
    private static let offlineThreshold = 3
    private var consecutiveFailures = 0

    private func note(online: Bool, definitive: Bool = false) {
        if online {
            consecutiveFailures = 0
            isOffline = false
        } else {
            consecutiveFailures = definitive ? Self.offlineThreshold : consecutiveFailures + 1
            if consecutiveFailures >= Self.offlineThreshold { isOffline = true }
        }
    }

    /// Yengil so'rov bilan qayta ulanishni tekshiradi — natijasidan qat'iy
    /// nazar `isOffline` `.connectivityChanged` orqali avtomatik yangilanadi.
    func retry() {
        Task {
            let result: Paginated<Category>? = try? await APIClient.shared.get("/categories/")
            // "Qayta urinish" — foydalanuvchi so'rovi: muvaffaqiyatsiz bo'lsa darhol oflayn.
            if result == nil { await MainActor.run { self.note(online: false, definitive: true) } }
        }
    }
}
