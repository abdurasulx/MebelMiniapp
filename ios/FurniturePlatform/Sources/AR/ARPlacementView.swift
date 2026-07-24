import simd
import SwiftUI

/// Mahsulotni AR orqali xonaga joylashtirish ekrani (roadmap Phase 4 — Customer AR:
/// mahsulot tanlash, xonaga joylashtirish, scale, rotation).
///
/// Boshqaruv paneli "frosted glass" (glassmorphism) uslubida: kamera ko'rinishi
/// panellar ortidan aniq ko'rinib tursin deb yuqori shaffoflik ishlatiladi.
struct ARPlacementView: View {
    let usdzURL: URL
    let title: String
    var colorHex: String? = nil
    var textureURL: URL? = nil
    /// Mahsulot sahifasida kiritilgan eni/bo'yi/chuqurligining variant standart
    /// o'lchamiga nisbati — AR'da modelni shu nisbatda masshtablaydi, shunda
    /// AR'da ko'rilgan buyum sahifadagi narxga mos o'lchamda ko'rinadi.
    var scaleFactors: SIMD3<Float> = [1, 1, 1]

    @Environment(\.dismiss) private var dismiss
    @State private var localFileURL: URL?
    @State private var errorMessage: String?
    @State private var progress: Double = 0
    @StateObject private var bridge = ARBridge()

    var body: some View {
        ZStack(alignment: .top) {
            if let localFileURL {
                ARContainerView(
                    modelFileURL: localFileURL, colorHex: colorHex, textureURL: textureURL,
                    scaleFactors: scaleFactors, bridge: bridge
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    if bridge.hasSelection {
                        ARBottomControlUnit(bridge: bridge)
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

            ARHeader(title: title, subtitle: bridge.hasSelection ? "Aylantirish va siljitish uchun pastki paneldan foydalaning" : nil) {
                dismiss()
            }
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

// MARK: - Yuqori panel

/// Nafis, shaffof yuqori panel: chapda yopish tugmasi, markazda ob'ekt nomi va
/// qisqa yo'riqnoma.
private struct ARHeader: View {
    let title: String
    let subtitle: String?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Color.clear.frame(width: 30, height: 30)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.55)
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
}

// MARK: - Pastki boshqaruv bloki

/// Yagona shaffof konteyner: rotatsiya slayderi (yuqorida) + joystik/scale/delete
/// (pastda, bitta qatorda).
private struct ARBottomControlUnit: View {
    @ObservedObject var bridge: ARBridge

    var body: some View {
        VStack(spacing: 16) {
            RotationDial(bridge: bridge)

            HStack(spacing: 18) {
                GlassIconButton(system: "arrow.up.left.and.arrow.down.right", tint: .white) {
                    // tap: standart o'lchamga tez qaytarish (fine-tuning drag orqali)
                } drag: { delta in
                    let factor = 1 + Float(-delta.height) * 0.0025
                    bridge.scaleSelected(by: factor)
                }

                PositionJoystick(bridge: bridge)

                GlassIconButton(system: "trash", tint: .red) {
                    bridge.removeSelected()
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 28)
    }
}

/// Bilyard kuch o'lchagichi / aylanma g'ildirakka o'xshash gorizontal slayder —
/// barmoq o'ngga-chapga yurgizilganda ob'ekt X o'qi (dunyo Y) atrofida silliq
/// buriladi. Chekka nuqtaga yopishib qolmaydi — cheksiz aylantirish uchun
/// har gesture tugaganda boshlanish nuqtasi markazga qaytariladi.
private struct RotationDial: View {
    @ObservedObject var bridge: ARBridge
    @State private var dragStartX: CGFloat?
    @State private var lastX: CGFloat = 0

    private let width: CGFloat = 220
    private let height: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: width - 56) {
                Image(systemName: "arrow.counterclockwise")
                Image(systemName: "arrow.clockwise")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))

            // tick belgilar — barmoq surilganda "aylanayotgandek" taassurot beradi
            HStack(spacing: 10) {
                ForEach(0..<9, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i == 4 ? 0.9 : 0.3))
                        .frame(width: i == 4 ? 3 : 2, height: i == 4 ? 18 : 10)
                }
            }
        }
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dragStartX == nil {
                        dragStartX = value.startLocation.x
                        lastX = value.startLocation.x
                    }
                    let deltaX = value.location.x - lastX
                    lastX = value.location.x
                    // piksel → radian: butun disk kengligi bo'ylab surish ~ to'liq aylanish
                    let radians = Float(deltaX / width) * .pi * 1.6
                    bridge.rotateSelected(radians: radians)
                }
                .onEnded { _ in
                    dragStartX = nil
                }
        )
    }
}

/// Markaziy shaffof joystik (D-pad/thumbstick) — barmoq markazdan qaysi
/// tomonga surilsa, ob'ekt xuddi shu (fazoda qulflangan) yo'nalishda siljiydi.
/// Ikki zonaga bo'lingan: ichki zona (markazga yaqin) — nozik, 1x tezlik;
/// tashqi zona (chekkaga yaqin) — tez, 2x tezlik. Qo'yib yuborilganda
/// tayoqcha markazga qaytadi.
private struct PositionJoystick: View {
    @ObservedObject var bridge: ARBridge
    @GestureState private var dragOffset: CGSize = .zero

    private let baseSize: CGFloat = 76
    private let knobSize: CGFloat = 34
    private let maxOffset: CGFloat = 21
    private let innerRadius: CGFloat = 11 // ichki (1x) va tashqi (2x) zona chegarasi

    private var distance: CGFloat {
        sqrt(dragOffset.width * dragOffset.width + dragOffset.height * dragOffset.height)
    }
    private var inOuterZone: Bool { distance > innerRadius }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: baseSize, height: baseSize)
                .overlay(
                    Circle().stroke(.white.opacity(0.15), lineWidth: 1)
                )

            // Ichki (1x) / tashqi (2x) zona chegarasi
            Circle()
                .stroke(.white.opacity(inOuterZone ? 0.4 : 0.2), lineWidth: 1)
                .frame(width: innerRadius * 2, height: innerRadius * 2)

            // yo'nalish o'qlari — tashqi zonada yorqinroq (tezlashgani bildiradi)
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(dragOffset == .zero ? 0.25 : (inOuterZone ? 0.8 : 0.5)))
                    .offset(y: -baseSize / 2 + 6)
                    .rotationEffect(.degrees(angle))
            }

            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: knobSize, height: knobSize)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                .offset(dragOffset)
        }
        .frame(width: baseSize, height: baseSize)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($dragOffset) { value, state, _ in
                    let clamped = Self.clamp(value.translation, radius: maxOffset)
                    state = clamped
                    // Tayoqcha markazdan qanchalik uzoqlashgan bo'lsa, har bir
                    // harakat hodisasida shunchalik ko'proq siljiydi — barmoq
                    // qimirlab turgan ekan, tabiiy uzluksiz surilish hissi beradi.
                    // Ichki zonada 1x (nozik boshqarish), tashqi zonada 2x (tez siljish).
                    let dist = sqrt(clamped.width * clamped.width + clamped.height * clamped.height)
                    let speed: Float = dist > innerRadius ? 2.0 : 1.0
                    let right = Float(clamped.width / maxOffset)
                    let forward = Float(-clamped.height / maxOffset)
                    bridge.nudge(right: right * 0.01 * speed, forward: forward * 0.01 * speed)
                }
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: dragOffset)
    }

    private static func clamp(_ translation: CGSize, radius: CGFloat) -> CGSize {
        let length = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard length > radius else { return translation }
        let scaleFactor = radius / length
        return CGSize(width: translation.width * scaleFactor, height: translation.height * scaleFactor)
    }
}

/// Shisha effektli kvadrat piktogramma tugma — bosish (`onTap`) yoki tepaga/pastga
/// sudrash (`drag`, masalan Scale uchun) orqali ishlaydi.
private struct GlassIconButton: View {
    let system: String
    var tint: Color = .white
    var onTap: (() -> Void)? = nil
    var drag: ((CGSize) -> Void)? = nil

    var body: some View {
        Image(systemName: system)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint == .red ? Color.red.opacity(0.16) : .white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint == .red ? Color.red.opacity(0.45) : .white.opacity(0.15), lineWidth: 1)
            )
            .onTapGesture { onTap?() }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in drag?(value.translation) }
            )
    }
}
