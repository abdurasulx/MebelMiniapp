import SwiftUI

/// Marketplace'lardagi kabi yurakcha — bosilganda serverga saqlanadi (LikesStore orqali).
struct LikeButton: View {
    let productId: String
    var compact: Bool = true
    /// Toggle tugagach chaqiriladi (masalan Sevimlilar ro'yxatidan darhol olib tashlash uchun).
    var onToggle: ((Bool) -> Void)? = nil

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @State private var busy = false

    private var liked: Bool { likes.isLiked(productId) }

    var body: some View {
        Button {
            guard auth.isAuthenticated, !busy else { return }
            busy = true
            Task {
                await likes.toggle(productId)
                busy = false
                onToggle?(likes.isLiked(productId))
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
    }
}
