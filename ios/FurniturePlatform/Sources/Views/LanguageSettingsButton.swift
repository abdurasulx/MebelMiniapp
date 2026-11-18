import SwiftUI
import UIKit

/// Use iOS's app language settings instead of a separate in-app language picker.
struct LanguageSettingsButton: View {
    @EnvironmentObject private var locale: LocaleStore
    @Environment(\.openURL) private var openURL

    var showsLanguageName = false

    var body: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            if showsLanguageName {
                HStack {
                    Label(locale.t("profile_language"), systemImage: "globe")
                    Spacer()
                    if let current = appLocales.first(where: { $0.code == locale.code }) {
                        Text("\(current.flag) \(current.nativeName)")
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            } else {
                Label(locale.code.uppercased(), systemImage: "globe")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityIdentifier("appLanguageSettingsButton")
        .accessibilityLabel(locale.t("profile_language"))
        .accessibilityHint(locale.t("language_settings_hint"))
    }
}
