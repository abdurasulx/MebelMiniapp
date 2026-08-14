import SwiftUI

private let socialIcons: [String: String] = [
    "Instagram": "at",
    "Telegram": "paperplane.fill",
    "Facebook": "link",
    "Veb-sayt": "globe",
]

/// Firma profilidagi ijtimoiy tarmoq/veb-sayt havolalari — bosilganda
/// tizim brauzerida ochiladi (qarang `Company.socialLinks`).
struct SocialLinksRow: View {
    let links: [(label: String, url: URL)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(links, id: \.url) { item in
                Link(destination: item.url) {
                    Image(systemName: socialIcons[item.label] ?? "link")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.brandDeep)
                        .frame(width: 30, height: 30)
                        .background(Color.brandDeep.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }
}
