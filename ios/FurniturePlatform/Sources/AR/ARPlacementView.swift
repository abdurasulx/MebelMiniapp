import SwiftUI

/// Mahsulotni AR orqali xonaga joylashtirish ekrani (roadmap Phase 4 — Customer AR:
/// mahsulot tanlash, xonaga joylashtirish, scale, rotation).
struct ARPlacementView: View {
    let usdzURL: URL
    let title: String
    var colorHex: String? = nil
    var textureURL: URL? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var localFileURL: URL?
    @State private var errorMessage: String?
    @State private var progress: Double = 0
    @StateObject private var bridge = ARBridge()

    var body: some View {
        ZStack(alignment: .top) {
            if let localFileURL {
                ARContainerView(modelFileURL: localFileURL, colorHex: colorHex, textureURL: textureURL, bridge: bridge)
                    .ignoresSafeArea()

                VStack {
                    Spacer()
                    if bridge.hasSelection {
                        MoveControlPad(bridge: bridge)
                            .padding(.bottom, 24)
                    } else {
                        Text("Tekislikni toping, so'ng bosib mebelni joylashtiring.\nBir vaqtda faqat bitta buyum qo'yiladi — boshqa joyga bossangiz, o'sha yerga ko'chadi.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 32)
                    }
                }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("3D modelni yuklab bo'lmadi").bold()
                    Text(errorMessage).font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 160)
                        .tint(.white)
                    Text(progress > 0 ? "3D model yuklanmoqda… \(Int(progress * 100))%" : "3D model yuklanmoqda…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
                Text(title)
                    .font(.caption).bold()
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding()
        }
        .background(Color.black)
        .task { await downloadModel() }
    }

    private func downloadModel() async {
        // Lokal dev backend (Django runserver) katta fayllarni sekin uzatadi —
        // shuning uchun progress foizini ko'rsatib, "osilib qolgandek" tuyulmasligini
        // ta'minlaymiz (prodda CDN/nginx bilan bu ancha tezroq bo'ladi).
        let downloader = ProgressDownloader { value in
            Task { @MainActor in self.progress = value }
        }
        do {
            localFileURL = try await downloader.download(from: usdzURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Tanlangan obyektni tugmalar orqali boshqarish: oldinga/orqaga/o'ngga/chapga siljitish,
/// aylantirish, va o'chirish. Yo'nalish **kompasga (dunyoga) qarab fiks** — xonada
/// qayerda tursangiz ham, tugma bosilganda obyekt doim bir xil jismoniy tomonga suriladi.
private struct MoveControlPad: View {
    @ObservedObject var bridge: ARBridge

    var body: some View {
        HStack(spacing: 20) {
            Button {
                bridge.rotateSelected(radians: -.pi / 8)
            } label: {
                Image(systemName: "rotate.left.fill").arButton()
            }

            VStack(spacing: 6) {
                Button { bridge.nudge(forward: 1) } label: {
                    Image(systemName: "chevron.up").arButton()
                }
                HStack(spacing: 6) {
                    Button { bridge.nudge(right: -1) } label: {
                        Image(systemName: "chevron.left").arButton()
                    }
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .arButton(tint: .white.opacity(0.5))
                    Button { bridge.nudge(right: 1) } label: {
                        Image(systemName: "chevron.right").arButton()
                    }
                }
                Button { bridge.nudge(forward: -1) } label: {
                    Image(systemName: "chevron.down").arButton()
                }
            }

            VStack(spacing: 10) {
                Button {
                    bridge.rotateSelected(radians: .pi / 8)
                } label: {
                    Image(systemName: "rotate.right.fill").arButton()
                }
                Button {
                    bridge.removeSelected()
                } label: {
                    Image(systemName: "trash.fill").arButton(tint: .red)
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private extension Image {
    func arButton(tint: Color = .white) -> some View {
        self
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.35), in: Circle())
    }
}
