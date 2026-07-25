import ARKit
import Combine
import RealityKit
import SwiftUI

/// SwiftUI tugmalari (o'ng/chap/oldinga/orqaga) bilan AR kontroller o'rtasidagi ko'prik.
final class ARBridge: ObservableObject {
    @Published var hasSelection = false
    /// Kamera darhol ishga tushadi, lekin 3D model fon rejimida yuklanadi —
    /// shu bayroq model butunlay tayyor (yuklab olingan + RealityKit shabloni
    /// tuzilgan) bo'lganda `true` bo'ladi, shundan keyingina yuklash overlay'i
    /// yashiriladi.
    @Published var isModelReady = false
    weak var controller: ARPlacementViewController?

    func nudge(right: Float = 0, forward: Float = 0) {
        controller?.moveSelected(right: right, forward: forward)
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

/// RealityKit ARView'ni SwiftUI'ga bog'laydi. Tepadagi ARPlacementView undan foydalanadi.
///
/// `modelFileURL` ATAYIN ixtiyoriy — kamera (ARKit sessiyasi) `modelFileURL`
/// hali `nil` bo'lsa ham darhol ishga tushadi (`makeUIViewController`da fayl
/// kutilmaydi); 3D model background'da yuklab olinib, tayyor bo'lgach
/// `updateUIViewController` uni controllerga topshiradi.
struct ARContainerView: UIViewControllerRepresentable {
    var modelFileURL: URL?
    /// Tanlangan variantning rang/naqsh tint'i — bitta geometriyaga (Product.model3d)
    /// runtime'da qo'llanadi, xuddi web'dagi `ModelViewer`ning material API'si kabi.
    let colorHex: String?
    let textureURL: URL?
    /// Mahsulot sahifasida kiritilgan o'lchamning variant standart o'lchamiga
    /// nisbati — joylashtirilganda modelga shu nisbatda qo'llaniladi.
    var scaleFactors: SIMD3<Float> = [1, 1, 1]
    @ObservedObject var bridge: ARBridge

    func makeUIViewController(context: Context) -> ARPlacementViewController {
        let controller = ARPlacementViewController(colorHex: colorHex, textureURL: textureURL, scaleFactors: scaleFactors)
        controller.onSelectionChange = { [weak bridge] selected in
            bridge?.hasSelection = selected
        }
        controller.onModelReady = { [weak bridge] in
            withAnimation { bridge?.isModelReady = true }
        }
        bridge.controller = controller
        if let modelFileURL {
            controller.setModelFileURL(modelFileURL)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ARPlacementViewController, context: Context) {
        if let modelFileURL {
            uiViewController.setModelFileURL(modelFileURL)
        }
    }
}

/// Xonaga mebel joylashtirish — **MVP: faqat bitta obyekt**:
/// — hali hech narsa qo'yilmagan bo'lsa, bosilgan joyga (tekislikka) joylashtiriladi;
/// — obyekt allaqachon qo'yilgan bo'lsa, keyingi bosishlar uni **yangi joyga ko'chiradi**
///   (yangi nusxa yaratilmaydi);
/// — barmoq bilan surish/aylantirish/kattalashtirish RealityKit'ning tayyor
///   gesture tizimi orqali ham ishlayveradi, qo'shimcha SwiftUI tugmalari bilan ham.
final class ARPlacementViewController: UIViewController, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    private var modelFileURL: URL?
    private let colorHex: String?
    private let textureURL: URL?
    private let scaleFactors: SIMD3<Float>
    private var arView: ARView!
    private var coachingOverlay: ARCoachingOverlayView!
    private var modelTemplate: ModelEntity?
    private var isLoadingTemplate = false
    private var placed: ModelEntity? {
        didSet { onSelectionChange?(placed != nil) }
    }

    // Obyekt qo'yilgan paytda foydalanuvchi qayerga qarab turgani "qulflab" qo'yiladi —
    // shundan keyin tugmalar ANA SHU fiks yo'nalishlarga qarab suradi, joriy kamera
    // holatiga bog'liq bo'lmaydi. Bu ARKit kompas konvensiyasini "taxmin qilish"dan
    // ko'ra ishonchli: foydalanuvchi xonada aylanib boshqa tomondan tursa ham,
    // "oldinga" tugmasi doim bir xil jismoniy tomonni anglatadi.
    private var lockedRightAxis: SIMD3<Float> = [1, 0, 0]
    private var lockedForwardAxis: SIMD3<Float> = [0, 0, -1]

    var onSelectionChange: ((Bool) -> Void)?
    /// 3D model to'liq yuklab olinib, RealityKit shabloni tuzilganda chaqiriladi
    /// (kamera esa bundan mustaqil, ekran ochilishi bilanoq ishlab turadi).
    var onModelReady: (() -> Void)?

    private static let moveStep: Float = 0.08 // metr — tugma bosilganda siljish qadami

    init(colorHex: String?, textureURL: URL?, scaleFactors: SIMD3<Float> = [1, 1, 1]) {
        self.colorHex = colorHex
        self.textureURL = textureURL
        self.scaleFactors = scaleFactors
        super.init(nibName: nil, bundle: nil)
    }

    /// SwiftUI'dan model fayli tayyor bo'lgach (`ARContainerView.updateUIViewController`)
    /// chaqiriladi — kamera bundan oldin allaqachon ishga tushgan bo'ladi.
    func setModelFileURL(_ url: URL) {
        guard modelFileURL == nil, !isLoadingTemplate else { return }
        modelFileURL = url
        isLoadingTemplate = true
        Task { await loadTemplate() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) yo'q") }

    override func viewDidLoad() {
        super.viewDidLoad()

        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.session.delegate = self
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        // Occlusion: real narsalar (stol, devor, gilam oldidagi buyumlar) virtual mebelni
        // to'sib turishi kerak — aks holda obyekt hamma narsaning "tepasida" chizilib,
        // xonaga tabiiy joylashmagandek ko'rinadi. LiDAR'li qurilmalarda (iPhone Pro)
        // mesh-asoslangan to'liq occlusion, boshqalarida esa odam segmentatsiyasi
        // (kamida odamlar to'sib tursa) ishlatiladi.
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

        if modelFileURL != nil, !isLoadingTemplate {
            isLoadingTemplate = true
            Task { await loadTemplate() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // SwiftUI'dan UIViewControllerRepresentable orqali kelgan Auto Layout o'lchamlari
        // autoresizingMask'ni har doim ham to'g'ri ishga tushirmaydi — shuning uchun har
        // layout jarayonida ARView butun ekranni to'liq egallashini qo'lda ta'minlaymiz
        // (aks holda ekranning faqat bir qismida g'alati/kichik tasvir chiqib qoladi).
        arView?.frame = view.bounds
        coachingOverlay?.frame = view.bounds
    }

    private func loadTemplate() async {
        guard let modelFileURL else { return }
        do {
            let entity = try await ModelEntity(contentsOf: modelFileURL)
            entity.generateCollisionShapes(recursive: true)
            await applyVariantMaterial(to: entity)
            self.modelTemplate = entity
            onModelReady?()
        } catch {
            print("USDZ yuklanmadi: \(error)")
        }
    }

    /// Tanlangan variantning rangi/naqshini bitta model geometriyasiga qo'llaydi —
    /// har rang uchun alohida USDZ yuklash o'rniga, xuddi shu yondashuv web'da
    /// `ModelViewer`da (`pbrMetallicRoughness.setBaseColorFactor/Texture`) ishlatiladi.
    private func applyVariantMaterial(to entity: Entity) async {
        var texture: TextureResource?
        if let textureURL {
            texture = try? await Self.downloadTexture(from: textureURL)
        }
        let tint = colorHex.flatMap { UIColor(hex: $0) }
        guard texture != nil || tint != nil else { return }
        Self.applyMaterial(texture: texture, tint: tint, to: entity)
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

    // MARK: - Joylashtirish / ko'chirish (bosish)

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: arView)
        let results = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = results.first else { return }

        if let existing = placed, let anchor = existing.anchor {
            // Obyekt allaqachon qo'yilgan — yangisini yaratmasdan, shu obyektni ko'chiramiz.
            anchor.move(to: result.worldTransform, relativeTo: nil)
            return
        }

        guard let template = modelTemplate else { return }
        lockMovementAxes()

        let anchor = AnchorEntity(world: result.worldTransform)
        let entity = template.clone(recursive: true)
        entity.transform.scale = scaleFactors
        entity.generateCollisionShapes(recursive: true)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)

        // USDZ/GLB modelning ichki nol nuqtasi (pivot) har doim ham obyektning
        // eng past (oyoq) qismida bo'lavermaydi — ko'p professional modellash
        // dasturlari pivotni obyekt markaziga qo'yadi, ba'zilari esa boshqa
        // o'lchov/o'q konvensiyasida eksport qilingan bo'ladi. Buni oldindan
        // taxmin qilish (masalan faqat local-space chegarani o'lchab) turli
        // fayllarda turlicha xato berdi — ba'zisida bir necha santimetr farq,
        // ba'zisida butunlay havoda "muallaq" qolish. Shuning uchun endi
        // TAXMIN qilinmaydi: obyekt sahnaga qo'shilgach uning HAQIQIY
        // dunyoviy (world-space) pastki nuqtasi o'lchanadi va aynan shu farq
        // bo'yicha tuzatiladi — qanday fayl, qanday pivot yoki o'lchov
        // konvensiyasi bo'lishidan qat'iy nazar, natija har doim bir xil
        // ishonchli bo'ladi.
        let worldBounds = entity.visualBounds(relativeTo: nil)
        let targetFloorY = result.worldTransform.columns.3.y
        let correction = targetFloorY - worldBounds.min.y
        entity.position.y += correction

        // Eslatma: RealityKit'ning tayyor `installGestures` imo-ishoralari ATAYIN
        // ulanmaydi — pastki SwiftUI panelidagi joystik/aylantirish diski bilan bir
        // xil teginishlarni "talashib", ikkalasi bir vaqtda ishga tushib ketardi
        // (natijada joystik ishlamay qolgan, aylantirish esa noto'g'ri o'qda
        // ko'rinar edi). Boshqaruv endi faqat SwiftUI panel orqali amalga oshadi.

        placed = entity
    }

    /// Joylashtirish paytidagi kamera yo'nalishini "qulflaydi" — tugmalar shundan keyin
    /// shu fiks yo'nalishga qarab ishlaydi (foydalanuvchi keyin qayerga qarab tursa ham).
    private func lockMovementAxes() {
        let cam = arView.cameraTransform.matrix
        var right = SIMD3<Float>(cam.columns.0.x, 0, cam.columns.0.z)
        var forward = SIMD3<Float>(-cam.columns.2.x, 0, -cam.columns.2.z)
        if simd_length(right) > 0.0001 { right = simd_normalize(right) } else { right = [1, 0, 0] }
        if simd_length(forward) > 0.0001 { forward = simd_normalize(forward) } else { forward = [0, 0, -1] }
        lockedRightAxis = right
        lockedForwardAxis = forward
    }

    // MARK: - SwiftUI tugmalari orqali boshqarish

    func moveSelected(right: Float, forward: Float) {
        guard let entity = placed else { return }
        let delta = (lockedRightAxis * right + lockedForwardAxis * forward) * Self.moveStep
        let currentWorldPosition = entity.position(relativeTo: nil)
        entity.setPosition(currentWorldPosition + delta, relativeTo: nil)
    }

    func rotateSelected(radians: Float) {
        guard let entity = placed else { return }
        // `entity.transform.rotation *=` ob'ektning O'ZINING lokal o'qi bo'yicha
        // qo'shadi — agar modelning ichki yo'nalishi picha og'ma bo'lsa (USDZ
        // eksport konvensiyasi), bu tepaga/pastga egilib ketayotgandek ko'rinadi.
        // Shuning uchun dunyoning haqiqiy vertikal o'qi (world Y, gravitatsiyaga
        // qarshi) bo'yicha, world-space'da qo'shamiz — bu har doim sof
        // "chapga-o'ngga" aylanishni kafolatlaydi, model qanday eksport
        // qilinganidan qat'iy nazar.
        let delta = simd_quatf(angle: radians, axis: [0, 1, 0])
        let currentWorldOrientation = entity.orientation(relativeTo: nil)
        entity.setOrientation(delta * currentWorldOrientation, relativeTo: nil)
    }

    func removeSelected() {
        guard let entity = placed, let anchor = entity.anchor else { return }
        arView.scene.removeAnchor(anchor)
        placed = nil
    }

    func scaleSelected(by factor: Float) {
        guard let entity = placed else { return }
        let newScale = simd_clamp(entity.transform.scale * factor, [0.3, 0.3, 0.3], [3, 3, 3])
        entity.transform.scale = newScale
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {}
}
