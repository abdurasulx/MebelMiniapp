import simd
import SwiftUI
import UIKit

/// AR ekrani `.fullScreenCover` sifatida yopilgach, ba'zan pastdagi `TabView`
/// xato/eskirgan safe-area/tab-bar o'lchamlarini saqlab qolib, USTA'ning
/// BARCHA tablarida bo'sh joy (gap) paydo bo'lib qolishi kuzatildi — bu
/// SwiftUI'ning `fullScreenCover` + kamera (`ignoresSafeArea`) kombinatsiyasi
/// bilan bog'liq tanilgan nuqson. Yopilgandan so'ng oyna (window)
/// ierarxiyasini qo'lda "qayta joylashtirishga" majburlash bu holatni
/// tuzatadi.
enum ARLayoutFix {
    static func refreshWindowLayout() {
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.rootViewController?.view.setNeedsLayout()
                    window.rootViewController?.view.layoutIfNeeded()
                }
            }
        }
    }
}

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
            // Kamera (ARKit sessiyasi) ekran ochilishi bilanoq ishga tushadi —
            // model fayli hali yuklanmagan bo'lsa ham `localFileURL` `nil` holda
            // uzatiladi, qora ekran yoki statik splash bo'lmaydi.
            ARContainerView(
                modelFileURL: localFileURL, colorHex: colorHex, textureURL: textureURL,
                scaleFactors: scaleFactors, bridge: bridge
            )
            .ignoresSafeArea()

            if bridge.isModelReady {
                VStack {
                    Spacer()
                    if bridge.hasSelection {
                        ARBottomControlUnit(bridge: bridge)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("Tekislikni toping, so'ng bosib mebelni joylashtiring.\nBir vaqtda faqat bitta buyum qo'yiladi — boshqa joyga bossangiz, o'sha yerga ko'chadi.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: bridge.hasSelection)
            } else {
                ARLoadingOverlay(progress: progress, errorMessage: errorMessage)
                    .transition(.scale(scale: 1.5).combined(with: .opacity))
            }

            ARHeader(title: title, subtitle: bridge.hasSelection ? "Aylantirish va siljitish uchun pastki paneldan foydalaning" : nil) {
                dismiss()
            }
        }
        .animation(.easeOut(duration: 0.5), value: bridge.isModelReady)
        .task { await downloadModel() }
        .onDisappear { ARLayoutFix.refreshWindowLayout() }
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

// MARK: - Yuklanish overlay'i

/// Kamera tasviri ustidan mayin "muzlagan shisha" (frosted glass) parda +
/// markazda ikki qavatli neon-nurli dumaloq loader + aylanib turuvchi qisqa
/// matn. Model tayyor bo'lgach (`bridge.isModelReady`) `ARPlacementView`
/// buni `.opacity` bilan silliq yo'qotadi (fade-out).
private struct ARLoadingOverlay: View {
    let progress: Double
    let errorMessage: String?

    private static let phrases = [
        "Kamera muhiti tayyorlanmoqda…",
        "AR fazosi shakllanmoqda…",
        "3D model yuklanmoqda…",
    ]

    @State private var phraseIndex = 0
    private let timer = Timer.publish(every: 1.8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.55)
                .ignoresSafeArea()

            if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("3D modelni yuklab bo'lmadi").bold().foregroundStyle(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            } else {
                VStack(spacing: 14) {
                    OrbitingLoader()
                    VStack(spacing: 4) {
                        Text(Self.phrases[phraseIndex])
                            .id(phraseIndex)
                            .transition(.opacity)
                        if progress > 0, progress < 1 {
                            Text("\(Int(progress * 100))%")
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                phraseIndex = (phraseIndex + 1) % Self.phrases.count
            }
        }
    }
}

/// Ikki qavatli dumaloq loader: orqada ingichka shaffof statik halqa, uning
/// ustida bilyard to'pining silliq harakatini eslatuvchi, orbitada aylanib
/// nurlanib turuvchi gradient nuqta (qisqa "quyruq" iziy bilan).
private struct OrbitingLoader: View {
    @State private var rotation: Double = 0

    private let size: CGFloat = 64
    private let dotSize: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 2)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: 0.22)
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(red: 0.55, green: 0.85, blue: 1.0)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.65, green: 0.9, blue: 1.0), .white.opacity(0)],
                        center: .center, startRadius: 0, endRadius: dotSize
                    )
                )
                .frame(width: dotSize, height: dotSize)
                .offset(x: size / 2)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
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
                    // `state == .zero` — bu SURILISHNING BIRINCHI hodisasi (aks
                    // holda @GestureState har doim oldingi qiymatdan davom etadi) —
                    // aynan shu daqiqada yo'nalish "qulflanadi" (qarang
                    // beginMoveGesture izohi), qolgan davomida o'zgarmaydi.
                    if state == .zero { bridge.beginMoveGesture() }
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
                .onEnded { _ in
                    bridge.endMoveGesture()
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
