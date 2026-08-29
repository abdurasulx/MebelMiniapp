import ARKit
import Combine
import RealityKit
import SwiftUI

/// Bir vaqtda bir nechta obyekt joylashtirilgan AR sessiyasi bilan SwiftUI
/// o'rtasidagi ko'prik — `ARBridge`dan farqli, tanlangan obyekt istalgan
/// vaqtda o'zgarishi mumkin (yangisi joylashtirilganda yoki mavjudi
/// bosilganda), shuning uchun tanlanganlik holati shu yerda kuzatiladi.
final class MultiARBridge: ObservableObject {
    @Published var hasSelection = false
    @Published var isModelReady = false
    /// Barcha modellar (shablonlar) yuklab bo'linganini bildiradi — tepadagi
    /// bilan farqi: bu YUKLASH progressini, u esa "hech bo'lmasa bittasi
    /// tayyor, ekranni ko'rsatish mumkin" holatini bildiradi.
    @Published var loadedCount = 0
    weak var controller: MultiARPlacementViewController?

    /// Keyingi bosishda QAYSI model joylashtirilishi kerakligini belgilaydi —
    /// `nil` bo'lsa, bo'sh joyga bosish hech narsa qilmaydi (faqat mavjud
    /// obyektni tanlash/bekor qilish ishlaydi). `@Published` — aks holda
    /// tray'dagi "faol" belgisi va pastdagi yo'riqnoma matni SwiftUI'da
    /// yangilanib turmas edi (bog'lash `$bridge.activeModelId` orqali ham
    /// ishlaydi, lekin `objectWillChange` yubormasa qayta chizilmaydi).
    @Published var activeModelId: String? {
        didSet { controller?.activeModelId = activeModelId }
    }

    func nudge(right: Float = 0, forward: Float = 0) {
        controller?.moveSelected(right: right, forward: forward)
    }

    /// Joystik surilishi BOSHLANGANDA chaqiriladi — qarang
    /// `MultiARPlacementViewController.beginMoveGesture`.
    func beginMoveGesture() {
        controller?.beginMoveGesture()
    }

    /// Joystik qo'yib yuborilganda chaqiriladi.
    func endMoveGesture() {
        controller?.endMoveGesture()
    }

    func rotateSelected(radians: Float) {
        controller?.rotateSelected(radians: radians)
    }

    func removeSelected() {
        controller?.removeSelected()
    }

    func scaleSelected(by factor: Float) {
        controller?.scaleSelected(by: factor)
    }
}

/// RealityKit ARView'ni SwiftUI'ga bog'laydi — `ARContainerView`dan farqli,
/// bir nechta model faylini (`models`) qabul qiladi va ularning barchasini
/// bir necha marta, istalgan sonda sahnaga joylashtirish imkonini beradi.
struct MultiARContainerView: UIViewControllerRepresentable {
    /// Har bir model uchun (id, lokal fayl yo'li — hali yuklanmagan bo'lsa
    /// `nil`, rang, naqsh).
    let models: [(id: String, fileURL: URL?, colorHex: String?, textureURL: URL?)]
    @ObservedObject var bridge: MultiARBridge

    func makeUIViewController(context: Context) -> MultiARPlacementViewController {
        let controller = MultiARPlacementViewController()
        controller.onSelectionChange = { [weak bridge] selected in
            bridge?.hasSelection = selected
        }
        controller.onModelLoaded = { [weak bridge] in
            bridge?.loadedCount += 1
            if bridge?.loadedCount == 1 {
                withAnimation { bridge?.isModelReady = true }
            }
        }
        bridge.controller = controller
        controller.activeModelId = bridge.activeModelId
        for model in models where model.fileURL != nil {
            controller.registerModel(
                id: model.id, fileURL: model.fileURL!, colorHex: model.colorHex, textureURL: model.textureURL
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MultiARPlacementViewController, context: Context) {
        for model in models where model.fileURL != nil {
            uiViewController.registerModel(
                id: model.id, fileURL: model.fileURL!, colorHex: model.colorHex, textureURL: model.textureURL
            )
        }
        uiViewController.activeModelId = bridge.activeModelId
    }
}

/// Xonaga BIR NECHTA mebel joylashtirish:
/// — pastdagi "tray"da tanlangan model "faol" bo'lib belgilanadi;
/// — faol model bor holda bo'sh tekislikka bosilsa, YANGI nusxa joylashtiriladi
///   (mavjudlarga tegilmaydi — bir xil modeldan bir nechta nusxa qo'yish mumkin);
/// — mavjud (allaqachon joylashtirilgan) obyektga bosilsa, o'sha TANLANADI
///   (keyin joystik/aylantirish/o'lchash/o'chirish shunga qo'llanadi);
/// — bo'sh joyga bosilganda faol model bo'lmasa, faqat tanlov bekor qilinadi.
final class MultiARPlacementViewController: UIViewController, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    private var arView: ARView!
    private var coachingOverlay: ARCoachingOverlayView!

    private var templates: [String: ModelEntity] = [:]
    private var loadingIds: Set<String> = []
    /// Sahnaga joylashtirilgan barcha nusxalar — qaysi model shablonidan
    /// yaratilgani bilan birga (o'chirish/audit uchun shart emas, lekin
    /// kelajakda foydali bo'lishi mumkin).
    private var placedEntities: [ModelEntity] = []
    private var selectedEntity: ModelEntity? {
        didSet { onSelectionChange?(selectedEntity != nil) }
    }

    var activeModelId: String?
    var onSelectionChange: ((Bool) -> Void)?
    /// Har bir model shabloni to'liq yuklab olinib, RealityKit'ga tayyor
    /// bo'lganda (har biri uchun alohida) chaqiriladi.
    var onModelLoaded: (() -> Void)?

    private static let moveStep: Float = 0.24

    override func viewDidLoad() {
        super.viewDidLoad()

        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.session.delegate = self
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        arView.session.run(config)

        coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.delegate = self
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.frame = arView.bounds
        arView.addSubview(coachingOverlay)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        arView?.frame = view.bounds
        coachingOverlay?.frame = view.bounds
    }

    /// Bitta modelni "kutubxona"ga qo'shadi — bir necha marta chaqirilishi
    /// xavfsiz (allaqachon yuklangan/yuklanayotgan bo'lsa e'tiborsiz qoladi).
    func registerModel(id: String, fileURL: URL, colorHex: String?, textureURL: URL?) {
        guard templates[id] == nil, !loadingIds.contains(id) else { return }
        loadingIds.insert(id)
        Task {
            do {
                let entity = try await ModelEntity(contentsOf: fileURL)
                entity.generateCollisionShapes(recursive: true)
                await Self.applyVariantMaterial(colorHex: colorHex, textureURL: textureURL, to: entity)
                await MainActor.run {
                    self.templates[id] = entity
                    self.loadingIds.remove(id)
                    self.onModelLoaded?()
                }
            } catch {
                print("USDZ yuklanmadi (\(id)): \(error)")
                await MainActor.run { self.loadingIds.remove(id) }
            }
        }
    }

    private static func applyVariantMaterial(colorHex: String?, textureURL: URL?, to entity: Entity) async {
        var texture: TextureResource?
        if let textureURL {
            texture = try? await downloadTexture(from: textureURL)
        }
        let tint = colorHex.flatMap { UIColor(hex: $0) }
        guard texture != nil || tint != nil else { return }
        applyMaterial(texture: texture, tint: tint, to: entity)
    }

    private static func downloadTexture(from url: URL) async throws -> TextureResource {
        let (localURL, _) = try await URLSession.shared.download(from: url)
        let cachedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension.isEmpty ? "png" : url.pathExtension)
        try? FileManager.default.removeItem(at: cachedURL)
        try FileManager.default.moveItem(at: localURL, to: cachedURL)
        return try await TextureResource(contentsOf: cachedURL)
    }

    private static func applyMaterial(texture: TextureResource?, tint: UIColor?, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                if var pbr = material as? PhysicallyBasedMaterial {
                    if let texture {
                        pbr.baseColor = .init(texture: .init(texture))
                    } else if let tint {
                        pbr.baseColor.tint = tint
                    }
                    return pbr
                }
                if var simple = material as? SimpleMaterial {
                    if let tint {
                        simple.color = .init(tint: tint, texture: simple.color.texture)
                    }
                    return simple
                }
                return material
            }
            entity.components.set(model)
        }
        for child in entity.children {
            applyMaterial(texture: texture, tint: tint, to: child)
        }
    }

    // MARK: - Joylashtirish / tanlash (bosish)

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: arView)

        // Avval mavjud (allaqachon joylashtirilgan) obyektlardan biriga
        // tegilganmi tekshiramiz.
        if let hitEntity = arView.entity(at: point),
           let hitAncestor = Self.findPlacedAncestor(of: hitEntity, in: placedEntities) {
            if let activeModelId, let template = templates[activeModelId] {
                // Faol model bor holda mavjud obyektga bosilsa — yangi nusxa
                // pastdagi tekislikka emas, aynan SHU OBYEKT USTIGA
                // joylashtiriladi (bir detalni ikkinchisi ustiga qo'yish).
                stackEntity(from: template, onTopOf: hitAncestor)
                return
            }
            // Faol model yo'q — oddiy tanlash (keyin joystik/aylantirish/
            // o'chirish shunga qo'llanadi).
            selectedEntity = hitAncestor
            return
        }

        guard let activeModelId, let template = templates[activeModelId] else {
            // Faol model tanlanmagan — bo'sh joyga bosish faqat tanlovni bekor qiladi.
            selectedEntity = nil
            return
        }

        let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = results.first else { return }
        placeEntity(from: template, at: result.worldTransform)
    }

    /// Berilgan dunyoviy o'rinda (odatda pol/tekislik nuqtasi) yangi nusxa
    /// yaratadi — pastki chegarasi aynan shu Y balandligiga to'g'irlanadi
    /// (USDZ/GLB pivot nuqtasi har xil bo'lishi mumkinligi uchun).
    @discardableResult
    private func placeEntity(from template: ModelEntity, at worldTransform: simd_float4x4) -> ModelEntity {
        let anchor = AnchorEntity(world: worldTransform)
        let entity = template.clone(recursive: true)
        entity.generateCollisionShapes(recursive: true)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        let worldBounds = entity.visualBounds(relativeTo: nil)
        let targetFloorY = worldTransform.columns.3.y
        let correction = targetFloorY - worldBounds.min.y
        entity.position.y += correction

        placedEntities.append(entity)
        selectedEntity = entity
        return entity
    }

    /// Yangi nusxani `target`ning aynan USTIGA (tepa chegarasiga, markazga
    /// tekislab) joylashtiradi — `target`ning gorizontal burilishini meros
    /// qilib oladi, lekin o'lchamini (scale) EMAS, aks holda `target`
    /// kattalashtirilgan bo'lsa yangi nusxa ham ikki marta kattalashib qolardi.
    private func stackEntity(from template: ModelEntity, onTopOf target: ModelEntity) {
        let targetBounds = target.visualBounds(relativeTo: nil)
        let transform = Transform(
            scale: .one,
            rotation: target.orientation(relativeTo: nil),
            translation: [targetBounds.center.x, targetBounds.max.y, targetBounds.center.z]
        )
        placeEntity(from: template, at: transform.matrix)
    }

    /// `entity(at:)` odatda modelning ICHKI (mesh) qismini qaytaradi, aynan
    /// biz `placedEntities`ga qo'shgan tashqi `ModelEntity`ni emas — shuning
    /// uchun ota-bobolar zanjiri bo'ylab yuqoriga ko'tarilib, ro'yxatimizdagi
    /// mos yozuvni topamiz.
    private static func findPlacedAncestor(of entity: Entity, in placed: [ModelEntity]) -> ModelEntity? {
        var current: Entity? = entity
        while let node = current {
            if let match = placed.first(where: { $0 === node }) {
                return match
            }
            current = node.parent
        }
        return nil
    }

    /// Joriy kamera yo'nalishidan ekran-nisbiy o'q juftligini hisoblaydi.
    /// `moveSelected` buni har chaqiriqda emas, faqat surilish BOSHIDA bir
    /// marta ishlatadi (qarang `cachedMovementAxes`) — aks holda foydalanuvchi
    /// joystikni ushlab turgan holda picha burilib qolsa (yoki qurilma
    /// titrasa), yo'nalish surilish ORTASIDA o'zgarib, obyekt kutilmagan
    /// "aylanib" ketayotgandek harakatlanardi.
    ///
    /// MUHIM: avvalgi yondashuvlar (xom kamera-ustunlar, keyin `UIDevice.current.
    /// orientation`ga asoslangan `viewMatrix(for:)`) sinovda tasdiqlanmadi —
    /// orientatsiya haqida taxmin qilishga asoslangan edi. Shuning uchun
    /// RealityKit'ning O'ZIDAN so'raymiz: `arView.ray(through:)` berilgan ekran
    /// nuqtasidan o'tuvchi haqiqiy dunyo-fazoviy nurni qaytaradi — ARView HOZIR
    /// qanday render qilayotgan bo'lsa ham (portret, jismoniy landscape — farqi
    /// yo'q) shunga mos. Ekran markazidan o'ngga siljigan nuqta orqali o'tuvchi
    /// nur bilan markaziy nur (= kamera qarab turgan tomon, `forward`) farqidan
    /// HAQIQIY screen-right yo'nalishini olamiz.
    private func currentMovementAxes() -> (right: SIMD3<Float>, forward: SIMD3<Float>) {
        let bounds = arView.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let rightPoint = CGPoint(x: bounds.midX + 60, y: bounds.midY)

        if let centerRay = arView.ray(through: center),
           let rightRay = arView.ray(through: rightPoint) {
            var right = SIMD3<Float>(
                rightRay.direction.x - centerRay.direction.x, 0,
                rightRay.direction.z - centerRay.direction.z
            )
            var forward = SIMD3<Float>(centerRay.direction.x, 0, centerRay.direction.z)
            if simd_length(right) > 0.0001 { right = simd_normalize(right) } else { right = [1, 0, 0] }
            if simd_length(forward) > 0.0001 { forward = simd_normalize(forward) } else { forward = [0, 0, -1] }
            return (right, forward)
        }

        // Zaxira: nurlar olinmasa (masalan sessiya hali frame bermagan bo'lsa),
        // eski xom kamera-ustun usuli.
        let cam = arView.cameraTransform.matrix
        var right = SIMD3<Float>(cam.columns.0.x, 0, cam.columns.0.z)
        var forward = SIMD3<Float>(-cam.columns.2.x, 0, -cam.columns.2.z)
        if simd_length(right) > 0.0001 { right = simd_normalize(right) } else { right = [1, 0, 0] }
        if simd_length(forward) > 0.0001 { forward = simd_normalize(forward) } else { forward = [0, 0, -1] }
        return (right, forward)
    }

    private var cachedMovementAxes: (right: SIMD3<Float>, forward: SIMD3<Float>)?

    // MARK: - SwiftUI tugmalari orqali boshqarish (tanlangan obyektga qo'llanadi)

    func beginMoveGesture() {
        cachedMovementAxes = currentMovementAxes()
    }

    func endMoveGesture() {
        cachedMovementAxes = nil
    }

    func moveSelected(right: Float, forward: Float) {
        guard let entity = selectedEntity else { return }
        let axes = cachedMovementAxes ?? currentMovementAxes()
        let delta = (axes.right * right + axes.forward * forward) * Self.moveStep
        let currentWorldPosition = entity.position(relativeTo: nil)
        entity.setPosition(currentWorldPosition + delta, relativeTo: nil)
    }

    func rotateSelected(radians: Float) {
        guard let entity = selectedEntity else { return }
        let delta = simd_quatf(angle: radians, axis: [0, 1, 0])
        let currentWorldOrientation = entity.orientation(relativeTo: nil)
        entity.setOrientation(delta * currentWorldOrientation, relativeTo: nil)
    }

    func removeSelected() {
        guard let entity = selectedEntity, let anchor = entity.anchor else { return }
        arView.scene.removeAnchor(anchor)
        placedEntities.removeAll { $0 === entity }
        selectedEntity = nil
    }

    func scaleSelected(by factor: Float) {
        guard let entity = selectedEntity else { return }
        let newScale = simd_clamp(entity.transform.scale * factor, [0.3, 0.3, 0.3], [3, 3, 3])
        entity.transform.scale = newScale
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {}
}
