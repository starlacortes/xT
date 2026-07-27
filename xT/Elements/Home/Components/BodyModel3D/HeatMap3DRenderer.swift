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

        // Assign shaderModifiers LAST so SceneKit sees all bound arguments
        // when it compiles the combined fragment shader (commonprofile_frag).
        mat.shaderModifiers = [SCNShaderModifierEntryPoint.surface: BodyHeatMapShader.surfaceModifier]

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

    /// Returns the world-space centroid position for a zone label.
    func centroid(for label: String) -> SCNVector3? {
        centroidStore.centroid(for: label)
    }

    // MARK: - Display link

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

        let now = Float(CACurrentMediaTime())
        let oldCount = animatedTaps.count
        animatedTaps.removeAll { now - $0.startTime > 0.75 }
        if animatedTaps.count != oldCount {
            uploadTapTexture()
        }
        if animatedTaps.isEmpty {
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
