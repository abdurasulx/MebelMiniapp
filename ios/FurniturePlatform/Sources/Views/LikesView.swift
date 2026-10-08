import SwiftUI

/// "Sevimlilar" — marketplace'lardagi kabi, serverda saqlangan sevimli
/// mahsulotlar ro'yxati (qaysi qurilmadan kirsa ham bir xil).
///
/// Bu ekran endi o'zining alohida ro'yxatini saqlamaydi — to'g'ridan-
/// to'g'ri `LikesStore.likedProducts`dan render qiladi. Boshqa ekranda
/// (Bosh sahifa, mahsulot sahifasi) LIKE/UNLIKE bosilganda
/// `LikesStore.toggle()` shu ro'yxatni DARHOL yangilaydi — Sevimlilar
/// tabiga kirilganda serverdan qayta so'ralmaydi (faqat BIRINCHI marta,
/// qarang `loadIfNeeded`), shuning uchun hech qanday o'zgarish bo'lmasa
/// tab qayta ochilganda "Loading..." ko'rinmaydi.
struct LikesView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var likes: LikesStore
    @EnvironmentObject private var locale: LocaleStore
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isAuthenticated {
                    ContentUnavailableCompat(
                        icon: "heart",
                        title: locale.t("likes_login_title"),
                        message: locale.t("likes_login_message")
                    )
                } else if isLoading && likes.likedProducts.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if likes.likedProducts.isEmpty {
                    ContentUnavailableCompat(
                        icon: "heart",
                        title: locale.t("likes_empty_title"),
                        message: locale.t("likes_empty_message")
                    )
                } else {
                    ScrollView {
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(Color.appError).padding()
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                            ForEach(likes.likedProducts) { product in
                                // LikeButton `NavigationLink`ning label'i ICHIDA emas, sibling
                                // sifatida joylashtiriladi — aks holda yurakchaga bosish, tugma
                                // o'z harakatini bajarish o'rniga, navigatsiyani ishga tushirib
                                // yuboradi (SwiftUI: Button ichidagi NavigationLink taplarni
                                // yutib yuboradigan holat).
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink(destination: ProductDetailView(productId: product.id)) {
                                        ShopStyleCard(product: product)
                                    }
                                    .buttonStyle(.plain)

                                    // Unlike bosilganda `likes.likedProducts`dan avtomatik
                                    // olib tashlanadi (qarang LikesStore.toggle) — bu yerda
                                    // qo'shimcha qo'lda olib tashlash shart emas.
                                    LikeButton(productId: product.id, product: product)
                                        .padding(6)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle(locale.t("likes_title"))
            .task {
                isLoading = true
                await likes.loadIfNeeded()
                isLoading = false
            }
            .refreshable {
                await likes.reload()
            }
        }
    }
}

private struct ShopStyleCard: View {
    let product: Product

    var body: some View {
        ProductCardView(product: product)
    }
}

/// iOS 17'dan oldingi ContentUnavailableView o'rniga oddiy versiya (deployment target 18, lekin shu View kichik va qayta ishlatiladi).
struct ContentUnavailableCompat: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(Color.textSecondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
