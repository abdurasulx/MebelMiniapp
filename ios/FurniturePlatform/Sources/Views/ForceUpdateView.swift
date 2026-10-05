import SwiftUI

/// To'liq ekranli, yopib bo'lmaydigan majburiy yangilash ekrani.
struct ForceUpdateView: View {
    @EnvironmentObject private var versions: AppVersionStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var openFailed = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandDeep, Color.brandDeep.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.brandPrimary)
                Text(locale.t("update_title"))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(messageText)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                if let latest = versions.forcedPolicy?.latestVersion, !latest.isEmpty {
                    Text("\(locale.t("update_latest_version")): \(latest)")
                        .font(.footnote)
                        .foregroundStyle(Color.brandPrimary)
                }
                if openFailed || versions.storeUrl.isEmpty {
                    Text(locale.t("update_store_error"))
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Button {
                    openFailed = !versions.openStore()
                } label: {
                    Text(openFailed ? locale.t("update_retry") : locale.t("update_button"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brandPrimary)
                        .foregroundStyle(Color.brandDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    Task { await versions.check() }
                } label: {
                    HStack {
                        if versions.isChecking { ProgressView().tint(.white) }
                        Text(locale.t("update_recheck"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, 8)
                }
                .disabled(versions.isChecking)
            }
            .padding(24)
        }
        .interactiveDismissDisabled(true)
    }

    private var messageText: String {
        if let m = versions.forcedPolicy?.message, !m.isEmpty { return m }
        return locale.t("update_forced_message")
    }
}
