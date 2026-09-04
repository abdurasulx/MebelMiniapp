import CoreLocation
import Foundation

struct AttendanceLocationException: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Bitta "Ishga keldim"/"Ishni tugatdim" bosishi uchun bir martalik
/// joylashuv — `LocationStore`dan farqli (u viloyat aniqlash uchun, davomiy
/// state), bu yerda faqat `async`/`await` orqali bitta natija kerak, va
/// `CLLocation.sourceInformation?.isSimulatedBySoftware` (iOS 15+) orqali
/// joylashuv simulyatsiya qilinganini tekshiradi (docs §8 — fake-GPS himoyasi).
@MainActor
final class AttendanceLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async throws -> CLLocation {
        let authStatus = manager.authorizationStatus
        switch authStatus {
        case .denied, .restricted:
            throw AttendanceLocationException(message: "Joylashuvga ruxsat berilmagan. Sozlamalardan ruxsat bering.")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else { return }
            continuation?.resume(returning: loc)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: AttendanceLocationException(message: "Joylashuv aniqlanmadi. Qayta urining."))
            continuation = nil
        }
    }
}

extension CLLocation {
    /// iOS 15+ — joylashuv simulyator/mock manba orqali kelganini bildiradi
    /// (masalan Xcode simulyatori yoki uchinchi tomon "fake GPS" ilovasi).
    var isSimulated: Bool {
        if #available(iOS 15.0, *) {
            return sourceInformation?.isSimulatedBySoftware ?? false
        }
        return false
    }
}
