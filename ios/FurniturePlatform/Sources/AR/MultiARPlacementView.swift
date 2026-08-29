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
                subtitle: bridge.isModelReady ? "Pastdan mahsulot tanlab, tekislikka bosib joylashtiring" : nil
            ) {
                dismiss()
            }
        }
        .animation(.easeOut(duration: 0.5), value: bridge.isModelReady)
        .task { await downloadModels() }
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
/// tugma-asosli (drag-siz), oddiy va ishonchli: yo'nalish tugmalari,
/// aylantirish, kattalashtirish/kichraytirish, o'chirish.
private struct MultiARControlUnit: View {
    @ObservedObject var bridge: MultiARBridge

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                MultiARIconButton(system: "rotate.left") { bridge.rotateSelected(radians: -0.35) }
                MultiARIconButton(system: "minus.magnifyingglass") { bridge.scaleSelected(by: 0.92) }
                DPad(bridge: bridge)
                MultiARIconButton(system: "plus.magnifyingglass") { bridge.scaleSelected(by: 1.08) }
                MultiARIconButton(system: "rotate.right") { bridge.rotateSelected(radians: 0.35) }
            }
            MultiARIconButton(system: "trash", tint: .red) { bridge.removeSelected() }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial).opacity(0.6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

private struct DPad: View {
    @ObservedObject var bridge: MultiARBridge
    private let step: Float = 0.3

    var body: some View {
        VStack(spacing: 4) {
            MultiARIconButton(system: "chevron.up", small: true) { bridge.nudge(forward: step) }
            HStack(spacing: 4) {
                MultiARIconButton(system: "chevron.left", small: true) { bridge.nudge(right: -step) }
                MultiARIconButton(system: "chevron.right", small: true) { bridge.nudge(right: step) }
            }
            MultiARIconButton(system: "chevron.down", small: true) { bridge.nudge(forward: -step) }
        }
    }
}

private struct MultiARIconButton: View {
    let system: String
    var tint: Color = .white
    var small: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: small ? 12 : 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: small ? 30 : 44, height: small ? 30 : 44)
                .background(
                    RoundedRectangle(cornerRadius: small ? 9 : 14, style: .continuous)
                        .fill(tint == .red ? Color.red.opacity(0.16) : .white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: small ? 9 : 14, style: .continuous)
                        .stroke(tint == .red ? Color.red.opacity(0.45) : .white.opacity(0.15), lineWidth: 1)
                )
        }
    }
}
