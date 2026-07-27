import SceneKit
import SwiftUI
import simd

// MARK: - Snap angle enum (used by QuickDoseSheet controls)

enum BodySnapAngle: CGFloat, CaseIterable, Equatable {
    case front = 0
    case right = 90
    case back  = 180
    case left  = 270

    var label: String {
        switch self {
        case .front: return "Front"
        case .back:  return "Back"
        case .left:  return "Left"
        case .right: return "Right"
        }
    }
}

// MARK: - View

struct BodyModel3DView: UIViewRepresentable {

    typealias HeatMapData = [String: Int]
    typealias HitPosition = (label: String, worldX: Double, worldY: Double, worldZ: Double, normalX: Double, normalY: Double, normalZ: Double)

    let heatMapData: HeatMapData
    let avoidZones: Set<String>
    let preferredZones: Set<String>
    let recommendedZones: Set<String>
    let selectedSites: Binding<[String]>
    let maxSelections: Int
    var bodyType: BodyType = .neutral
    var snapAngle: BodySnapAngle = .front
    var snapNonce: Int = 0
    var onTapZone: ((String, Bool) -> Void)? = nil
    var tapPositions: Binding<[String: HitPosition]>
    var onPreTap: (([String], [String: HitPosition]) -> Void)? = nil
    /// Called with the tap location in view coordinates when the user hits the body on
    /// surface that has no clinical zone, so the host can mark the spot.
    var onNoZoneTap: ((CGPoint) -> Void)? = nil
    /// Reports the live camera yaw in radians whenever it changes.
    ///
    /// Hosts need this because the user can free-pan with a drag, which leaves the snap-angle
    /// selection untouched. Deriving the recorded view context from the snap label meant
    /// panning round to the back and tapping stored `viewContext: "front"`.
    var onYawChange: ((Float) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(heatMapData: heatMapData,
                    avoidZones: avoidZones,
                    preferredZones: preferredZones,
                    recommendedZones: recommendedZones,
                    selectedSites: selectedSites,
                    maxSelections: maxSelections,
                    onTapZone: onTapZone,
                    tapPositions: tapPositions,
                    onPreTap: onPreTap,
                    onNoZoneTap: onNoZoneTap,
                    onYawChange: onYawChange)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isJitteringEnabled = true

        let scene = SCNScene()
        scnView.scene = scene

        let cameraNode = makeCamera(in: scene)
        scnView.pointOfView = cameraNode
        setupLighting(in: scene)

        // The engine must exist before the model loads: `loadBodyModel` hands it the baked
        // zone map, and assigning through a nil engine would silently leave taps unresolvable.
        context.coordinator.hitTestEngine = ZoneHitTestEngine()

        loadBodyModel(into: scene, bodyType: bodyType, cameraNode: cameraNode, scnView: scnView, context: context)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        context.coordinator.scnView        = scnView
        context.coordinator.scene          = scene
        context.coordinator.cameraNode     = cameraNode
        context.coordinator.centroidStore  = ZoneCentroidStore.shared
        context.coordinator.renderHeatMap()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            context.coordinator.renderHeatMap()
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.heatMapData        = heatMapData
        c.avoidZones         = avoidZones
        c.preferredZones     = preferredZones
        c.recommendedZones   = recommendedZones
        c.maxSelections      = maxSelections
        c.tapPositions   = tapPositions
        c.onNoZoneTap    = onNoZoneTap
        c.onYawChange    = onYawChange
        c.renderHeatMap()
        c.heatMapRenderer?.updateCamera(c.cameraNode)
        c.syncPersistentSpots()

        if snapNonce != c.lastSnapNonce {
            c.lastSnapNonce = snapNonce
            c.animateCamera(to: snapAngle)
        }
    }

    // MARK: - Scene setup

    @discardableResult
    private func makeCamera(in scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        node.name   = "mainCamera"
        node.camera = SCNCamera()
        node.camera?.fieldOfView = 42
        node.camera?.zNear = 0.01
        node.camera?.zFar  = 100
        node.position = Coordinator.cameraPosition(yaw: 0)
        node.look(at: Coordinator.lookAt)
        scene.rootNode.addChildNode(node)
        return node
    }

    private func setupLighting(in scene: SCNScene) {
        scene.lightingEnvironment.contents  = UIColor(white: 0.92, alpha: 1.0)
        scene.lightingEnvironment.intensity = 1.8

        func addLight(type: SCNLight.LightType,
                      color: UIColor,
                      intensity: CGFloat,
                      position: SCNVector3,
                      shadow: Bool = false) {
            let node  = SCNNode()
            node.light = SCNLight()
            node.light?.type      = type
            node.light?.color     = color
            node.light?.intensity = intensity
            if shadow {
                node.light?.castsShadow   = true
                node.light?.shadowMode    = .deferred
                node.light?.shadowRadius  = 4
                node.light?.shadowColor   = UIColor(white: 0, alpha: 0.15)
            }
            node.position = position
            node.look(at: SCNVector3(0, 0.75, 0))
            scene.rootNode.addChildNode(node)
        }

        addLight(type: .directional,
                 color: UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0),
                 intensity: 820,
                 position: SCNVector3(1.5, 2.5, 2.0),
                 shadow: true)

        addLight(type: .directional,
                 color: UIColor(red: 0.82, green: 0.88, blue: 1.00, alpha: 1.0),
                 intensity: 380,
                 position: SCNVector3(-1.5, 1.8, 1.0))

        addLight(type: .directional,
                 color: UIColor(white: 0.72, alpha: 1.0),
                 intensity: 500,
                 position: SCNVector3(0, 1.5, -2.5))

        addLight(type: .directional,
                 color: UIColor(red: 0.90, green: 0.86, blue: 0.82, alpha: 1.0),
                 intensity: 340,
                 position: SCNVector3(-1.2, 1.5, -2.0))
    }

    private func loadBodyModel(into scene: SCNScene,
                                bodyType: BodyType,
                                cameraNode: SCNNode,
                                scnView: SCNView,
                                context: Context) {
        let name = bodyType.usdzName
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz",
                                          subdirectory: "Models")
            ?? Bundle.main.url(forResource: name, withExtension: "usdz")
            ?? Bundle.main.url(forResource: "body_neutral", withExtension: "usdz",
                                subdirectory: "Models")
            ?? Bundle.main.url(forResource: "body_neutral", withExtension: "usdz") else {
            print("[BodyModel3DView] \u{26A0}\u{FE0F} \(name).usdz not found")
            return
        }

        do {
            let modelScene = try SCNScene(url: url, options: [
                .checkConsistency: true,
                .flattenScene: false
            ])

            let wrapper = SCNNode()
            wrapper.name = name
            for child in modelScene.rootNode.childNodes {
                wrapper.addChildNode(child)
            }
            scene.rootNode.addChildNode(wrapper)
            context.coordinator.bodyWrapperNode = wrapper

            // Detect the asset's stored orientation instead of assuming it, so a corrected
            // regeneration of the mesh cannot silently flip the body.
            var wrapperSpace: [SIMD3<Float>] = []
            wrapper.enumerateChildNodes { node, _ in
                guard let src = node.geometry?.sources(for: .vertex).first else { return }
                let M = simd_float4x4(node.worldTransform)
                let stride = src.dataStride, offset = src.dataOffset, data = src.data
                data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                    for i in 0..<src.vectorCount {
                        let b = offset + i * stride
                        guard b + 12 <= data.count else { continue }
                        let local = SIMD4<Float>(ptr.loadUnaligned(fromByteOffset: b, as: Float.self),
                                                 ptr.loadUnaligned(fromByteOffset: b + 4, as: Float.self),
                                                 ptr.loadUnaligned(fromByteOffset: b + 8, as: Float.self), 1)
                        let r = M * local
                        wrapperSpace.append(SIMD3<Float>(r.x, r.y, r.z))
                    }
                }
            }
            let orientation = BodyOrientation(wrapperSpaceVertices: wrapperSpace) ?? .shippedAssets

            let (minB, maxB) = wrapper.boundingBox
            guard let bodyTransform = BodyTransform(boundingBox: (min: minB, max: maxB),
                                                    orientation: orientation) else {
                print("[BodyModel3DView] \u{26A0}\u{FE0F} Degenerate bounding box")
                return
            }
            bodyTransform.apply(to: wrapper)
            context.coordinator.bodyTransform = bodyTransform

            // Load the baked zone map for *this* body type. The old code loaded centroids
            // once, in an initializer, always for `.neutral` — so feminine and masculine
            // meshes were hit-tested against neutral geometry, off by up to 8 cm.
            var meshNode: SCNNode?
            var mostVertices = 0
            wrapper.enumerateChildNodes { node, _ in
                guard let count = node.geometry?.sources(for: .vertex).first?.vectorCount else { return }
                if count > mostVertices { mostVertices = count; meshNode = node }
            }
            if let meshNode {
                do {
                    let map = try ZoneMap(bodyType: bodyType, meshNode: meshNode)
                    context.coordinator.zoneMap = map
                    context.coordinator.hitTestEngine?.zoneMap = map
                    ZoneCentroidStore.shared.zoneMap = map
                } catch {
                    // Taps will report `.noZone` rather than guessing a label. Mislabelling an
                    // injection site is worse than declining to name one.
                    print("[BodyModel3DView] \u{26A0}\u{FE0F} zone map unavailable for \(bodyType.rawValue): \(error)")
                }
            } else {
                print("[BodyModel3DView] \u{26A0}\u{FE0F} No mesh geometry found for zone map")
            }

            let skin = skinMaterial()
            wrapper.enumerateChildNodes { node, _ in
                guard let geo = node.geometry else { return }
                geo.materials = [skin]
            }

            context.coordinator.skinMaterial = skin

            guard let device = scnView.device else {
                print("[BodyModel3DView] \u{26A0}\u{FE0F} No Metal device")
                return
            }
            context.coordinator.heatMapRenderer = HeatMap3DRenderer(
                material: skin,
                bodyType: bodyType,
                centroidStore: ZoneCentroidStore.shared
            )
            context.coordinator.heatMapRenderer?.attachShader(to: device)
            context.coordinator.heatMapRenderer?.updateCamera(cameraNode)

            print("[BodyModel3DView] Loaded \(name): s=\(bodyTransform.scale) proper=\(bodyTransform.isProper)")
        } catch {
            print("[BodyModel3DView] \u{26A0}\u{FE0F} Load failed: \(error)")
        }
    }

    private func skinMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel     = .physicallyBased
        m.diffuse.contents  = UIColor.accentSecondaryAdaptive
        m.roughness.contents = Float(0.62)
        m.metalness.contents = Float(0.0)
        // BodyTransform is a proper rotation, so triangle winding is preserved and
        // back-face culling works. The old mirrored transform inverted winding, which
        // is the only reason this had to be true.
        m.isDoubleSided     = false
        return m
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        static let orbitRadius: Float = 2.5
        static let orbitHeight: Float = 0.75
        static let lookAt = SCNVector3(0, 0.75, 0)

        static func cameraPosition(yaw: Float) -> SCNVector3 {
            SCNVector3(orbitRadius * sin(yaw),
                       orbitHeight,
                       orbitRadius * cos(yaw))
        }

        var yaw: Float = 0
        var lastSnapNonce: Int = 0
        private var cameraAnimLink: CADisplayLink?

        var heatMapData: HeatMapData
        var avoidZones: Set<String>
        var preferredZones: Set<String>
        var recommendedZones: Set<String>
        var selectedSites: Binding<[String]>
        var maxSelections: Int
        var onTapZone: ((String, Bool) -> Void)?
        var tapPositions: Binding<[String: HitPosition]>
        var onPreTap: (([String], [String: HitPosition]) -> Void)?
        var onNoZoneTap: ((CGPoint) -> Void)?
        var onYawChange: ((Float) -> Void)?

        weak var scnView: SCNView?
        weak var scene: SCNScene?
        weak var cameraNode: SCNNode?
        weak var bodyWrapperNode: SCNNode?
        weak var skinMaterial: SCNMaterial?
        var hitTestEngine: ZoneHitTestEngine?
        var heatMapRenderer: HeatMap3DRenderer?
        var centroidStore: ZoneCentroidStore?
        var bodyTransform: BodyTransform?
        /// Strong owner of the baked map. `ZoneCentroidStore` holds it weakly, so something
        /// has to keep it alive for the lifetime of the view.
        var zoneMap: ZoneMap?

        private var lastRenderSites: Set<String> = []
        private var lastRenderHeat: HeatMapData = [:]
        private var lastRenderAvoid: Set<String> = []
        private var lastRenderPreferred: Set<String> = []
        private var lastRenderRecommended: Set<String> = []
        private var lastPersistentCount: Int = -1
        private var lastPersistentSpots: [SCNVector3] = []

        init(heatMapData: HeatMapData,
             avoidZones: Set<String>,
             preferredZones: Set<String>,
             recommendedZones: Set<String>,
             selectedSites: Binding<[String]>,
             maxSelections: Int,
             onTapZone: ((String, Bool) -> Void)?,
             tapPositions: Binding<[String: HitPosition]>,
             onPreTap: (([String], [String: HitPosition]) -> Void)?,
             onNoZoneTap: ((CGPoint) -> Void)?,
             onYawChange: ((Float) -> Void)?) {
            self.heatMapData      = heatMapData
            self.avoidZones       = avoidZones
            self.preferredZones   = preferredZones
            self.recommendedZones = recommendedZones
            self.selectedSites    = selectedSites
            self.maxSelections    = maxSelections
            self.onTapZone        = onTapZone
            self.tapPositions     = tapPositions
            self.onPreTap         = onPreTap
        }

        // MARK: Gestures

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = scnView else { return }
            if gesture.state == .began {
                cameraAnimLink?.invalidate()
                cameraAnimLink = nil
            }
            let delta = gesture.translation(in: view)
            yaw += Float(delta.x) * 0.005
            applyCameraPosition(animated: false)
            gesture.setTranslation(.zero, in: view)
        }

        func animateCamera(to angle: BodySnapAngle) {
            cameraAnimLink?.invalidate()
            let target = Float(angle.rawValue) * (.pi / 180)
            let twoPi = Float.pi * 2
            var diff = target - yaw.truncatingRemainder(dividingBy: twoPi)
            if diff >  Float.pi { diff -= twoPi }
            if diff < -Float.pi { diff += twoPi }
            let startYaw = yaw
            let endYaw   = startYaw + diff
            let startTime = CACurrentMediaTime()
            let duration  = 0.42

            let link = CADisplayLink(target: self, selector: #selector(tickCameraAnim))
            link.add(to: .main, forMode: .common)
            cameraAnimLink = link
            cameraAnimStartYaw = startYaw
            cameraAnimEndYaw = endYaw
            cameraAnimStartTime = startTime
            cameraAnimDuration = duration
        }

        private var cameraAnimStartYaw: Float = 0
        private var cameraAnimEndYaw: Float = 0
        private var cameraAnimStartTime: CFTimeInterval = 0
        private var cameraAnimDuration: CFTimeInterval = 0

        @objc private func tickCameraAnim() {
            let elapsed = CACurrentMediaTime() - cameraAnimStartTime
            let t = Float(min(elapsed / cameraAnimDuration, 1.0))
            let et = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            yaw = cameraAnimStartYaw + (cameraAnimEndYaw - cameraAnimStartYaw) * et
            applyCameraPosition(animated: false)
            if elapsed >= cameraAnimDuration {
                cameraAnimLink?.invalidate()
                cameraAnimLink = nil
            }
        }

        private func applyCameraPosition(animated: Bool) {
            guard let cam = cameraNode else { return }
            cam.position = Self.cameraPosition(yaw: yaw)
            cam.look(at: Self.lookAt)
            heatMapRenderer?.updateCamera(cameraNode)
            onYawChange?(yaw)
        }

        // MARK: Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView, let engine = hitTestEngine else { return }
            let pt = gesture.location(in: view)
            switch engine.outcome(at: pt, in: view) {
            case .zone(let result):
                handleZoneHit(result)
            case .noZone:
                onNoZoneTap?(pt)
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.4)
            case .miss:
                break
            }
        }

        private func handleZoneHit(_ hit: ZoneHitResult) {
            if avoidZones.contains(hit.label) { return }

            onPreTap?(selectedSites.wrappedValue, tapPositions.wrappedValue)

            var sites = selectedSites.wrappedValue

            let wasSelection: Bool
            var removedLabel: String?

            if let idx = sites.firstIndex(of: hit.label) {
                removedLabel = sites[idx]
                sites.remove(at: idx)
                wasSelection = false
            } else if maxSelections <= 1 {
                let old = Set(sites)
                sites = [hit.label]
                wasSelection = true
                for oldLabel in old.subtracting([hit.label]) {
                    tapPositions.wrappedValue.removeValue(forKey: oldLabel)
                }
            } else if sites.count < maxSelections {
                sites.append(hit.label)
                wasSelection = true
            } else {
                return
            }

            selectedSites.wrappedValue = sites

            if wasSelection {
                tapPositions.wrappedValue[hit.label] = (
                    label: hit.label,
                    worldX: Double(hit.worldPosition.x),
                    worldY: Double(hit.worldPosition.y),
                    worldZ: Double(hit.worldPosition.z),
                    normalX: Double(hit.worldNormal.x),
                    normalY: Double(hit.worldNormal.y),
                    normalZ: Double(hit.worldNormal.z)
                )
            } else if let removed = removedLabel {
                tapPositions.wrappedValue.removeValue(forKey: removed)
            }

            let overlapsExisting = checkOverlap(newZone: hit.label)

            let feedback = UIImpactFeedbackGenerator(style: .light)
            feedback.impactOccurred()
            if wasSelection && overlapsExisting {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }

            if wasSelection, let mat = skinMaterial {
                let now = CACurrentMediaTime()
                heatMapRenderer?.triggerRipple(at: hit.worldPosition, material: mat, currentTime: now)
            }

            syncPersistentSpots()
            onTapZone?(hit.label, wasSelection && overlapsExisting)
            renderHeatMap()
        }

        private func checkOverlap(newZone: String) -> Bool {
            guard let store = centroidStore else { return false }

            let count = heatMapData[newZone] ?? 0
            guard count >= 2 else { return false }

            for (label, cnt) in heatMapData {
                guard label != newZone, cnt >= 2 else { continue }
                if store.zonesOverlap(newZone, label, heatMap: heatMapData) {
                    return true
                }
            }
            return false
        }

        func renderHeatMap() {
            let sites = Set(selectedSites.wrappedValue)
            if sites == lastRenderSites
                && heatMapData == lastRenderHeat
                && avoidZones == lastRenderAvoid
                && preferredZones == lastRenderPreferred
                && recommendedZones == lastRenderRecommended {
                heatMapRenderer?.updateCamera(cameraNode)
                return
            }
            lastRenderSites = sites
            lastRenderHeat = heatMapData
            lastRenderAvoid = avoidZones
            lastRenderPreferred = preferredZones
            lastRenderRecommended = recommendedZones
            heatMapRenderer?.update(
                heatMap: heatMapData,
                avoidZones: avoidZones,
                selectedZones: sites,
                preferredZones: preferredZones,
                recommendedZones: recommendedZones
            )
            heatMapRenderer?.updateCamera(cameraNode)
        }

    func syncPersistentSpots() {
        let spots = tapPositions.wrappedValue.values.map {
            SCNVector3(Float($0.worldX), Float($0.worldY), Float($0.worldZ))
        }
        let same = spots.count == lastPersistentCount &&
            zip(spots, lastPersistentSpots).allSatisfy {
                abs($0.x - $1.x) < 0.0001 &&
                abs($0.y - $1.y) < 0.0001 &&
                abs($0.z - $1.z) < 0.0001
            }
        guard !same else { return }
        lastPersistentCount = spots.count
        lastPersistentSpots = spots
        heatMapRenderer?.setPersistentSpots(spots)
    }

    }
}

// MARK: - Preview

#Preview {
    BodyModel3DView(
        heatMapData: [
            "Left Deltoid": 3,
            "Upper Left Abdomen": 1,
            "Right Upper Glute": 2,
            "Left Ventrogluteal": 4
        ],
        avoidZones: ["Left Forearm"],
        preferredZones: ["Upper Left Thigh", "Right Deltoid"],
        recommendedZones: [],
        selectedSites: .constant(["Left Deltoid"]),
        maxSelections: 1,
        onTapZone: { zone, overlapped in
            print("Tapped: \(zone), overlap: \(overlapped)")
        },
        tapPositions: .constant([:])
    )
    .frame(height: 440)
    .background(Color.black.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 24))
}
