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
                .background(Color.appCard)
                .clipped()

                if let qty = product.availableQuantity, qty > 0 {
                    Text("\(qty) dona")
                        .font(.caption2).bold()
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.appSuccess)
                        .foregroundStyle(.white)
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
                Text(product.companyName)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                if let first = product.variants.first {
                    priceView(first).padding(.top, 3)
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

    @ViewBuilder
    private func priceView(_ v: Variant) -> some View {
        if v.discountActive == true, let effective = v.effectiveBasePrice {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(v.basePrice.formattedSom) so'm")
                        .font(.caption2).strikethrough()
                        .foregroundStyle(Color.textSecondary)
                    if let pct = v.discountPercent, let value = Double(pct), value > 0 {
                        Text("-\(Int(value.rounded()))%")
                            .font(.caption2).bold()
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.appError)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text("\(effective.formattedSom) so'm dan")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(Color.brand)
                    .lineLimit(1)
            }
        } else {
            Text("\(v.basePrice.formattedSom) so'm dan")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(Color.brand)
                .lineLimit(1)
        }
    }
}
