import SwiftUI

/// Katalog/Bosh sahifa/Sevimlilarda bir xil mahsulot kartasi (Flutter `ProductCard`
/// va web kartasi bilan bir xil dizayn): oq fon, rasm cho'zilmaydi (`fit`),
/// nom 2 qatorgacha, narx ajralib turadi, chegirma bo'lsa eski narx va foiz.
struct ProductCardView: View {
    let product: Product
    var imageHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: product.cardImageUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit().padding(8)
                    case .failure:
                        placeholder
                    default:
                        Color.appBackgroundAlt.opacity(0.6)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)
                .background(Color.appBackgroundAlt)
                .clipped()

                if let qty = product.availableQuantity, qty > 0 {
                    Text("\(qty) dona")
                        .font(.caption2).bold()
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.accent)
                        .foregroundStyle(Color.onAccent)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(product.nameUz)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .topLeading)
                if let attributeSummary = product.attributeSummary {
                    Text(attributeSummary)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(Color.brandMuted)
                        .lineLimit(1)
                }
                HStack(spacing: 3) {
                    Text(product.companyName)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    if product.isVerified { VerifiedBadgeView(compact: true) }
                }
                if let pricing = product.displayPricing {
                    PriceBlockView(pricing: pricing, fromSuffix: true).padding(.top, 3)
                }
            }
            .padding(10)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            Color.appBackgroundAlt
            Image(systemName: "sofa.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.textDisabled)
        }
    }
}
