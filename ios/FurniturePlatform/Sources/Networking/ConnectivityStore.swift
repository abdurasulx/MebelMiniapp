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
            .sink { [weak self] online in self?.isOffline = !online }
    }

    /// Yengil so'rov bilan qayta ulanishni tekshiradi — natijasidan qat'iy
    /// nazar `isOffline` `.connectivityChanged` orqali avtomatik yangilanadi.
    func retry() {
        Task {
            let _: Paginated<Category>? = try? await APIClient.shared.get("/categories/")
        }
    }
}
