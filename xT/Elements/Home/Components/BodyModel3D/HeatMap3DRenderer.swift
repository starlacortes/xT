import SceneKit
import Metal

@MainActor
final class HeatMap3DRenderer {

    typealias HeatMapData = [String: Int]

    private weak var material: SCNMaterial?
    private let centroidStore: ZoneCentroidStore
    private var displayLink: CADisplayLink?
    private var isDisplayLinkRunning = false

    private var zoneTex: MTLTexture?
    private var zoneMetaTex: MTLTexture?
    private var tapTex: MTLTexture?
    private let maxZones = BodyHeatMapShader.maxZones
    private let maxTaps  = BodyHeatMapShader.maxTaps

    // World positions + start times for animated tap ripples
    private var animatedTaps: [(center: SCNVector3, startTime: Float)] = []
    // Positions that persist indefinitely as red dots
    private var persistentSpots: [SCNVector3] = []
    // Keeps the display link ticking `u_currentTime` while the constellation
    // starfield is twinkling, even with no active ripples.
    private var constellationActive = false

    // Time-diagram starfield: the solid body wrapper cross-fades against a
    // point-cloud star node as `u_constellation` ramps (see attachStarField).
    private weak var bodyNode: SCNNode?
    private weak var starNode: SCNNode?
    private weak var starMaterial: SCNMaterial?
    /// When true, body node opacity is kept at 1 so SceneKit hit-testing still
    /// works against the mesh even when constellation = 1. The shader's own
    /// `u_constellation` already makes the skin visually dark; the star node
    /// (renderingOrder 10, additive blend) renders on top.
    var keepBodyOpacityAtOne = false

    init(material: SCNMaterial,
         bodyType: BodyType = .neutral,
         centroidStore: ZoneCentroidStore) {
        self.material = material
        self.centroidStore = centroidStore
    }

    // MARK: - Public API

    func attachShader(to device: MTLDevice) {
        guard let mat = material else { return }

        buildTextures(device: device)

        // Data textures need nearest-neighbor filtering — read() is used in the
        // shader, but SceneKit's implicit sampler settings still matter.
        func dataMaterialProperty(contents tex: MTLTexture) -> SCNMaterialProperty {
            let p = SCNMaterialProperty(contents: tex)
            p.minificationFilter = .nearest
            p.magnificationFilter = .nearest
            p.wrapS = .clamp
            p.wrapT = .clamp
            return p
        }

        if let tex = zoneTex { mat.setValue(dataMaterialProperty(contents: tex), forKey: "u_zoneTex") }
        if let meta = zoneMetaTex { mat.setValue(dataMaterialProperty(contents: meta), forKey: "u_zoneMetaTex") }
        if let taps = tapTex { mat.setValue(dataMaterialProperty(contents: taps), forKey: "u_tapTex") }

        mat.setValue(Float(CACurrentMediaTime()), forKey: "u_currentTime")
        mat.setValue(SCNMatrix4Identity, forKey: "u_invViewMatrix")
        // Inert defaults for the Time-diagram uniforms so hosts that never touch
        // them (e.g. QuickDoseSheet) render the solid skin unchanged.
        mat.setValue(Float(0), forKey: "u_constellation")
        mat.setValue(NSValue(scnVector4: SCNVector4(0, 0, 0, 0)), forKey: "u_regionGlow")

        // Assign shaderModifiers LAST so SceneKit sees all bound arguments
        // when it compiles the combined fragment shader (commonprofile_frag).
        // The .fragment modifier forces final output alpha to fade with
        // u_constellation — PBR-safe, unlike _surface.diffuse.a which physically
        // based lighting ignores as full transparency.
        mat.shaderModifiers = [
            SCNShaderModifierEntryPoint.surface: BodyHeatMapShader.surfaceModifier,
            SCNShaderModifierEntryPoint.fragment: BodyHeatMapShader.fragmentModifier,
        ]

        startDisplayLinkIfNeeded()
    }

    func update(heatMap: HeatMapData,
                avoidZones: Set<String>,
                selectedZones: Set<String>,
                preferredZones: Set<String>,
                recommendedZones: Set<String>) {
        uploadZoneTextures(heatMap: heatMap,
                           avoidZones: avoidZones,
                           selectedZones: selectedZones,
                           preferredZones: preferredZones,
                           recommendedZones: recommendedZones)
    }

    func updateCamera(_ cameraNode: SCNNode?) {
        guard let mat = material, let cam = cameraNode else { return }
        mat.setValue(NSValue(scnMatrix4: cam.worldTransform), forKey: "u_invViewMatrix")
    }

    /// Triggers a ripple animation at the given world-space hit point.
    func triggerRipple(at worldPos: SCNVector3, material: SCNMaterial?, currentTime: TimeInterval) {
        animatedTaps.append((center: worldPos, startTime: Float(currentTime)))
        uploadTapTexture()
        startDisplayLinkIfNeeded()
    }

    /// Sets which tap positions should stay as persistent red dots.
    func setPersistentSpots(_ spots: [SCNVector3]) {
        persistentSpots = spots
        uploadTapTexture()
    }

    // MARK: - Time diagram

    /// Registers the point-cloud starfield and the solid body's wrapper node so
    /// `setConstellation` can cross-fade between them. `starNode` must carry a
    /// `StarFieldGeometry` geometry; its material receives the `u_currentTime` /
    /// `u_regionGlow` / tap-bloom uniforms in lock-step with the skin material.
    func attachStarField(starNode: SCNNode, bodyNode: SCNNode) {
        self.starNode = starNode
        self.bodyNode = bodyNode
        starMaterial = starNode.geometry?.firstMaterial
        starMaterial?.setValue(Float(CACurrentMediaTime()), forKey: "u_currentTime")
        starMaterial?.setValue(NSValue(scnVector4: SCNVector4(0, 0, 0, 0)), forKey: "u_regionGlow")
        starMaterial?.setValue(NSValue(scnVector3: SCNVector3(0, 0, 0)), forKey: "u_tintColor")
        starMaterial?.setValue(Float(0), forKey: "u_tintStrength")
        starMaterial?.setValue(NSValue(scnVector3: SCNVector3(0, 0, 0)), forKey: "u_tapCenter")
        starMaterial?.setValue(Float(0), forKey: "u_tapStart")
    }

    /// Tints the star palette toward a theme-derived color.
    /// strength 0 = no tint (natural star colors), 1 = fully replaced by tintColor.
    func setStarTint(color: SIMD3<Float>, strength: Float) {
        starMaterial?.setValue(NSValue(scnVector3: SCNVector3(color.x, color.y, color.z)), forKey: "u_tintColor")
        starMaterial?.setValue(strength, forKey: "u_tintStrength")
    }

    /// Sets the constellation dissolve amount (0 = solid skin, 1 = full starfield).
    /// The solid body fades out as the star points fade in, so at 1 only the
    /// glowing starfield remains. When `twinkle` is true and the amount is > 0
    /// the display link keeps running so the starfield animates; pass
    /// `twinkle: false` (Reduce Motion) for a static starfield that doesn't
    /// hold the display link open.
    func setConstellation(_ amount: Float, twinkle: Bool = true) {
        material?.setValue(amount, forKey: "u_constellation")

        let a = CGFloat(min(max(amount, 0), 1))
        if !keepBodyOpacityAtOne { bodyNode?.opacity = 1 - a }
        if let starNode {
            starNode.opacity = a
            // Skip drawing ~8k invisible points when the skin is fully solid.
            starNode.isHidden = amount <= 0.001
        }

        constellationActive = twinkle && amount > 0.001
        if constellationActive {
            startDisplayLinkIfNeeded()
        } else if twinkle == false {
            // Advance the clock once so a static starfield has a defined phase.
            let now = Float(CACurrentMediaTime())
            material?.setValue(now, forKey: "u_currentTime")
            starMaterial?.setValue(now, forKey: "u_currentTime")
        }
    }

    /// Sets (or clears) the red glow centred on the selected region's world anchor.
    func setRegionGlow(center: SCNVector3?, radius: Float) {
        let v = center.map { SCNVector4($0.x, $0.y, $0.z, radius) } ?? SCNVector4(0, 0, 0, 0)
        material?.setValue(NSValue(scnVector4: v), forKey: "u_regionGlow")
        starMaterial?.setValue(NSValue(scnVector4: v), forKey: "u_regionGlow")
    }

    /// Triggers a soft radial bloom in the starfield at the tap world position.
    /// The bloom rises quickly and fades over ~0.5 s. Has no effect when the
    /// star material isn't wired up (e.g. QuickDose, which uses the skin ripple).
    func triggerTapBloom(at world: SCNVector3) {
        starMaterial?.setValue(NSValue(scnVector3: world), forKey: "u_tapCenter")
        starMaterial?.setValue(Float(CACurrentMediaTime()), forKey: "u_tapStart")
        startDisplayLinkIfNeeded()
    }

    // MARK: - Display link

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        isDisplayLinkRunning = false
    }

    private func startDisplayLinkIfNeeded() {
        guard !isDisplayLinkRunning else { return }
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        isDisplayLinkRunning = true
    }

    @objc private func tick() {
        guard let mat = material else { return }
        mat.setValue(Float(CACurrentMediaTime()), forKey: "u_currentTime")
        starMaterial?.setValue(Float(CACurrentMediaTime()), forKey: "u_currentTime")

        let now = Float(CACurrentMediaTime())
        let oldCount = animatedTaps.count
        animatedTaps.removeAll { now - $0.startTime > 0.75 }
        if animatedTaps.count != oldCount {
            uploadTapTexture()
        }
        if animatedTaps.isEmpty && !constellationActive {
            displayLink?.invalidate()
            displayLink = nil
            isDisplayLinkRunning = false
        }
    }

    // MARK: - Texture upload

    private func buildTextures(device: MTLDevice) {
        let zoneDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: maxZones,
            height: 1,
            mipmapped: false
        )
        zoneDesc.usage = [.shaderRead]
        zoneTex = device.makeTexture(descriptor: zoneDesc)
        zoneMetaTex = device.makeTexture(descriptor: zoneDesc)

        let tapDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: maxTaps,
            height: 1,
            mipmapped: false
        )
        tapDesc.usage = [.shaderRead]
        tapTex = device.makeTexture(descriptor: tapDesc)
    }

    private func uploadTapTexture() {
        guard let tapTex else { return }

        var tapData = [Float](repeating: 0, count: maxTaps * 4)
        var idx = 0

        // Persistent spots go first (persistent red dots)
        for spot in persistentSpots {
            guard idx < maxTaps / 2 else { break }
            let base = idx * 4
            tapData[base + 0] = spot.x
            tapData[base + 1] = spot.y
            tapData[base + 2] = spot.z
            tapData[base + 3] = -1.0 // special marker: persistent, no start time
            idx += 1
        }

        // Animated ripples next
        for tap in animatedTaps {
            guard idx < maxTaps else { break }
            let base = idx * 4
            tapData[base + 0] = tap.center.x
            tapData[base + 1] = tap.center.y
            tapData[base + 2] = tap.center.z
            tapData[base + 3] = tap.startTime
            idx += 1
        }

        let bytesPerRow = maxTaps * 16
        let region = MTLRegionMake2D(0, 0, maxTaps, 1)
        tapData.withUnsafeBytes { ptr in
            tapTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
    }

    private func uploadZoneTextures(heatMap: HeatMapData,
                                    avoidZones: Set<String>,
                                    selectedZones: Set<String>,
                                    preferredZones: Set<String>,
                                    recommendedZones: Set<String>) {
        guard let zoneTex, let zoneMetaTex else { return }

        let allZones = Set(heatMap.keys)
            .union(avoidZones)
            .union(preferredZones)
            .union(selectedZones)
            .union(recommendedZones)

        var posData  = [Float](repeating: 0, count: maxZones * 4)
        var metaData = [Float](repeating: 0, count: maxZones * 4)

        var idx = 0
        for label in allZones.sorted() {
            guard idx < maxZones else { break }
            guard let c = centroidStore.centroid(for: label) else { continue }

            let count   = heatMap[label] ?? 0
            let avoided = avoidZones.contains(label)
            let selected = selectedZones.contains(label)
            let preferred = preferredZones.contains(label)
            let recommended = recommendedZones.contains(label)

            let r = centroidStore.radius(for: label, count: count)
            let wr: Float = (count >= 2) ? r * 0.4472 : 0.0

            var flags: Int32 = 0
            if avoided     { flags |= 1 }
            if selected    { flags |= 2 }
            if preferred   { flags |= 4 }
            if recommended { flags |= 8 }

            let base = idx * 4
            posData[base + 0] = c.x
            posData[base + 1] = c.y
            posData[base + 2] = c.z
            posData[base + 3] = r

            metaData[base + 0] = wr
            metaData[base + 1] = Float(count)
            metaData[base + 2] = Float(flags)
            metaData[base + 3] = 0

            idx += 1
        }

        let bytesPerRow = maxZones * 16
        let region = MTLRegionMake2D(0, 0, maxZones, 1)

        posData.withUnsafeBytes { ptr in
            zoneTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
        metaData.withUnsafeBytes { ptr in
            zoneMetaTex.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: bytesPerRow)
        }
    }
}
