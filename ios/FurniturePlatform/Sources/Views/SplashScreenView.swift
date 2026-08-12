import SwiftUI

/// Ilova ochilishida ko'rsatiladigan brend ekrani — avval bosh sahifada
/// bekorchi turgan hero matn shu yerga ko'chirildi (bir martalik taassurot,
/// Android'dagi `splash_screen.dart` bilan bir xil naqsh).
struct SplashScreenView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.brandDeep, Color.brandDeep.opacity(0.75), Color.brandPrimary.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("MINIMAL VA FUNKSIONAL")
                    .font(.caption).bold()
                    .tracking(1.5)
                    .foregroundStyle(Color.brandPrimary)

                Text("Uyingizga\nqulaylik va hashamat")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("O'zbekistonning eng yaxshi mebel ustalari.\nO'lchamingizga mos dizayn, uyingizga yetkazib berish.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(28)
            .padding(.bottom, 40)
        }
    }
}
