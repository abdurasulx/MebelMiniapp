import Foundation

/// O'zbekiston viloyatlari — backend `Viloyat` enum bilan bir xil kodlar
/// (`backend/apps/companies/models.py`). GPS koordinatasidan eng yaqin
/// viloyat markazini topish uchun taxminiy markaz koordinatalari beriladi
/// (aniq chegara emas, shunchaki eng yaqin markazni tanlash uslubi —
/// tashqi geocoding xizmati/API kaliti kerak emas). Flutter'dagi
/// `lib/viloyat.dart` bilan bir xil.
struct ViloyatInfo: Identifiable {
    let code: String
    let label: String
    let lat: Double
    let lng: Double
    var id: String { code }
}

let viloyatlar: [ViloyatInfo] = [
    ViloyatInfo(code: "toshkent_shahri", label: "Toshkent shahri", lat: 41.2995, lng: 69.2401),
    ViloyatInfo(code: "toshkent_viloyati", label: "Toshkent viloyati", lat: 41.0, lng: 69.5),
    ViloyatInfo(code: "andijon", label: "Andijon", lat: 40.7821, lng: 72.3442),
    ViloyatInfo(code: "buxoro", label: "Buxoro", lat: 39.7747, lng: 64.4286),
    ViloyatInfo(code: "fargona", label: "Farg'ona", lat: 40.3894, lng: 71.7864),
    ViloyatInfo(code: "jizzax", label: "Jizzax", lat: 40.1158, lng: 67.8422),
    ViloyatInfo(code: "xorazm", label: "Xorazm", lat: 41.3775, lng: 60.3639),
    ViloyatInfo(code: "namangan", label: "Namangan", lat: 40.9983, lng: 71.6726),
    ViloyatInfo(code: "navoiy", label: "Navoiy", lat: 40.1030, lng: 65.3686),
    ViloyatInfo(code: "qashqadaryo", label: "Qashqadaryo", lat: 38.8606, lng: 65.7891),
    ViloyatInfo(code: "qoraqalpogiston", label: "Qoraqalpog'iston Respublikasi", lat: 42.4531, lng: 59.6103),
    ViloyatInfo(code: "samarqand", label: "Samarqand", lat: 39.6270, lng: 66.9750),
    ViloyatInfo(code: "sirdaryo", label: "Sirdaryo", lat: 40.5030, lng: 68.7842),
    ViloyatInfo(code: "surxondaryo", label: "Surxondaryo", lat: 37.9401, lng: 67.5714),
]

func viloyatLabel(_ code: String?) -> String {
    guard let code else { return "Barchasi" }
    return viloyatlar.first { $0.code == code }?.label ?? "Noma'lum"
}

/// Berilgan lat/lng ga eng yaqin viloyatni topadi (Haversine masofasi).
func nearestViloyat(lat: Double, lng: Double) -> ViloyatInfo {
    func distanceKm(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
    return viloyatlar.min { distanceKm(lat, lng, $0.lat, $0.lng) < distanceKm(lat, lng, $1.lat, $1.lng) }
        ?? viloyatlar[0]
}
