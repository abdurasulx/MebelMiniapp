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

    /// Matnlar tanlangan tilga qarab Strings.swift lug'atidan olinadi (9 til) —
    /// til menyusi o'zgarganda ekran darhol qayta chiziladi.
    private var copy: Copy { Copy(locale) }

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
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .padding(8)
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
            ForEach(appLocales, id: \.code) { l in
                Button {
                    locale.setLocale(l.code)
                } label: {
                    if locale.code == l.code {
                        Label("\(l.flag) \(l.nativeName)", systemImage: "checkmark")
                    } else {
                        Text("\(l.flag) \(l.nativeName)")
                    }
                }
            }
        } label: {
            Label(locale.code.uppercased(), systemImage: "globe")
                .font(.subheadline.weight(.semibold))
        }
        .accessibilityIdentifier("welcomeLanguageMenu")
        .accessibilityLabel(locale.t("welcome_language"))
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
    let title, subtitle, marketplace: String
    let nearbyTitle, nearbyDetail, deliveryTitle, deliveryDetail, arTitle, arDetail: String
    let privacyNote, useLocation, locating, chooseRegion, regionTitle, allRegions: String
    let regionFooter, back, locationUnavailableTitle, locationUnavailableMessage, tryAgain: String

    @MainActor
    init(_ l: LocaleStore) {
        title = l.t("welcome_title"); subtitle = l.t("welcome_subtitle"); marketplace = l.t("welcome_marketplace")
        nearbyTitle = l.t("welcome_nearby_title"); nearbyDetail = l.t("welcome_nearby_detail")
        deliveryTitle = l.t("welcome_delivery_title"); deliveryDetail = l.t("welcome_delivery_detail")
        arTitle = l.t("welcome_ar_title"); arDetail = l.t("welcome_ar_detail")
        privacyNote = l.t("welcome_privacy_note"); useLocation = l.t("welcome_use_location")
        locating = l.t("welcome_locating"); chooseRegion = l.t("welcome_choose_region")
        regionTitle = l.t("welcome_region_title"); allRegions = l.t("welcome_all_regions")
        regionFooter = l.t("welcome_region_footer"); back = l.t("welcome_back")
        locationUnavailableTitle = l.t("welcome_loc_unavailable_title")
        locationUnavailableMessage = l.t("welcome_loc_unavailable_msg")
        tryAgain = l.t("welcome_try_again")
    }
}
