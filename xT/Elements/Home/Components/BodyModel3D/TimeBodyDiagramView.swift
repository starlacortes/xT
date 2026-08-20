import SceneKit
import SwiftUI
import simd

// MARK: - Region model

/// The six tappable regions of the Time whole-body diagram: five HRT body
/// regions (matching the keys in `TimeBodyRegions.bodyRegions`) plus the head,
/// which surfaces the "Mind" content. The pelvic-facing anatomy is split as:
/// belly/abdomen (its own region) vs. the merged hip + waist band — the
/// midriff ring, hip bones, and small of the back all belong to `hips`.
///
/// Anchors are in the world frame `BodyTransform` establishes: `+Y` up with the
/// feet at `y = 0` and the crown near `y = 1.5`, `+Z` facing the camera, and
/// `+X` the body's anatomical left. Selection is resolved by nearest anchor to
/// the tapped surface point, so the head (which has no clinical injection zone)
/// is handled the same way as the body regions.
enum TimeRegionKey: String, CaseIterable, Identifiable {
    case head, chest, abdomen, hips, glutes, thighs

    var id: String { rawValue }

    var isMind: Bool { self == .head }

    /// Matching key into `TimeBodyRegions.bodyRegions` (nil for the head/Mind).
    var bodyRegionKey: String? { isMind ? nil : rawValue }

    var title: String {
        switch self {
        case .head:    return String(localized: "Mind")
        case .chest:   return String(localized: "Chest")
        case .abdomen: return String(localized: "Abdomen")
        case .hips:    return String(localized: "Hips / Waist")
        case .glutes:  return String(localized: "Glutes")
        case .thighs:  return String(localized: "Thighs")
        }
    }

    /// Anchors define the nearest-anchor touch targets (see
    /// `Coordinator.nearestRegion`) and double as camera focus points / glow
    /// centers. Positions verified against the shipped body mesh (crown 1.50,
    /// mouth 1.30, navel ≈ 0.90, butt crease ≈ 0.93):
    /// - abdomen (0.94, z 0.09, far front) owns the belly — the navel resolves
    ///   to Abdomen, and the chest boundary sits at y ≈ 1.04 (under the bust).
    /// - hips (0.88, z ~0) owns the merged hip/waist band: from the front it
    ///   takes over below the belly, and on the back it beats Glutes for the
    ///   whole midriff, so the small of the back resolves to Hips / Waist.
    /// - glutes (0.80, z −0.12) stays behind the body centerline so its cell
    ///   only wins below the waistline on the back.
    var worldAnchor: SIMD3<Float> {
        switch self {
        case .head:    return SIMD3<Float>(0.00, 1.40,  0.02)
        case .chest:   return SIMD3<Float>(0.00, 1.14,  0.10)
        case .abdomen: return SIMD3<Float>(0.00, 0.94,  0.09)
        case .hips:    return SIMD3<Float>(0.00, 0.88,  0.02)
        case .glutes:  return SIMD3<Float>(0.00, 0.80, -0.12)
        case .thighs:  return SIMD3<Float>(0.00, 0.55,  0.06)
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
    var activeColor: Color
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
        // Show the resting constellation immediately — before any user tap — so
        // the starfield is visible from the moment the view appears.
        c.heatMapRenderer?.setConstellation(1.0, twinkle: !reduceMotion)
        if let tc = c.appliedThemeColor {
            c.heatMapRenderer?.setStarTint(
                color: Coordinator.restingStarTint(from: tc), strength: 0.85)
        }
        c.startLink()

        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = c
        scnView.addGestureRecognizer(pan)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let c = context.coordinator
        c.reduceMotion = reduceMotion
        c.onSelectRegion = { region in
            withAnimation(.easeInOut(duration: 0.3)) { selectedRegion = region }
        }

        if c.appliedThemeColor != themeColor || c.appliedActiveColor != activeColor {
            c.appliedThemeColor = themeColor
            c.appliedActiveColor = activeColor
            c.skinMaterial?.diffuse.contents = UIColor(themeColor)
            let isActive = c.appliedRegion != nil
            let tint = isActive
                ? Coordinator.activeStarTint(from: activeColor)
                : Coordinator.restingStarTint(from: themeColor)
            c.heatMapRenderer?.setStarTint(color: tint, strength: isActive ? 0.35 : 0.85)
        }

        if selectedRegion != c.appliedRegion {
            c.appliedRegion = selectedRegion
            c.focus(on: selectedRegion)
        }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stopLink()
        coordinator.invalidateBurstEffect()
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

    /// A small gray floor card standing between the legs ("front" facing the body's
    /// anatomical front, +Z; "back" facing −Z). The uniform starfield can hide which
    /// way the body is facing, so this gives the viewer a grounded cue for the
    /// rotation. It hangs off the world frame (not the wrapper) and the camera orbits
    /// about its vertical line, so the label you can read is always the side you're
    /// looking at. Height ≈ foot-to-ankle; excluded from region hit-tests by name.
    private func addOrientationCard(to scene: SCNScene) {
        let card = SCNNode()
        card.addChildNode(makeCardFace(word: "front", isBack: false))
        card.addChildNode(makeCardFace(word: "back", isBack: true))
        card.position = SCNVector3(0, 0.055, 0)
        scene.rootNode.addChildNode(card)
    }

    private func makeCardFace(word: String, isBack: Bool) -> SCNNode {
        // Bake the gray fill + label into one image; rounded corners read via alpha.
        // The label sits in the upper half of the card so it stays visible above the
        // resting hint pill that overlaps the bottom of the screen at foot level.
        let px = CGSize(width: 512, height: 384)
        let img = UIGraphicsImageRenderer(size: px).image { _ in
            UIColor(red: 0.62, green: 0.63, blue: 0.65, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: px), cornerRadius: 56).fill()
            let str = NSAttributedString(string: word, attributes: [
                .font: UIFont.systemFont(ofSize: 124, weight: .semibold),
                .foregroundColor: UIColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1.0),
                .kern: 2.0
            ])
            let s = str.size()
            str.draw(at: CGPoint(x: (px.width - s.width) / 2, y: px.height * 0.44 - s.height / 2))
        }
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.lightingModel = .constant   // stays readable through brightness/lighting shifts
        mat.isDoubleSided = false
        let face = SCNNode(geometry: SCNPlane(width: 0.15, height: 0.11))
        face.geometry?.materials = [mat]
        face.name = Coordinator.orientationCardName
        face.castsShadow = false
        if isBack {
            // A plane rotated π about Y with a normally-drawn texture reads correctly
            // when viewed from behind (no pre-mirroring needed).
            face.eulerAngles.y = .pi
            face.position.z = -0.0025
        } else {
            face.position.z = 0.0025
        }
        return face
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
        addOrientationCard(to: scene)

        let skin = SCNMaterial()
        skin.lightingModel = .physicallyBased
        skin.diffuse.contents = UIColor(themeColor)
        skin.roughness.contents = Float(0.62)
        skin.metalness.contents = Float(0.0)
        skin.isDoubleSided = false
        // Alpha blending + no depth writes let the shader fade the skin to
        // fully transparent (u_constellation = 1) without occluding the star
        // points. The node stays at opacity 1 so hit-testing still works.
        skin.blendMode = .alpha
        skin.writesToDepthBuffer = false
        wrapper.enumerateChildNodes { node, _ in
            if node.geometry != nil {
                // Hide eye meshes if the model has them as separate nodes —
                // only in the Time diagram, not QuickDose. The shipped
                // body_neutral/feminine/masculine USDZs are single-mesh
                // ("base_body_*") with no eye nodes, so this is a safety net
                // for future models; the shipped models' face glare is handled
                // by the star-cluster filter below.
                if let n = node.name?.lowercased(),
                   ["eye", "cornea", "iris", "pupil", "sclera"].contains(where: n.contains) {
                    node.isHidden = true
                    return
                }
                node.geometry?.materials = [skin]
            }
        }

        let c = context.coordinator
        c.skinMaterial = skin
        c.appliedThemeColor = themeColor
        c.appliedActiveColor = activeColor

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
            var positions = StarFieldGeometry.readPositions(vertexSource)
            // Density-normalize the head to an even star field. The USDZ mesh
            // packs far more vertices into facial features (eyes, mouth, ears,
            // nose) than into the scalp, so raw additive stars saturate into
            // glaring facial blobs — a bright nose/glabella triangle — while
            // simply deleting those clusters punched unsettling dark voids in
            // the face. Keeping at most one vertex per ~14 mm world-grid cell
            // gives the head a uniform constellation texture: no features
            // emerge, and no holes appear either. Everything below the chin
            // keeps the mesh's natural vertex distribution, which is already
            // even there. World frame: crown ≈ 1.50, chin ≈ 1.26.
            let M = simd_float4x4(meshNode.worldTransform)
            let headCutY: Float = 1.26
            let cell: Float = 0.014
            var used = Set<SIMD3<Int>>()
            used.reserveCapacity(positions.count / 8)
            var kept: [SIMD3<Float>] = []
            kept.reserveCapacity(positions.count)
            for p in positions {
                let w4 = M * SIMD4<Float>(p, 1)
                let w = SIMD3<Float>(w4.x, w4.y, w4.z) / w4.w
                if w.y >= headCutY {
                    let key = SIMD3<Int>(Int(floor(w.x / cell)),
                                         Int(floor(w.y / cell)),
                                         Int(floor(w.z / cell)))
                    if !used.insert(key).inserted { continue }
                }
                kept.append(p)
            }
            positions = kept
            let starNode = SCNNode(geometry: StarFieldGeometry.make(positions: positions))
            starNode.transform = meshNode.worldTransform
            starNode.opacity = 0
            starNode.isHidden = true
            starNode.castsShadow = false
            starNode.renderingOrder = 10   // draw after the fading skin
            scene.rootNode.addChildNode(starNode)
            renderer.attachStarField(starNode: starNode, bodyNode: wrapper)
            // Keep the body mesh at opacity 1 so SceneKit hit-tests still find
            // it when constellation = 1; the shader darkness + star overlay
            // provides the visual hiding.
            renderer.keepBodyOpacityAtOne = true
            c.starNode = starNode
        } else {
            print("[TimeBodyDiagramView] ⚠️ No mesh geometry found for starfield")
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        struct FocusConfig {
            var yaw: Float
            var pitch: Float
            var distance: Float
            var lookAt: SIMD3<Float>
            var biasX: Float
            var biasY: Float
            var constellation: Float

            /// Shortest signed angular offset from `a` to `b`, in (-π, π] —
            /// the "short way round" between two angles regardless of how many
            /// full turns `a` has accumulated.
            static func wrappedDelta(from a: Float, to b: Float) -> Float {
                atan2(sin(b - a), cos(b - a))
            }

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
        /// Playful tap-constellation bursts; owns its own display link (this
        /// Coordinator's link pauses while a region is selected).
        private let burstEffect = ConstellationBurstEffect()

        var reduceMotion = false
        var appliedRegion: TimeRegionKey?
        var appliedThemeColor: Color?
        var appliedActiveColor: Color?
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
            // idle rotation even rather than looking lop-sided. lookAt.y = 0.635
            // is between the original 0.67 framing (feet tucked behind the hint
            // pill — now moot since the pill auto-hides after 3 s) and the 0.60
            // lift used when the pill was permanent.
            // constellation: 1 — the body shows as a starfield even at rest,
            // tinted to a muted shade of the theme; the active state uses a
            // brighter tint variant (see restingStarTint / activeStarTint).
            FocusConfig(yaw: startYaw, pitch: 0.0, distance: 2.6,
                        lookAt: SIMD3<Float>(0, 0.635, 0), biasX: 0, biasY: 0, constellation: 1)
        }

        // MARK: Star tint helpers

        /// Dim, slightly cool-shifted version of the theme color for the resting starfield.
        static func restingStarTint(from color: Color) -> SIMD3<Float> {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            // Scaled up from the original *0.38/*0.48: the muted secondary accent
            // read as plain gray against the black backdrop once the skin is fully
            // transparent — this keeps enough luminance to register as lavender.
            return SIMD3<Float>(Float(r * 0.55), Float(g * 0.55), Float(b * 0.62))
        }

        /// Brightened version of the theme color for the active / region-selected starfield.
        static func activeStarTint(from color: Color) -> SIMD3<Float> {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(min(1, r * 1.2)), Float(min(1, g * 1.1)), Float(min(1, b * 1.3)))
        }

        private func focusConfig(for key: TimeRegionKey) -> FocusConfig {
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
                var t = focusConfig(for: region)
                // Idle spin accumulates unbounded yaw (`current.yaw` can be
                // tens of radians) while the focus preset's yaw is a small
                // wrapped value — interpolating straight between them would
                // unwind every accumulated turn in a single animation, which
                // reads as a violent spin. Wrap the target onto the nearest
                // equivalent angle so the camera travels at most half a turn,
                // the short way round.
                t.yaw = current.yaw + FocusConfig.wrappedDelta(from: current.yaw, to: t.yaw)
                to = t
                hasSelection = true
                let a = region.worldAnchor
                heatMapRenderer?.setRegionGlow(center: SCNVector3(a.x, a.y, a.z),
                                               radius: region.isMind ? 0.30 : 0.30)
                if let ac = appliedActiveColor {
                    heatMapRenderer?.setStarTint(color: Self.activeStarTint(from: ac), strength: 0.30)
                }
            } else {
                to = Coordinator.restingConfig(startYaw: current.yaw)
                hasSelection = false
                heatMapRenderer?.setRegionGlow(center: nil, radius: 0)
                if let tc = appliedThemeColor {
                    heatMapRenderer?.setStarTint(color: Self.restingStarTint(from: tc), strength: 0.85)
                }
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

        /// Node name for the front/back floor card — excluded from region hit-tests so a
        /// tap through it behaves like a tap on empty space (i.e. dismisses the card).
        static let orientationCardName = "timeOrientationCard"

        /// Node name for the playful tap-constellation bursts — excluded from
        /// region hit-tests so tapping through an active burst still resolves
        /// against the body surface behind it.
        static let burstNodeName = ConstellationBurstEffect.nodeName

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scnView else { return }
            let pt = gesture.location(in: view)
            let results = view.hitTest(pt, options: [
                .searchMode: SCNHitTestSearchMode.all.rawValue,
                .boundingBoxOnly: false
            ])
            // Skip the star point cloud and the orientation card so taps always resolve
            // against the body surface — the star node is always rendered now, so .all
            // mode is needed to reach the body mesh behind the points.
            guard let hit = results.first(where: {
                        $0.node.geometry != nil
                        && $0.node !== starNode
                        && $0.node.name != Self.orientationCardName
                        && $0.node.name != Self.burstNodeName
                    }) else {
                // Tap landed on open space: dismiss the open detail card. (Tapping a
                // different body region still switches regions, so a landing that hits
                // the body never reaches this branch.)
                if appliedRegion != nil { onSelectRegion?(nil) }
                return
            }

            let world = hit.worldCoordinates
            let region = Self.nearestRegion(to: SIMD3<Float>(Float(world.x), Float(world.y), Float(world.z)))

            if let mat = skinMaterial {
                heatMapRenderer?.triggerRipple(at: world, material: mat, currentTime: CACurrentMediaTime())
            }
            // Poke first so still-alive bursts flare; the fresh spawn below
            // starts un-flared and draws in on its own schedule.
            burstEffect.poke()
            if let scene = view.scene {
                burstEffect.spawn(at: world, normal: hit.worldNormal, in: scene,
                                  reduceMotion: reduceMotion,
                                  lightMode: false)
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
            current.yaw -= Float(delta.x) * 0.006
            applyCamera()
            gesture.setTranslation(.zero, in: view)
            if (gesture.state == .ended || gesture.state == .cancelled) && hasSelection {
                link?.isPaused = true
            }
        }

        /// Let the pan coexist with any other recognizer that might otherwise
        /// silently win the drag (e.g. the tap recognizer or a future SwiftUI
        /// gesture layered over the SceneKit view).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        static func nearestRegion(to p: SIMD3<Float>) -> TimeRegionKey {
            // The head is a small target and idle rotation orbits the camera (not the
            // body), so a hit's world-Y is a stable, orientation-independent cue.
            // Verified against the mesh: crown 1.50, chin ≈ 1.26, shoulder/trap
            // tops reach y = 1.266 — so the cut must sit at 1.28 (above the
            // shoulders, below the jaw). A narrow throat column extends Mind
            // down to the collar line (y 1.22) without stealing the lateral
            // trapezius for it (|x| > 0.065 keeps shoulders on Chest).
            if p.y >= 1.28 { return .head }
            if p.y >= 1.22, abs(p.x) < 0.065, p.z > -0.06 { return .head }
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

        /// Tears down any in-flight tap-constellation bursts (their display
        /// link, and their scene nodes).
        func invalidateBurstEffect() {
            burstEffect.invalidate()
        }

        @objc private func tick() {
            let now = CACurrentMediaTime()
            let dt = lastTick == 0 ? 0 : now - lastTick
            lastTick = now

            if animating {
                let t = min(Float((now - animStart) / animDuration), 1)
                let e = Float(Ease.inOutQuad(Double(t)))
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
