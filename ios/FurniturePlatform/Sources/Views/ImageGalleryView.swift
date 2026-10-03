import SwiftUI

/// Mahsulot rasmini to'liq ekranda ochadi (marketplace uslubidagi galereya):
/// pinch/ikki marta bosish bilan zoom, o'ngga-chapga surib almashtirish,
/// "1 / 5" hisoblagich va ixcham nuqtalar. `index` tashqaridan boshqariladi —
/// mahsulot sahifasidagi galereya shu bilan sinxron turadi.
struct ImageGalleryView: View {
    let urls: [String]
    @Binding var index: Int
    let errorText: String
    let closeLabel: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoomed = false

    private let maxDots = 7

    var body: some View {
        ZStack {
            Color.black.opacity(0.97).ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                    ZoomableImagePage(
                        url: url, errorText: errorText,
                        isCurrent: i == index,
                        onZoomChange: { z in if i == index { zoomed = z } }
                    )
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Rasm kattalashtirilganda barmoq rasmni siljitadi, sahifani emas.
            .scrollDisabled(zoomed)
            .ignoresSafeArea()
            .onChange(of: index) { _, _ in zoomed = false }

            VStack {
                HStack(alignment: .top) {
                    if urls.count > 1 {
                        pill(Text("\(index + 1) / \(urls.count)").monospacedDigit())
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel(closeLabel)
                }
                .padding(12)
                Spacer()
                if urls.count > 1 {
                    dots.padding(.bottom, 16)
                }
            }
        }
    }

    private func pill<V: View>(_ content: V) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.black.opacity(0.5), in: Capsule())
    }

    /// Ko'p rasmda nuqtalar oynasi `maxDots` bilan cheklanadi, chetlari kichrayadi.
    private var dots: some View {
        let count = urls.count
        let visible = min(count, maxDots)
        let start = min(max(index - maxDots / 2, 0), max(0, count - maxDots))
        return pill(
            HStack(spacing: 6) {
                ForEach(0..<visible, id: \.self) { k in
                    let i = start + k
                    let active = i == index
                    let edge = count > maxDots && ((k == 0 && i > 0) || (k == visible - 1 && i < count - 1))
                    Capsule()
                        .fill(active ? Color.white : Color.white.opacity(0.4))
                        .frame(width: active ? 20 : (edge ? 4 : 6), height: active ? 8 : (edge ? 4 : 6))
                }
            }
            .animation(.easeOut(duration: 0.25), value: index)
        )
    }
}

/// Bitta rasm: pinch-zoom, ikki marta bosish bilan 1x <-> 2.5x, yuklanish va xato holatlari.
private struct ZoomableImagePage: View {
    let url: String
    let errorText: String
    let isCurrent: Bool
    let onZoomChange: (Bool) -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: URL(string: url), transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(zoomGesture(size: geo.size))
                        .gesture(panGesture(size: geo.size))
                        .onTapGesture(count: 2) { toggleZoom(size: geo.size) }
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "photo").font(.system(size: 36))
                        Text(errorText).font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: geo.size.width, height: geo.size.height)
                default:
                    ProgressView().tint(.white)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .onChange(of: isCurrent) { _, current in
            if !current { reset() }
        }
    }

    private func clampedOffset(_ o: CGSize, scale s: CGFloat, size: CGSize) -> CGSize {
        let maxX = size.width * (s - 1) / 2
        let maxY = size.height * (s - 1) / 2
        return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
    }

    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(baseScale * value.magnification, 1), maxScale)
                offset = clampedOffset(offset, scale: scale, size: size)
                onZoomChange(scale > 1.01)
            }
            .onEnded { _ in
                baseScale = scale
                if scale <= 1.01 { reset() } else { baseOffset = offset }
            }
    }

    // Faqat kattalashtirilganda siljitadi (minimumDistance katta — oddiy surish sahifani almashtiradi).
    private func panGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: scale > 1.01 ? 0 : 10_000)
            .onChanged { value in
                guard scale > 1.01 else { return }
                offset = clampedOffset(
                    CGSize(width: baseOffset.width + value.translation.width,
                           height: baseOffset.height + value.translation.height),
                    scale: scale, size: size
                )
            }
            .onEnded { _ in baseOffset = offset }
    }

    private func toggleZoom(size: CGSize) {
        withAnimation(.easeOut(duration: 0.25)) {
            if scale > 1.01 {
                reset()
            } else {
                scale = 2.5
                baseScale = 2.5
                onZoomChange(true)
            }
        }
    }

    private func reset() {
        scale = 1; baseScale = 1
        offset = .zero; baseOffset = .zero
        onZoomChange(false)
    }
}
