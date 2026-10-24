import ARKit
import SceneKit
import SwiftUI

struct ARMeasurementView: UIViewRepresentable {
    let onMeasurement: (FurnitureMeasurement) -> Void
    let onTrackingStatus: (String) -> Void
    let onSnapshot: (Data) -> Void
    let resetID: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(onMeasurement: onMeasurement, onTrackingStatus: onTrackingStatus, onSnapshot: onSnapshot)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = SCNScene()
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:))))
        context.coordinator.sceneView = view
        context.coordinator.startSession()
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        if context.coordinator.resetID != resetID {
            context.coordinator.reset(resetID: resetID)
        }
    }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        weak var sceneView: ARSCNView?
        var targetPoint: SIMD3<Float>?
        var meshPoints: [SIMD3<Float>] = []
        var isScanning = false
        var resetID = UUID()
        let onMeasurement: (FurnitureMeasurement) -> Void
        let onTrackingStatus: (String) -> Void
        let onSnapshot: (Data) -> Void

        init(onMeasurement: @escaping (FurnitureMeasurement) -> Void, onTrackingStatus: @escaping (String) -> Void, onSnapshot: @escaping (Data) -> Void) {
            self.onMeasurement = onMeasurement
            self.onTrackingStatus = onTrackingStatus
            self.onSnapshot = onSnapshot
        }

        func startSession() {
            guard ARWorldTrackingConfiguration.isSupported else {
                onTrackingStatus("Bu qurilma AR o‘lchashni qo‘llamaydi.")
                return
            }
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.environmentTexturing = .automatic
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                configuration.sceneReconstruction = .meshWithClassification
            }
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }
            sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            onTrackingStatus("Mebelni kamera markaziga olib keling.")
        }

        func reset(resetID: UUID) {
            self.resetID = resetID
            targetPoint = nil
            meshPoints = []
            isScanning = false
            sceneView?.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            onTrackingStatus("Yangi o‘lcham uchun birinchi nuqtaga bosing.")
        }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = sceneView else { return }
            let location = recognizer.location(in: view)
            guard let point = worldPoint(at: location, in: view) else {
                onTrackingStatus("Sirt aniqlanmadi. Kamerani sekin harakatlantirib, yana bosing.")
                return
            }

            guard !isScanning else { return }
            // Capture the selected view before adding the yellow marker. SwiftUI
            // controls are outside ARSCNView and are not included in this image.
            view.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
            let image = view.snapshot()
            let ratio = min(1, 2048 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = normalized.jpegData(compressionQuality: 0.9) else {
                onTrackingStatus("Kamera rasmini olib bo‘lmadi. Qayta urinib ko‘ring.")
                return
            }
            onSnapshot(jpeg)
            targetPoint = point
            meshPoints = []
            isScanning = true
            addMarker(at: point, color: .systemYellow, in: view)
            onTrackingStatus("Mebel tanlandi. Uni atrofidan sekin aylanib chiqing…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 7) { [weak self] in self?.finishScan() }
        }

        private func worldPoint(at location: CGPoint, in view: ARSCNView) -> SIMD3<Float>? {
            let query = view.raycastQuery(from: location, allowing: .estimatedPlane, alignment: .any)
            if let result = query.flatMap({ view.session.raycast($0).first }) {
                return SIMD3(result.worldTransform.columns.3.x, result.worldTransform.columns.3.y, result.worldTransform.columns.3.z)
            }
            return nil
        }

        private func addMarker(at point: SIMD3<Float>, color: UIColor, in view: ARSCNView) {
            let sphere = SCNSphere(radius: 0.009)
            sphere.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: sphere)
            node.simdPosition = point
            view.scene.rootNode.addChildNode(node)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard isScanning, let targetPoint, let mesh = anchor as? ARMeshAnchor else { return }
            let vertices = mesh.geometry.vertices
            let base = vertices.buffer.contents().advanced(by: vertices.offset)
            for index in stride(from: 0, to: vertices.count, by: 3) {
                let pointer = base.advanced(by: index * vertices.stride).assumingMemoryBound(to: SIMD3<Float>.self)
                let local = pointer.pointee
                let transformed = mesh.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
                let world = SIMD3<Float>(transformed.x, transformed.y, transformed.z)
                if simd_distance(world, targetPoint) < 0.95 { meshPoints.append(world) }
            }
        }

        private func finishScan() {
            guard isScanning else { return }
            isScanning = false
            guard meshPoints.count > 80 else {
                onTrackingStatus("Sirt yetarli aniqlanmadi. Mebelga yaqinroq boring va qayta bosing.")
                return
            }
            let xs = meshPoints.map(\.x), ys = meshPoints.map(\.y), zs = meshPoints.map(\.z)
            let width = Double((xs.max() ?? 0) - (xs.min() ?? 0)) * 100
            let height = Double((ys.max() ?? 0) - (ys.min() ?? 0)) * 100
            let depth = Double((zs.max() ?? 0) - (zs.min() ?? 0)) * 100
            guard width > 5, height > 5, depth > 5 else {
                onTrackingStatus("Mebelning ko‘proq tomonlarini ko‘rsatib, qayta skan qiling.")
                return
            }
            onMeasurement(FurnitureMeasurement(widthCentimeters: width, heightCentimeters: height, depthCentimeters: depth, sampledPoints: meshPoints.count))
            onTrackingStatus("Skan tayyor. Natijani tekshiring.")
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .normal: onTrackingStatus("Tayyor — birinchi nuqtaga bosing.")
            case .limited(let reason): onTrackingStatus("Kamerani sekin harakatlantiring: \(reason.description)")
            case .notAvailable: onTrackingStatus("AR kuzatuvi mavjud emas.")
            }
        }
    }
}

private extension ARCamera.TrackingState.Reason {
    var description: String {
        switch self {
        case .initializing: "tayyorlanmoqda"
        case .excessiveMotion: "harakat juda tez"
        case .insufficientFeatures: "yorug‘lik yoki sirt yetarli emas"
        case .relocalizing: "joylashuv qayta aniqlanmoqda"
        @unknown default: "kuzatuv cheklangan"
        }
    }
}
