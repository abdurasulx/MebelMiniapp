import SwiftUI

/// Narx bloki: yakuniy narx, chegirma bo'lsa eski narx chizilgan va lime foiz
/// belgisi (Flutter `PriceBlock` bilan bir xil). Chegirmani klient hisoblamaydi.
struct PriceBlockView: View {
    let pricing: PricingInfo
    var fromSuffix = false
    @EnvironmentObject private var locale: LocaleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if pricing.hasDiscount {
                HStack(spacing: 6) {
                    Text("\(String(format: "%.0f", pricing.originalPrice).formattedSom) so'm")
                        .font(.caption2).strikethrough()
                        .foregroundStyle(Color.textSecondary)
                    Text("-\(Int(pricing.discountPercent.rounded()))%")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Color.accent)
                        .foregroundStyle(Color.onAccent)
                        .clipShape(Capsule())
                }
            }
            Text("\(String(format: "%.0f", pricing.finalPrice).formattedSom) so'm\(fromSuffix ? locale.t("price_from_suffix") : "")")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// "Tasdiqlangan firma" belgisi.
struct VerifiedBadgeView: View {
    var compact = false
    @EnvironmentObject private var locale: LocaleStore

    var body: some View {
        if compact {
            Image(systemName: "checkmark.seal.fill")
                .font(.footnote).foregroundStyle(Color.appSuccess)
                .accessibilityLabel(locale.t("company_verified"))
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill").font(.caption)
                Text(locale.t("company_verified")).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Color.accent)
            .foregroundStyle(Color.onAccent)
            .clipShape(Capsule())
        }
    }
}

/// Yetkazib berish kartasi (bo'lmasa "firma bilan kelishiladi").
struct DeliveryCardView: View {
    let delivery: DeliveryInfo?
    @EnvironmentObject private var locale: LocaleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(locale.t("delivery_title"), systemImage: "shippingbox")
                .font(.subheadline).fontWeight(.bold)
            if let d = delivery {
                HStack {
                    Text(locale.t("delivery_price_label")).foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(d.free ? locale.t("delivery_free") : "\(String(format: "%.0f", d.price).formattedSom) so'm")
                        .fontWeight(.semibold)
                }
                HStack {
                    Text(locale.t("delivery_time_label")).foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(d.minDays == d.maxDays
                         ? "\(d.minDays)\(locale.t("delivery_days_suffix"))"
                         : "\(d.minDays)–\(d.maxDays)\(locale.t("delivery_days_suffix"))")
                        .fontWeight(.semibold)
                }
            } else {
                Text(locale.t("delivery_agreed")).font(.footnote).foregroundStyle(Color.textSecondary)
            }
        }
        .font(.footnote)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
    }
}

/// O'lcham chizmasi: quti shaklida eni/bo'yi/chuqurligi o'lcham chiziqlari bilan,
/// haqiqiy nisbatda; pastida hajm (m³). Qiymatlar metrda.
struct DimensionBoxView: View {
    let widthM: Double
    let heightM: Double
    let depthM: Double
    @EnvironmentObject private var locale: LocaleStore

    static func cm(_ m: Double) -> String { "\(Int((m * 100).rounded())) sm" }

    static func volume(_ w: Double, _ h: Double, _ d: Double) -> String {
        let v = w * h * d
        var s = String(format: v >= 1 ? "%.2f" : "%.3f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// Faqat HAQIQIY o'lcham bo'lsa qaytaradi: avval 3D model geometriyasi, keyin
    /// variantniki; variant standart 1×1×1 (to'ldirilmagan) bo'lsa nil.
    static func resolve(model: Model3D?, variant: Variant?) -> (w: Double, h: Double, d: Double)? {
        var w = model?.bboxWidthValue, h = model?.bboxHeightValue, d = model?.bboxDepthValue
        if w == nil || h == nil || d == nil {
            guard let v = variant else { return nil }
            w = v.widthValue; h = v.heightValue; d = v.depthValue
            if w == 1 && h == 1 && d == 1 { return nil }
        }
        guard let w, let h, let d, w > 0, h > 0, d > 0 else { return nil }
        return (w, h, d)
    }

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in draw(ctx, size) }
                .frame(height: 190)
            Text("\(locale.t("dim_volume")): \(Self.volume(widthM, heightM, depthM)) m³")
                .font(.footnote).bold()
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.appBackgroundAlt)
                .clipShape(Capsule())
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let depthK = 0.5, margin = 8.0, labelRoom = 28.0
        let c = 0.7071
        let availW = size.width - margin * 2 - labelRoom
        let availH = size.height - margin * 2 - labelRoom
        let k = min(availW / (widthM + depthM * depthK * c), availH / (heightM + depthM * depthK * c))
        let fw = widthM * k, fh = heightM * k
        let dx = depthM * k * depthK * c, dy = dx
        let totalW = fw + dx, totalH = fh + dy
        let left = (size.width - totalW) / 2 - 8
        let top = (size.height - labelRoom - totalH) / 2 + dy

        let fl = CGPoint(x: left, y: top + fh), fr = CGPoint(x: left + fw, y: top + fh)
        let tl = CGPoint(x: left, y: top), tr = CGPoint(x: left + fw, y: top)
        func off(_ p: CGPoint, _ x: Double, _ y: Double) -> CGPoint { CGPoint(x: p.x + x, y: p.y + y) }
        func poly(_ pts: [CGPoint]) -> Path {
            var p = Path(); p.addLines(pts); p.closeSubpath(); return p
        }
        let front = poly([tl, tr, fr, fl])
        let topFace = poly([tl, tr, off(tr, dx, -dy), off(tl, dx, -dy)])
        let side = poly([tr, off(tr, dx, -dy), off(fr, dx, -dy), fr])

        ctx.fill(topFace, with: .color(.appBackgroundAlt))
        ctx.fill(side, with: .color(.appBorder))
        ctx.fill(front, with: .color(.appCard))
        let edge = StrokeStyle(lineWidth: 1.6, lineJoin: .round)
        for path in [front, topFace, side] { ctx.stroke(path, with: .color(.brand), style: edge) }

        func arrowLine(_ a: CGPoint, _ b: CGPoint) {
            var line = Path(); line.move(to: a); line.addLine(to: b)
            ctx.stroke(line, with: .color(.brandMuted), lineWidth: 1.2)
            let vx = b.x - a.x, vy = b.y - a.y
            let len = (vx * vx + vy * vy).squareRoot()
            guard len > 1 else { return }
            let ux = vx / len, uy = vy / len, nx = -uy, ny = ux
            for (p, s) in [(a, 1.0), (b, -1.0)] {
                var h = Path()
                h.move(to: CGPoint(x: p.x + s * ux * 7 + nx * 3.2, y: p.y + s * uy * 7 + ny * 3.2))
                h.addLine(to: p)
                h.addLine(to: CGPoint(x: p.x + s * ux * 7 - nx * 3.2, y: p.y + s * uy * 7 - ny * 3.2))
                ctx.stroke(h, with: .color(.brandMuted), lineWidth: 1.2)
            }
        }
        func label(_ s: String, at center: CGPoint, angle: Double = 0) {
            var c2 = ctx
            c2.translateBy(x: center.x, y: center.y)
            c2.rotate(by: .radians(angle))
            let text = Text(s).font(.system(size: 11.5, weight: .bold)).foregroundColor(.textPrimary)
            let r = CGRect(x: -34, y: -8, width: 68, height: 16)
            c2.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(.appBackground))
            c2.draw(text, at: .zero, anchor: .center)
        }

        let wa = off(fl, 0, 16), wb = off(fr, 0, 16)
        arrowLine(wa, wb)
        label("\(locale.t("dim_width")) \(Self.cm(widthM))", at: CGPoint(x: (wa.x + wb.x) / 2, y: wa.y + 12))
        let ha = off(tl, -16, 0), hb = off(fl, -16, 0)
        arrowLine(ha, hb)
        label("\(locale.t("dim_height")) \(Self.cm(heightM))",
              at: CGPoint(x: ha.x - 12, y: (ha.y + hb.y) / 2), angle: -.pi / 2)
        let da = off(fr, 10, 10), db = off(fr, 10 + dx, 10 - dy)
        arrowLine(da, db)
        label("\(locale.t("dim_depth")) \(Self.cm(depthM))",
              at: CGPoint(x: (da.x + db.x) / 2 + 30, y: (da.y + db.y) / 2 - 20 + 6), angle: -.pi / 4)
    }
}
