import SwiftUI

/// Ilova ochilishida ko'rsatiladigan brend ekrani — avval bosh sahifada
/// bekorchi turgan hero matn shu yerga ko'chirildi (bir martalik taassurot,
/// Android'dagi `splash_screen.dart` bilan bir xil naqsh).
struct SplashScreenView: View {
    @EnvironmentObject private var locale: LocaleStore
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.brand, Color.brandPressed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(locale.t("MINIMAL VA FUNKSIONAL"))
                    .font(.caption).bold()
                    .tracking(1.5)
                    .foregroundStyle(Color.brandPrimary)

                Text(locale.t("Uyingizga\nqulaylik va hashamat"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text(locale.t("O'zbekistonning eng yaxshi mebel ustalari.\nO'lchamingizga mos dizayn, uyingizga yetkazib berish."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(28)
            .padding(.bottom, 40)
        }
    }
}
