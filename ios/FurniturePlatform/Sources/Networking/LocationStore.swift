import CoreLocation
import Foundation

enum LocationStatus {
    case idle, loading, granted, denied, unavailable
}

/// GPS orqali foydalanuvchi qaysi viloyatda ekanini aniqlaydi — o'sha
/// viloyatdagi (yoki viloyati ko'rsatilmagan) firmalarning mahsulotlarini
/// ko'rsatish uchun (`Product.companyViloyat` filtri, backend `?viloyat=`).
/// Flutter'dagi `lib/location_store.dart` bilan bir xil naqsh.
@MainActor
final class LocationStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    private static let prefKey = "selected_viloyat"

    @Published private(set) var viloyat: String?
    @Published private(set) var status: LocationStatus = .idle

    private let manager = CLLocationManager()

    var viloyatLabelText: String { viloyatLabel(viloyat) }

    override init() {
        super.init()
        manager.delegate = self
    }

    func bootstrap() {
        if let saved = UserDefaults.standard.string(forKey: Self.prefKey) {
            viloyat = saved
            status = .granted
            return
        }
        detectFromGps()
    }

    func detectFromGps() {
        status = .loading
        let authStatus = manager.authorizationStatus
        switch authStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            status = .denied
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            status = .unavailable
        }
    }

    func setViloyat(_ code: String?) {
        viloyat = code
        if let code {
            UserDefaults.standard.set(code, forKey: Self.prefKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.prefKey)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                status = .denied
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let nearest = nearestViloyat(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        Task { @MainActor in
            setViloyat(nearest.code)
            status = .granted
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in status = .unavailable }
    }
}
