import SwiftUI

/// Marketplace'lardagi kabi yurakcha — bosilganda serverga saqlanadi (LikesStore orqali).
struct LikeButton: View {
    let productId: String
    var compact: Bool = true
    // Berilsa, LIKE qilinganda `LikesStore.likedProducts`ga darhol
    // qo'shiladi (server so'rovisiz Sevimlilar ekranida ko'rinishi uchun,
    // qarang LikesStore.toggle).
    var product: Product? = nil
    /// Toggle tugagach chaqiriladi (masalan Sevimlilar ro'yxatidan darhol olib tashlash uchun).
    var onToggle: ((Bool) -> Void)? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @State private var busy = false
    // Avval bosilganda (tizimga kirilmagan yoki tarmoq xatosi bo'lsa)
    // tugma jimgina hech narsa qilmasdi — foydalanuvchi buni "ishlamayabdi"
    // deb qabul qildi. Endi ikkala holatda ham aniq xabar ko'rsatiladi.
    @State private var alertMessage: String?

    private var liked: Bool { likes.isLiked(productId) }

    var body: some View {
        Button {
            guard !busy else { return }
            guard auth.isAuthenticated else {
                alertMessage = "Sevimlilarga qo'shish uchun tizimga kiring"
                return
            }
            busy = true
            Task {
                let error = await likes.toggle(productId, product: product)
                busy = false
                if let error {
                    alertMessage = error
                } else {
                    onToggle?(likes.isLiked(productId))
                }
            }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .foregroundStyle(liked ? Color.red : (compact ? .white : .secondary))
                .font(compact ? .callout : .title3)
                .padding(compact ? 6 : 8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(auth.isAuthenticated ? 1 : 0.5)
        .accessibilityLabel(liked ? "Sevimlilardan olib tashlash" : "Sevimlilarga qo'shish")
        .accessibilityIdentifier("likeButton-\(productId)")
        .alert("Xatolik", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
}
