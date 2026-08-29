import SwiftUI

/// AR'ga joylashtiriladigan model — mahsulot 3D fayli (bitta) + tanlangan
/// variantning rang/naqsh ma'lumoti bilan.
struct ARModelItem: Identifiable {
    let id: String
    let title: String
    let usdzURL: URL
    let colorHex: String?
    let textureURL: URL?
}

/// Bir nechta mahsulotni AR orqali xonaga joylashtirish ekrani —
/// `ARPlacementView`dan farqli, bir vaqtda bir nechta obyekt qo'yish va
/// ularni alohida boshqarish/o'chirish imkonini beradi.
struct MultiARPlacementView: View {
    let models: [ARModelItem]

    @Environment(\.dismiss) private var dismiss
    @State private var localFileURLs: [String: URL] = [:]
    @State private var errorMessage: String?
    @State private var downloadedCount = 0
    @StateObject private var bridge = MultiARBridge()

    var body: some View {
        ZStack(alignment: .top) {
            MultiARContainerView(
                models: models.map { (id: $0.id, fileURL: localFileURLs[$0.id], colorHex: $0.colorHex, textureURL: $0.textureURL) },
                bridge: bridge
            )
            .ignoresSafeArea()

            if bridge.isModelReady {
                VStack(spacing: 0) {
                    Spacer()
                    if bridge.hasSelection {
                        MultiARControlUnit(bridge: bridge)
                            .padding(.bottom, 12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text(
                            bridge.activeModelId == nil
                                ? "Pastdan mahsulot tanlang, so'ng tekislikka bosib joylashtiring."
                                : "Tekislikka bosib joylashtiring — mavjud obyektga bossangiz, ustiga qo'yiladi."
                        )
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    ModelTray(models: models, loadedIds: Set(localFileURLs.keys), activeModelId: $bridge.activeModelId)
                        .padding(.bottom, 24)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: bridge.hasSelection)
            } else {
                MultiARLoadingOverlay(
                    progress: models.isEmpty ? 1 : Double(downloadedCount) / Double(models.count),
                    errorMessage: errorMessage
                )
                .transition(.scale(scale: 1.5).combined(with: .opacity))
            }

            ARHeaderBar(
                title: "AR — \(models.count) ta mahsulot",
                subtitle: bridge.isModelReady
                    ? (bridge.hasSelection
                        ? "Aylantirish va siljitish uchun pastki paneldan foydalaning"
                        : "Pastdan mahsulot tanlab, tekislikka bosib joylashtiring")
                    : nil
            ) {
                dismiss()
            }
        }
        .animation(.easeOut(duration: 0.5), value: bridge.isModelReady)
        .task { await downloadModels() }
        .onDisappear { ARLayoutFix.refreshWindowLayout() }
    }

    private func downloadModels() async {
        for model in models {
            let downloader = ProgressDownloader { _ in }
            do {
                let url = try await downloader.download(from: model.usdzURL)
                localFileURLs[model.id] = url
                downloadedCount += 1
                // Birinchi tayyor bo'lgan model avtomatik "faol" qilib belgilanadi —
                // foydalanuvchi tray'dan tanlamasdan ham darhol joylashtira olsin.
                if bridge.activeModelId == nil {
                    bridge.activeModelId = model.id
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Pastdagi gorizontal "tray" — har bir tanlangan mahsulotni ko'rsatadi,
/// bosilganda o'sha model keyingi joylashtirish uchun "faol" bo'ladi.
private struct ModelTray: View {
    let models: [ARModelItem]
    let loadedIds: Set<String>
    @Binding var activeModelId: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(models) { model in
                    let isLoaded = loadedIds.contains(model.id)
                    let isActive = activeModelId == model.id
                    Button {
                        guard isLoaded else { return }
                        // Faol modelga qayta bosilsa — "qurollantirilgan" holat
                        // o'chadi (endi mavjud obyektga bosish uni USTIGA
                        // qo'yish emas, oddiy TANLASH bo'ladi — qarang
                        // MultiARContainerView.handleTap).
                        activeModelId = isActive ? nil : model.id
                    } label: {
                        VStack(spacing: 4) {
                            if isLoaded {
                                Image(systemName: isActive ? "cube.fill" : "cube")
                            } else {
                                ProgressView().controlSize(.mini)
                            }
                            Text(model.title)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .frame(maxWidth: 64)
                        }
                        .foregroundStyle(isActive ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .opacity(isLoaded ? 1 : 0.6)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct MultiARLoadingOverlay: View {
    let progress: Double
    let errorMessage: String?

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).opacity(0.55).ignoresSafeArea()
            if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").font(.title2).foregroundStyle(.white)
                    Text("3D modellarni yuklab bo'lmadi").bold().foregroundStyle(.white)
                    Text(errorMessage).font(.caption).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                }
                .padding(24)
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(.white)
                    Text("3D modellar yuklanmoqda… \(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}

/// `ARHeader`ning nusxasi — `ARPlacementView.swift`dagi asl `ARHeader` shu
/// faylga xos (`private`) bo'lgani uchun bu yerda alohida.
private struct ARHeaderBar: View {
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
                Text(title).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle).font(.system(size: 10, weight: .regular)).foregroundStyle(.white.opacity(0.65))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial).opacity(0.55)
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
}

/// Tanlangan (allaqachon joylashtirilgan) obyektni boshqarish paneli —
/// `ARPlacementView.swift`dagi mijoz paneli bilan AYNAN BIR XIL: drag-asosli
/// joystik + aylanma slayder + drag bilan masshtablash (avvalgi tugma-asosli
/// D-pad'dan farqli — u yerda faqat 4 ta diskret yo'nalish tugmasi bor edi).
private struct MultiARControlUnit: View {
    @ObservedObject var bridge: MultiARBridge

    var body: some View {
        VStack(spacing: 16) {
            MultiARRotationDial(bridge: bridge)

            HStack(spacing: 18) {
                MultiARGlassIconButton(system: "arrow.up.left.and.arrow.down.right", tint: .white) {
                    // tap: standart o'lchamga tez qaytarish (fine-tuning drag orqali)
                } drag: { delta in
                    let factor = 1 + Float(-delta.height) * 0.0025
                    bridge.scaleSelected(by: factor)
                }

                MultiARPositionJoystick(bridge: bridge)

                MultiARGlassIconButton(system: "trash", tint: .red) {
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
/// buriladi. `ARPlacementView.swift::RotationDial`ning nusxasi — `MultiARBridge`
/// bilan ishlaydi.
private struct MultiARRotationDial: View {
    @ObservedObject var bridge: MultiARBridge
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
/// tomonga surilsa, ob'ekt xuddi shu yo'nalishda siljiydi. `ARPlacementView.swift
/// ::PositionJoystick`ning nusxasi — `MultiARBridge` bilan ishlaydi.
private struct MultiARPositionJoystick: View {
    @ObservedObject var bridge: MultiARBridge
    @GestureState private var dragOffset: CGSize = .zero

    private let baseSize: CGFloat = 76
    private let knobSize: CGFloat = 34
    private let maxOffset: CGFloat = 21
    private let innerRadius: CGFloat = 11

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

            Circle()
                .stroke(.white.opacity(inOuterZone ? 0.4 : 0.2), lineWidth: 1)
                .frame(width: innerRadius * 2, height: innerRadius * 2)

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
                    // `state == .zero` — surilishning birinchi hodisasi, aynan shu
                    // daqiqada yo'nalish "qulflanadi" (qarang beginMoveGesture izohi).
                    if state == .zero { bridge.beginMoveGesture() }
                    let clamped = Self.clamp(value.translation, radius: maxOffset)
                    state = clamped
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
/// sudrash (`drag`, masalan Scale uchun) orqali ishlaydi. `ARPlacementView.swift
/// ::GlassIconButton`ning nusxasi.
private struct MultiARGlassIconButton: View {
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
