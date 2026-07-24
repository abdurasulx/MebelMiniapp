import Foundation

/// MDH davlatlari — telefon raqami kiritishdan oldin davlat tanlash uchun.
/// Flutter'dagi `lib/countries.dart` bilan bir xil.
struct CountryInfo: Identifiable, Equatable {
    let name: String
    let dialCode: String
    let flag: String
    let phoneLength: Int
    var id: String { name }

    func isValid(_ localNumber: String) -> Bool {
        localNumber.count == phoneLength && localNumber.allSatisfy(\.isNumber)
    }
}

let cisCountries: [CountryInfo] = [
    CountryInfo(name: "O'zbekiston", dialCode: "+998", flag: "🇺🇿", phoneLength: 9),
    CountryInfo(name: "Rossiya", dialCode: "+7", flag: "🇷🇺", phoneLength: 10),
    CountryInfo(name: "Qozog'iston", dialCode: "+7", flag: "🇰🇿", phoneLength: 10),
    CountryInfo(name: "Qirg'iziston", dialCode: "+996", flag: "🇰🇬", phoneLength: 9),
    CountryInfo(name: "Tojikiston", dialCode: "+992", flag: "🇹🇯", phoneLength: 9),
    CountryInfo(name: "Turkmaniston", dialCode: "+993", flag: "🇹🇲", phoneLength: 8),
    CountryInfo(name: "Ozarbayjon", dialCode: "+994", flag: "🇦🇿", phoneLength: 9),
    CountryInfo(name: "Armaniston", dialCode: "+374", flag: "🇦🇲", phoneLength: 8),
    CountryInfo(name: "Belarus", dialCode: "+375", flag: "🇧🇾", phoneLength: 9),
    CountryInfo(name: "Moldova", dialCode: "+373", flag: "🇲🇩", phoneLength: 8),
]
