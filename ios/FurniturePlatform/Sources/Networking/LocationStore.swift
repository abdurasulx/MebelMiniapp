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
    private static let latKey = "gps_lat"
    private static let lngKey = "gps_lng"

    @Published private(set) var viloyat: String?
    // Aniq GPS koordinatasi — mavjud bo'lsa, firma xizmat radiusi bo'yicha
    // filtrlashda viloyat o'rniga shu ishlatiladi (qarang backend
    // apps/products/views.py `lat`/`lng` parametri, backend/common/geo.py).
    @Published private(set) var lat: Double?
    @Published private(set) var lng: Double?
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
            if UserDefaults.standard.object(forKey: Self.latKey) != nil {
                lat = UserDefaults.standard.double(forKey: Self.latKey)
                lng = UserDefaults.standard.double(forKey: Self.lngKey)
            }
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

    func setViloyat(_ code: String?, lat: Double? = nil, lng: Double? = nil) {
        viloyat = code
        // Qo'lda boshqa viloyat tanlansa, avvalgi GPS koordinatasi endi
        // noto'g'ri bo'lib qoladi — shuning uchun faqat GPS orqali kelgan
        // chaqiruvdagina (lat/lng berilganda) saqlanadi, aks holda tozalanadi.
        self.lat = lat
        self.lng = lng
        if let code {
            UserDefaults.standard.set(code, forKey: Self.prefKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.prefKey)
        }
        if let lat, let lng {
            UserDefaults.standard.set(lat, forKey: Self.latKey)
            UserDefaults.standard.set(lng, forKey: Self.lngKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.latKey)
            UserDefaults.standard.removeObject(forKey: Self.lngKey)
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
            setViloyat(nearest.code, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
            status = .granted
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in status = .unavailable }
    }
}
