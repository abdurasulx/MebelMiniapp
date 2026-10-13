import CoreLocation
import SwiftUI

/// First-launch onboarding. Location is optional: the user can always continue
/// by choosing a region instead of granting system location permission.
struct WelcomeLocationView: View {
    @EnvironmentObject private var location: LocationStore
    @EnvironmentObject private var locale: LocaleStore

    let onComplete: () -> Void

    private enum Step { case welcome, region }

    @State private var step: Step = .welcome
    @State private var isRequestingLocation = false
    @State private var showLocationError = false

    private var copy: Copy { locale.code == "en" ? .english : .uzbek }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcome
                case .region: regionList
                }
            }
            .animation(.snappy, value: step)
            .toolbar {
                if step == .welcome {
                    ToolbarItem(placement: .topBarTrailing) { languageMenu }
                }
            }
        }
        .tint(Color.brand)
        .onChange(of: location.status) { _, status in
            guard isRequestingLocation else { return }
            switch status {
            case .granted where location.hasFix:
                isRequestingLocation = false
                onComplete()
            case .denied:
                isRequestingLocation = false
                step = .region
            case .unavailable:
                isRequestingLocation = false
                showLocationError = true
            default:
                break
            }
        }
        .alert(copy.locationUnavailableTitle, isPresented: $showLocationError) {
            Button(copy.tryAgain) { requestLocation() }
            Button(copy.chooseRegion, role: .cancel) { step = .region }
        } message: {
            Text(copy.locationUnavailableMessage)
        }
    }

    private var welcome: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        brandMark

                        VStack(alignment: .leading, spacing: 10) {
                            Text(copy.title)
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color.textPrimary)
                            Text(copy.subtitle)
                                .font(.body)
                                .foregroundStyle(Color.textSecondary)
                        }

                        VStack(spacing: 0) {
                            benefit(icon: "location.fill", title: copy.nearbyTitle, detail: copy.nearbyDetail)
                            Divider().padding(.leading, 56)
                            benefit(icon: "shippingbox.fill", title: copy.deliveryTitle, detail: copy.deliveryDetail)
                            Divider().padding(.leading, 56)
                            benefit(icon: "arkit", title: copy.arTitle, detail: copy.arDetail)
                        }
                        .padding(.vertical, 4)
                        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Label(copy.privacyNote, systemImage: "hand.raised.fill")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }

                VStack(spacing: 10) {
                    Button(action: requestLocation) {
                        HStack(spacing: 8) {
                            if isRequestingLocation {
                                ProgressView().tint(Color.onBrand)
                            } else {
                                Image(systemName: "location.fill")
                            }
                            Text(isRequestingLocation ? copy.locating : copy.useLocation)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand)
                    .disabled(isRequestingLocation)

                    Button(copy.chooseRegion) { step = .region }
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(.bar)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var brandMark: some View {
        HStack {
            Image(systemName: "sofa.fill")
                .font(.title2)
                .foregroundStyle(Color.onBrand)
                .frame(width: 52, height: 52)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("VIDA Market").font(.headline)
                Text(copy.marketplace).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer()
        }
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.brand)
                .frame(width: 40, height: 40)
                .background(Color.brand.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
                Text(detail).font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var regionList: some View {
        List {
            Section {
                Button { finish(with: nil) } label: {
                    regionRow(title: copy.allRegions, icon: "globe", highlighted: true)
                }

                ForEach(viloyatlar) { region in
                    Button { finish(with: region.code) } label: {
                        regionRow(title: region.label, icon: "mappin", highlighted: false)
                    }
                }
            } footer: {
                Text(copy.regionFooter)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(copy.regionTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(copy.back) { step = .welcome }
            }
        }
    }

    private func regionRow(title: String, icon: String, highlighted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(highlighted ? Color.brand : Color.textSecondary)
                .frame(width: 24)
            Text(title).foregroundStyle(Color.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var languageMenu: some View {
        Menu {
            Button { locale.setLocale("uz") } label: {
                Label("O'zbekcha", systemImage: locale.code == "uz" ? "checkmark" : "")
            }
            Button { locale.setLocale("en") } label: {
                Label("English", systemImage: locale.code == "en" ? "checkmark" : "")
            }
        } label: {
            Text(locale.code == "en" ? "EN" : "UZ")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("Language")
    }

    private func requestLocation() {
        isRequestingLocation = true
        location.detectFromGps()
    }

    private func finish(with regionCode: String?) {
        location.setViloyat(regionCode)
        onComplete()
    }
}

private struct Copy {
    let title: String
    let subtitle: String
    let marketplace: String
    let nearbyTitle: String
    let nearbyDetail: String
    let deliveryTitle: String
    let deliveryDetail: String
    let arTitle: String
    let arDetail: String
    let privacyNote: String
    let useLocation: String
    let locating: String
    let chooseRegion: String
    let regionTitle: String
    let allRegions: String
    let regionFooter: String
    let back: String
    let locationUnavailableTitle: String
    let locationUnavailableMessage: String
    let tryAgain: String

    static let uzbek = Copy(
        title: "Uyingiz uchun to‘g‘ri tanlov",
        subtitle: "Mebel, interyer va ustalarni bir joyda toping.",
        marketplace: "Mebel va interyer bozori",
        nearbyTitle: "Yaqindagi do‘konlar", nearbyDetail: "Hududingizdagi salon va ustalarni ko‘ring.",
        deliveryTitle: "Aniq yetkazib berish", deliveryDetail: "Manzilingizga mos takliflarni oling.",
        arTitle: "Uyda sinab ko‘ring", arDetail: "Mebelni AR orqali xonangizda ko‘ring.",
        privacyNote: "Joylashuvingiz faqat yaqin takliflarni ko‘rsatish uchun ishlatiladi.",
        useLocation: "Joylashuvimdan foydalanish", locating: "Aniqlanmoqda…", chooseRegion: "Viloyatni tanlash",
        regionTitle: "Viloyatni tanlang", allRegions: "Barcha viloyatlar",
        regionFooter: "Bu tanlov keyin Profil bo‘limidan o‘zgartiriladi.", back: "Orqaga",
        locationUnavailableTitle: "Joylashuv aniqlanmadi",
        locationUnavailableMessage: "GPS signali yoki xizmatlari mavjud emas. Qayta urinib ko‘ring yoki viloyatni qo‘lda tanlang.",
        tryAgain: "Qayta urinish"
    )

    static let english = Copy(
        title: "The right choice for your home",
        subtitle: "Find furniture, interiors, and makers in one place.",
        marketplace: "Furniture & interior marketplace",
        nearbyTitle: "Nearby stores", nearbyDetail: "See salons and makers in your area.",
        deliveryTitle: "Relevant delivery", deliveryDetail: "Get options tailored to your location.",
        arTitle: "Try it at home", arDetail: "Preview furniture in your room with AR.",
        privacyNote: "Your location is only used to show relevant nearby offers.",
        useLocation: "Use my location", locating: "Locating…", chooseRegion: "Choose a region",
        regionTitle: "Choose your region", allRegions: "All regions",
        regionFooter: "You can change this later from your profile.", back: "Back",
        locationUnavailableTitle: "Location unavailable",
        locationUnavailableMessage: "GPS signal or services are unavailable. Try again or choose a region manually.",
        tryAgain: "Try again"
    )
}
