import SceneKit
import SwiftUI
import simd

// MARK: - Region model

/// The six tappable regions of the Time whole-body diagram: five HRT body
/// regions (matching the keys in `TimeBodyRegions.bodyRegions`) plus the head,
/// which surfaces the "Mind" content.
///
/// Anchors are in the world frame `BodyTransform` establishes: `+Y` up with the
/// feet at `y = 0` and the crown near `y = 1.5`, `+Z` facing the camera, and
/// `+X` the body's anatomical left. Selection is resolved by nearest anchor to
/// the tapped surface point, so the head (which has no clinical injection zone)
/// is handled the same way as the body regions.
enum TimeRegionKey: String, CaseIterable, Identifiable {
    case head, chest, waist, hips, glutes, thighs

    var id: String { rawValue }

    var isMind: Bool { self == .head }

    /// Matching key into `TimeBodyRegions.bodyRegions` (nil for the head/Mind).
    var bodyRegionKey: String? { isMind ? nil : rawValue }

    var title: String {
        switch self {
        case .head:   return String(localized: "Mind")
        case .chest:  return String(localized: "Chest")
        case .waist:  return String(localized: "Waist")
        case .hips:   return String(localized: "Hips")
        case .glutes: return String(localized: "Glutes")
        case .thighs: return String(localized: "Thighs")
        }
    }

    var worldAnchor: SIMD3<Float> {
        switch self {
        case .head:   return SIMD3<Float>(0.00, 1.40,  0.02)
        case .chest:  return SIMD3<Float>(0.00, 1.14,  0.10)
        case .waist:  return SIMD3<Float>(0.00, 0.98,  0.08)
        case .hips:   return SIMD3<Float>(0.00, 0.88,  0.07)
        case .glutes: return SIMD3<Float>(0.00, 0.86, -0.10)
        case .thighs: return SIMD3<Float>(0.00, 0.55,  0.06)
        }
    }
}

// MARK: - View

/// A single interactive whole-body 3-D diagram for the Time screen. The body
/// rests centred in theme-coloured skin with a slow idle rotation; tapping a
/// region fires the shared ripple, animates the camera to zoom in and shift the
/// body off the left edge (or, for the head, down and rotated to expose the
/// skull), and dissolves the skin into a twinkling constellation starfield.
struct TimeBodyDiagramView: UIViewRepresentable {

    var bodyType: BodyType
    @Binding var selectedRegion: TimeRegionKey?
    var themeColor: Color
    var reduceMotion: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isJitteringEnabled = true

        let scene = SCNScene()
        scnView.scene = scene

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 42
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode

        setupLighting(in: scene)
        loadBody(into: scene, scnView: scnView, context: context)

        let c = context.coordinator
        c.scnView = scnView
        c.cameraNode = cameraNode
        c.reduceMotion = reduceMotion
        c.applyCamera()
        c.startLink()

        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.reduceMotion = reduceMotion
        c.onSelectRegion = { region in
            withAnimation(.easeInOut(duration: 0.3)) { selectedRegion = region }
        }

        if c.appliedThemeColor != themeColor {
            c.appliedThemeColor = themeColor
            c.skinMaterial?.diffuse.contents = UIColor(themeColor)
        }

        if selectedRegion != c.appliedRegion {
            c.appliedRegion = selectedRegion
            c.focus(on: selectedRegion)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopLink()
    }

    // MARK: - Scene setup

    private func setupLighting(in scene: SCNScene) {
        scene.lightingEnvironment.contents = UIColor(white: 0.92, alpha: 1.0)
        scene.lightingEnvironment.intensity = 1.8

        func addLight(_ color: UIColor, _ intensity: CGFloat, _ position: SCNVector3, shadow: Bool = false) {
            let node = SCNNode()
            node.light = SCNLight()
            node.light?.type = .directional
            node.light?.color = color
            node.light?.intensity = intensity
            if shadow {
                node.light?.castsShadow = true
                node.light?.shadowMode = .deferred
                node.light?.shadowRadius = 4
                node.light?.shadowColor = UIColor(white: 0, alpha: 0.15)
            }
            node.position = position
            node.look(at: SCNVector3(0, 0.85, 0))
            scene.rootNode.addChildNode(node)
        }

        addLight(UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0), 820, SCNVector3(1.5, 2.5, 2.0), shadow: true)
        addLight(UIColor(red: 0.82, green: 0.88, blue: 1.00, alpha: 1.0), 380, SCNVector3(-1.5, 1.8, 1.0))
        addLight(UIColor(white: 0.72, alpha: 1.0), 500, SCNVector3(0, 1.5, -2.5))
    }

    private func loadBody(into scene: SCNScene, scnView: SCNView, context: Context) {
        let name = bodyType.usdzName
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models")
            ?? Bundle.main.url(forResource: name, withExtension: "usdz")
            ?? Bundle.main.url(forResource: "body_neutral", withExtension: "usdz", subdirectory: "Models")
            ?? Bundle.main.url(forResource: "body_neutral", withExtension: "usdz"),
              let modelScene = try? SCNScene(url: url, options: [.checkConsistency: true, .flattenScene: false])
        else {
            print("[TimeBodyDiagramView] ⚠️ \(name).usdz not found")
            return
        }

        let wrapper = SCNNode()
        for child in modelScene.rootNode.childNodes { wrapper.addChildNode(child) }
        scene.rootNode.addChildNode(wrapper)

        // Detect stored orientation from wrapper-space vertices (same approach as
        // BodyModel3DView) so a regenerated mesh can't silently flip the body.
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
        guard let transform = BodyTransform(boundingBox: (min: minB, max: maxB), orientation: orientation) else {
            print("[TimeBodyDiagramView] ⚠️ Degenerate bounding box")
            return
        }
        transform.apply(to: wrapper)

        let skin = SCNMaterial()
        skin.lightingModel = .physicallyBased
        skin.diffuse.contents = UIColor(themeColor)
        skin.roughness.contents = Float(0.62)
        skin.metalness.contents = Float(0.0)
        skin.isDoubleSided = false
        wrapper.enumerateChildNodes { node, _ in
            if node.geometry != nil { node.geometry?.materials = [skin] }
        }

        let c = context.coordinator
        c.skinMaterial = skin
        c.appliedThemeColor = themeColor

        guard let device = scnView.device else {
            print("[TimeBodyDiagramView] ⚠️ No Metal device")
            return
        }
        let renderer = HeatMap3DRenderer(material: skin, bodyType: bodyType, centroidStore: ZoneCentroidStore.shared)
        renderer.attachShader(to: device)
        // Zero the data textures once so the (undefined) initial contents don't
        // paint stray heat — this diagram never uploads real zone data.
        renderer.update(heatMap: [:], avoidZones: [], selectedZones: [], preferredZones: [], recommendedZones: [])
        renderer.setPersistentSpots([])
        c.heatMapRenderer = renderer

        // Build the constellation starfield from the densest child mesh's own
        // vertices. The star node carries that mesh's world transform but hangs
        // off the scene root — NOT the wrapper — because node opacity multiplies
        // down the hierarchy, and the cross-fade drives the wrapper to opacity 0
        // (which would take the stars with it). The body's pose is fixed after
        // load (the idle rotation orbits the camera), so a one-time transform
        // copy keeps every star exactly on the skin it replaces.
        var meshNode: SCNNode?
        var mostVertices = 0
        wrapper.enumerateChildNodes { node, _ in
            guard let count = node.geometry?.sources(for: .vertex).first?.vectorCount else { return }
            if count > mostVertices { mostVertices = count; meshNode = node }
        }
        if let meshNode, let vertexSource = meshNode.geometry?.sources(for: .vertex).first {
            let positions = StarFieldGeometry.readPositions(vertexSource)
            let starNode = SCNNode(geometry: StarFieldGeometry.make(positions: positions))
            starNode.transform = meshNode.worldTransform
            starNode.opacity = 0
            starNode.isHidden = true
            starNode.castsShadow = false
            starNode.renderingOrder = 10   // draw after the fading skin
            scene.rootNode.addChildNode(starNode)
            renderer.attachStarField(starNode: starNode, bodyNode: wrapper)
            c.starNode = starNode
        } else {
            print("[TimeBodyDiagramView] ⚠️ No mesh geometry found for starfield")
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject {

        struct FocusConfig {
            var yaw: Float
            var pitch: Float
            var distance: Float
            var lookAt: SIMD3<Float>
            var biasX: Float
            var biasY: Float
            var constellation: Float

            static func lerp(_ a: FocusConfig, _ b: FocusConfig, _ t: Float) -> FocusConfig {
                func l(_ x: Float, _ y: Float) -> Float { x + (y - x) * t }
                return FocusConfig(
                    yaw: l(a.yaw, b.yaw),
                    pitch: l(a.pitch, b.pitch),
                    distance: l(a.distance, b.distance),
                    lookAt: a.lookAt + (b.lookAt - a.lookAt) * t,
                    biasX: l(a.biasX, b.biasX),
                    biasY: l(a.biasY, b.biasY),
                    constellation: l(a.constellation, b.constellation)
                )
            }
        }

        weak var scnView: SCNView?
        weak var cameraNode: SCNNode?
        weak var skinMaterial: SCNMaterial?
        weak var starNode: SCNNode?
        var heatMapRenderer: HeatMap3DRenderer?

        var reduceMotion = false
        var appliedRegion: TimeRegionKey?
        var appliedThemeColor: Color?
        var onSelectRegion: ((TimeRegionKey?) -> Void)?

        private let idleSpeed: Float = 0.085
        private var current = Coordinator.restingConfig(startYaw: 0)
        private var from = Coordinator.restingConfig(startYaw: 0)
        private var to = Coordinator.restingConfig(startYaw: 0)
        private var animating = false
        private var hasSelection = false
        private var animStart: CFTimeInterval = 0
        private let animDuration: CFTimeInterval = 0.55
        private var lastTick: CFTimeInterval = 0
        private var link: CADisplayLink?

        // MARK: Config presets

        static func restingConfig(startYaw: Float) -> FocusConfig {
            // A level orbit (pitch 0) about the body's vertical midline keeps the
            // idle rotation even rather than looking lop-sided. lookAt.y = 0.67
            // sits the body in the visible area (below the hero header, with the
            // feet clear of the tab bar) rather than the raw screen centre.
            FocusConfig(yaw: startYaw, pitch: 0.0, distance: 2.6,
                        lookAt: SIMD3<Float>(0, 0.67, 0), biasX: 0, biasY: 0, constellation: 0)
        }

        private func focusConfig(for key: TimeRegionKey, startYaw: Float) -> FocusConfig {
            if key.isMind {
                // Zoom into the head from the anatomical-left with a slight downward
                // tilt. biasY = 0.12 nudges the head below viewport centre so the
                // Mind info panel (pinned at the top of the screen) doesn't overlap it.
                return FocusConfig(yaw: .pi / 2, pitch: 0.34, distance: 0.98,
                                   lookAt: key.worldAnchor, biasX: 0, biasY: 0.12, constellation: 1)
            } else {
                // Zoom into the region and push the body off the left edge so the
                // info panel owns the right of the screen. Rotate to the back for
                // regions that live on the posterior (glutes) so the glowing region
                // actually faces the camera.
                let yaw: Float = (key == .glutes) ? .pi : 0
                return FocusConfig(yaw: yaw, pitch: 0.02, distance: 1.20,
                                   lookAt: key.worldAnchor, biasX: 0.28, biasY: 0, constellation: 1)
            }
        }

        // MARK: Focus

        func focus(on region: TimeRegionKey?) {
            link?.isPaused = false
            from = current
            if let region {
                to = focusConfig(for: region, startYaw: current.yaw)
                hasSelection = true
                let a = region.worldAnchor
                heatMapRenderer?.setRegionGlow(center: SCNVector3(a.x, a.y, a.z),
                                               radius: region.isMind ? 0.30 : 0.30)
            } else {
                to = Coordinator.restingConfig(startYaw: current.yaw)
                hasSelection = false
                heatMapRenderer?.setRegionGlow(center: nil, radius: 0)
            }

            if reduceMotion {
                current = to
                applyCamera()
                heatMapRenderer?.setConstellation(to.constellation, twinkle: false)
                animating = false
                if hasSelection { link?.isPaused = true }
            } else {
                animStart = CACurrentMediaTime()
                animating = true
            }
        }

        // MARK: Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let pt = gesture.location(in: view)
            let results = view.hitTest(pt, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .boundingBoxOnly: false
            ])
            // Skip the star point cloud so taps always resolve against the body
            // surface, even mid-dissolve.
            guard let hit = results.first(where: { $0.node.geometry != nil && $0.node !== starNode }) else { return }

            let world = hit.worldCoordinates
            let region = Self.nearestRegion(to: SIMD3<Float>(Float(world.x), Float(world.y), Float(world.z)))

            if let mat = skinMaterial {
                heatMapRenderer?.triggerRipple(at: world, material: mat, currentTime: CACurrentMediaTime())
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            // Toggle: tapping the already-selected region deselects it.
            let next: TimeRegionKey? = (region == appliedRegion) ? nil : region
            onSelectRegion?(next)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = scnView else { return }
            if gesture.state == .began {
                // Cancel any in-flight focus animation so the drag takes immediate effect.
                animating = false
                link?.isPaused = false
            }
            let delta = gesture.translation(in: view)
            current.yaw -= Float(delta.x) * 0.005
            applyCamera()
            gesture.setTranslation(.zero, in: view)
            if (gesture.state == .ended || gesture.state == .cancelled) && hasSelection {
                link?.isPaused = true
            }
        }

        static func nearestRegion(to p: SIMD3<Float>) -> TimeRegionKey {
            // The head is a small target and idle rotation orbits the camera (not the
            // body), so a hit's world-Y is a stable, orientation-independent cue: any
            // tap above the shoulders resolves to the head/Mind, making it reliable to
            // hit without stealing the chest (anchored at y ≈ 1.14).
            if p.y >= 1.30 { return .head }
            return TimeRegionKey.allCases
                .filter { $0 != .head }
                .min { simd_distance($0.worldAnchor, p) < simd_distance($1.worldAnchor, p) }!
        }

        // MARK: Display link

        func startLink() {
            guard link == nil else { return }
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        }

        func stopLink() {
            link?.invalidate()
            link = nil
        }

        @objc private func tick() {
            let now = CACurrentMediaTime()
            let dt = lastTick == 0 ? 0 : now - lastTick
            lastTick = now

            if animating {
                let t = min(Float((now - animStart) / animDuration), 1)
                let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                current = FocusConfig.lerp(from, to, e)
                applyCamera()
                heatMapRenderer?.setConstellation(current.constellation, twinkle: true)
                if t >= 1 {
                    animating = false
                    if hasSelection { link?.isPaused = true }
                }
            } else if !hasSelection && !reduceMotion {
                current.yaw += idleSpeed * Float(dt)
                applyCamera()
            } else {
                link?.isPaused = true
            }
        }

        // MARK: Camera

        func applyCamera() {
            guard let cam = cameraNode else { return }
            let c = current
            let hr = c.distance * cos(c.pitch)
            let base = c.lookAt + SIMD3<Float>(hr * sin(c.yaw), c.distance * sin(c.pitch), hr * cos(c.yaw))
            let viewDir = simd_normalize(c.lookAt - base)
            let up = SIMD3<Float>(0, 1, 0)
            var right = simd_cross(viewDir, up)
            let rl = simd_length(right)
            right = rl > 1e-5 ? right / rl : SIMD3<Float>(1, 0, 0)
            let shift = right * c.biasX + up * c.biasY
            let pos = base + shift
            let look = c.lookAt + shift
            cam.simdPosition = pos
            // Pin the up vector to world +Y. The plain `look(at:)` variant reuses
            // the camera's current up, so per-frame roll error compounds over the
            // idle orbit and the body slowly appears to spin "diagonally".
            cam.simdLook(at: look, up: SIMD3<Float>(0, 1, 0), localFront: SCNNode.simdLocalFront)
            heatMapRenderer?.updateCamera(cam)
        }
    }
}
