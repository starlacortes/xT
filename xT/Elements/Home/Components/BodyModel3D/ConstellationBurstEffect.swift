import SceneKit
import simd

// MARK: - Layout

/// Deterministic layout for one tap constellation burst: a handful of star
/// offsets spread across a small disc in the tap's tangent plane (Z is the
/// surface normal, so the figure hugs the body), plus the connect-the-dots
/// chain. Pure value type so the layout is unit-testable without SceneKit.
struct ConstellationBurstLayout {

    /// Star offsets in the burst's local frame (X/Y = tangent plane,
    /// Z = lift above the surface). Each entry doubles as a star index.
    let positions: [SIMD3<Float>]

    /// `(from, to)` pairs into `positions`, in greedy nearest-neighbour
    /// chain order — the order the dots are drawn/connected in.
    let connections: [(Int, Int)]

    /// Radius of the constellation disc in meters (~10 cm across).
    static let defaultRadius: Float = 0.05

    /// Builds the layout from a deterministic seed. Stars are spread on an
    /// angular ring with jitter (reads as a playful figure, not a clump) and
    /// lifted slightly off the surface so they never z-fight the skin.
    static func make(seed: UInt64,
                     starCount: Int = 6,
                     radius: Float = defaultRadius) -> ConstellationBurstLayout {
        let starCount = max(3, starCount)
        var rng = SplitMix64(state: seed)

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(starCount)
        for i in 0..<starCount {
            let angle = (Float(i) + rng.nextUnit() * 0.6 - 0.3) * (.pi * 2 / Float(starCount))
            let r = radius * (0.45 + 0.55 * rng.nextUnit())
            let lift: Float = 0.006 + 0.010 * rng.nextUnit()
            points.append(SIMD3<Float>(cos(angle) * r, sin(angle) * r, lift))
        }

        // Greedy nearest-neighbour chain starting at star 0: the draw-in
        // order sweeps across the figure like drawing a constellation by hand.
        var order = [0]
        var remaining = Set(1..<starCount)
        while let current = order.last, !remaining.isEmpty {
            let next = remaining.min {
                simd_distance_squared(points[$0], points[current])
                    < simd_distance_squared(points[$1], points[current])
            }!
            remaining.remove(next)
            order.append(next)
        }
        let connections = zip(order, order.dropFirst()).map { ($0.0, $0.1) }

        return ConstellationBurstLayout(positions: points, connections: connections)
    }

}

// MARK: - Effect

/// Playful constellation tap feedback for the Time body diagram. Each tap on
/// the body spawns a small cluster of stars at the hit point that pop in one
/// by one along a connect-the-dots chain, twinkle gently while they hold,
/// then fade away — layered on top of the existing ripple/haptic, purely
/// visual, and excluded from the body's hit-tests by node name. Bursts are
/// also tap-responsive: every body tap briefly flares any bursts that are
/// still alive (`poke`), so rapid tapping makes the sky sparkle back.
///
/// Self-contained like `HeatMap3DRenderer`: owns its own `CADisplayLink`
/// because the Coordinator's link pauses whenever a region is selected
/// (which is exactly when taps land). The body itself never moves — the
/// camera orbits it — so anchoring the burst group to the world hit point is
/// enough; it stays glued to the spot as the view orbits.
@MainActor
final class ConstellationBurstEffect: NSObject {

    /// Node name applied to the burst group and both child nodes so the
    /// Coordinator's hit-test filter skips constellation geometry.
    static let nodeName = "constellationBurst"

    /// Cap on simultaneous bursts (matches the ripple's `maxTaps`); the
    /// oldest is dropped when a new tap would exceed it.
    static let maxConcurrentBursts = 4

    // MARK: Timeline constants (seconds)

    private static let stagger: Float = 0.055      // per-star delay along the chain
    private static let popDuration: Float = 0.13   // single star pop-in
    private static let lineLead: Float = 0.10      // segment appears just after its late star
    private static let fadeStart: Float = 0.80
    private static let lifetime: Float = 1.20
    // Reduce Motion: everything appears/fades together, no staggered pop.
    private static let reducedPopDuration: Float = 0.10
    private static let reducedFadeStart: Float = 0.35
    private static let reducedLifetime: Float = 0.70

    private struct Burst {
        let node: SCNNode
        let materials: [SCNMaterial]
        let birth: CFTimeInterval
        let lifetime: Float
        /// Tap-poke flare: 1 right after a poke, decays to 0 over ~0.4 s.
        var flare: Float = 0
    }

    private var lastFrameTime: CFTimeInterval = 0

    private var bursts: [Burst] = []
    private var link: CADisplayLink?
    private var spawnCounter: UInt64 = 0

    /// Spawns a constellation burst at the world-space tap point, oriented
    /// flat against the surface via `normal`. Fired from the Coordinator's
    /// tap handler alongside the ripple and haptic.
    func spawn(at world: SCNVector3,
               normal: SCNVector3,
               in scene: SCNScene,
               reduceMotion: Bool,
               lightMode: Bool) {
        spawnCounter &+= 1
        let layout = ConstellationBurstLayout.make(seed: spawnCounter &* 0xD1B54A32D192ED03)

        let group = SCNNode()
        group.name = Self.nodeName
        group.simdTransform = Self.localFrame(at: SIMD3<Float>(world),
                                              normal: SIMD3<Float>(normal))
        group.renderingOrder = 11   // above the bodies' starfield (10)

        let (geometry, materials) = Self.makeGeometry(layout: layout,
                                                      reduceMotion: reduceMotion,
                                                      lightMode: lightMode)
        for childGeometry in geometry {
            let child = SCNNode(geometry: childGeometry)
            child.name = Self.nodeName
            group.addChildNode(child)
        }
        scene.rootNode.addChildNode(group)

        while bursts.count >= Self.maxConcurrentBursts {
            bursts.removeFirst().node.removeFromParentNode()
        }
        bursts.append(Burst(node: group,
                            materials: materials,
                            birth: CACurrentMediaTime(),
                            lifetime: reduceMotion ? Self.reducedLifetime : Self.lifetime))
        startLinkIfNeeded()
    }

    /// Tap-responsive sparkle: briefly flares every burst that is still
    /// alive. Called for each body tap (before `spawn`, so the new burst
    /// isn't pre-flared); the flare decays away in `tick`.
    func poke() {
        for i in bursts.indices {
            bursts[i].flare = 1
        }
    }

    /// Stops the clock and removes in-flight bursts — call on view teardown.
    func invalidate() {
        link?.invalidate()
        link = nil
        for b in bursts { b.node.removeFromParentNode() }
        bursts.removeAll()
    }

    // MARK: Display link

    private func startLinkIfNeeded() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastFrameTime == 0 ? 0 : Float(now - lastFrameTime)
        lastFrameTime = now

        for i in bursts.indices {
            let t = Float(now - bursts[i].birth)
            guard t <= bursts[i].lifetime else { continue }

            // Decay the tap-poke flare (~0.4 s to zero) and feed the clock.
            let flare = max(0, bursts[i].flare - dt * 2.5)
            bursts[i].flare = flare
            for m in bursts[i].materials {
                m.setValue(t, forKey: "u_burstTime")
                m.setValue(flare, forKey: "u_flare")
            }
            // Subtle whole-figure pop on poke.
            let s: Float = 1 + 0.08 * flare
            bursts[i].node.scale = SCNVector3(x: s, y: s, z: s)
        }
        bursts.removeAll { burst in
            guard Float(now - burst.birth) > burst.lifetime else { return false }
            burst.node.removeFromParentNode()
            return true
        }
        if bursts.isEmpty {
            link?.invalidate()
            link = nil
            lastFrameTime = 0
        }
    }

    // MARK: Frame & geometry

    /// Orthonormal frame with Z along the surface normal so the layout's
    /// tangent-plane disc lies flat against the body at `world`.
    private static func localFrame(at world: SIMD3<Float>, normal: SIMD3<Float>) -> float4x4 {
        let n = simd_length_squared(normal) > 1e-6
            ? simd_normalize(normal)
            : SIMD3<Float>(0, 0, 1)
        let ref: SIMD3<Float> = abs(n.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        let t = simd_normalize(simd_cross(ref, n))
        let b = simd_normalize(simd_cross(n, t))
        var m = float4x4(1)
        m.columns.0 = SIMD4(t, 0)
        m.columns.1 = SIMD4(b, 0)
        m.columns.2 = SIMD4(n, 0)
        m.columns.3 = SIMD4(world, 1)
        return m
    }

    /// Builds the star point-cloud and the line geometry for one burst along
    /// with their materials (one material per geometry; both carry the burst
    /// clock uniform so the shader animates the whole timeline).
    private static func makeGeometry(layout: ConstellationBurstLayout,
                                     reduceMotion: Bool,
                                     lightMode: Bool) -> ([SCNGeometry], [SCNMaterial]) {
        let count = layout.positions.count

        // Draw-in order from the chain: connection k links order[k] → order[k+1].
        var order = [Int]()
        if let first = layout.connections.first {
            order.append(first.0)
            order.append(contentsOf: layout.connections.map { $0.1 })
        } else {
            order = Array(0..<count)
        }
        var delay = [Float](repeating: 0, count: count)
        for (k, star) in order.enumerated() {
            delay[star] = reduceMotion ? 0 : Float(k) * stagger
        }

        // MARK: Stars (point cloud)

        var xyz = [Float]()
        var rgba = [Float]()
        for (i, p) in layout.positions.enumerated() {
            xyz.append(contentsOf: [p.x, p.y, p.z])
            let c = starColor(index: i, count: count)
            rgba.append(contentsOf: [c.x, c.y, c.z, delay[i]])
        }

        let starSources = [
            SCNGeometrySource(
                data: xyz.withUnsafeBufferPointer { Data(buffer: $0) },
                semantic: .vertex, vectorCount: count, usesFloatComponents: true,
                componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3),
            SCNGeometrySource(
                data: rgba.withUnsafeBufferPointer { Data(buffer: $0) },
                semantic: .color, vectorCount: count, usesFloatComponents: true,
                componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0, dataStride: MemoryLayout<Float>.size * 4),
        ]
        let starElement = SCNGeometryElement(indices: Array(0..<UInt32(count)),
                                             primitiveType: .point)
        starElement.pointSize = 5.0
        starElement.minimumPointScreenSpaceRadius = 2.0
        starElement.maximumPointScreenSpaceRadius = 9.0
        let starGeometry = SCNGeometry(sources: starSources, elements: [starElement])
        let starMaterial = makeMaterial(lightMode: lightMode, reduceMotion: reduceMotion)
        starGeometry.materials = [starMaterial]

        // MARK: Lines (connect-the-dots)

        var lxyz = [Float]()
        var lrgba = [Float]()
        var indices = [UInt32]()
        for (a, b) in layout.connections {
            // A segment pops in right after its later star (chain order makes
            // `b` the later one), so the dots connect as they appear.
            let lineDelay = reduceMotion ? 0 : delay[b] + lineLead
            let base = UInt32(lxyz.count / 3)
            for s in [a, b] {
                let p = layout.positions[s]
                lxyz.append(contentsOf: [p.x, p.y, p.z])
                // Dimmer than the stars so the lines read as links, not stars.
                lrgba.append(contentsOf: [0.62, 0.58, 0.50, lineDelay])
            }
            indices.append(contentsOf: [base, base + 1])
        }

        let lineSources = [
            SCNGeometrySource(
                data: lxyz.withUnsafeBufferPointer { Data(buffer: $0) },
                semantic: .vertex, vectorCount: lxyz.count / 3, usesFloatComponents: true,
                componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0, dataStride: MemoryLayout<Float>.size * 3),
            SCNGeometrySource(
                data: lrgba.withUnsafeBufferPointer { Data(buffer: $0) },
                semantic: .color, vectorCount: lrgba.count / 4, usesFloatComponents: true,
                componentsPerVector: 4, bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0, dataStride: MemoryLayout<Float>.size * 4),
        ]
        let lineElement = SCNGeometryElement(indices: indices, primitiveType: .line)
        let lineGeometry = SCNGeometry(sources: lineSources, elements: [lineElement])
        let lineMaterial = makeMaterial(lightMode: lightMode, reduceMotion: reduceMotion)
        lineGeometry.materials = [lineMaterial]

        return ([starGeometry, lineGeometry], [starMaterial, lineMaterial])
    }

    /// Shared material for a burst's geometry: additive glow in dark mode,
    /// alpha-blended deepened stars on a pale background (same split the main
    /// starfield uses, since near-white additive glow vanishes on white).
    private static func makeMaterial(lightMode: Bool, reduceMotion: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.blendMode = lightMode ? .alpha : .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        m.shaderModifiers = [.geometry: burstModifier]
        m.setValue(Float(0), forKey: "u_burstTime")
        m.setValue(Float(0), forKey: "u_flare")
        m.setValue(Float(reduceMotion ? 0 : 1), forKey: "u_twinkle")
        m.setValue(Self.fadeStart(for: reduceMotion), forKey: "u_fadeStart")
        m.setValue(Self.lifetime(for: reduceMotion), forKey: "u_lifetime")
        m.setValue(Self.popDuration(for: reduceMotion), forKey: "u_popDuration")
        m.setValue(Float(lightMode ? 1 : 0), forKey: "u_onLight")
        return m
    }

    /// Per-point timeline: `_geometry.color.a` carries the star's (or
    /// segment's) draw-in delay, consumed here and never leaked into blending.
    /// On top of the pop-in/fade-out envelope this adds a gentle per-star
    /// twinkle during the hold (phase/speed derived from the quantized delay,
    /// so no extra vertex storage is needed) and a tap-poke flare (`u_flare`,
    /// decayed CPU-side) that briefly brightens the whole figure. Dark mode
    /// fades via brightness (additive); light mode keeps the hue and fades
    /// via alpha so the stars stay visible on a pale background.
    private static let burstModifier = """
    #pragma arguments
    float u_burstTime;
    float u_fadeStart;
    float u_lifetime;
    float u_popDuration;
    float u_onLight;
    float u_flare;
    float u_twinkle;

    #pragma body
    float delay = _geometry.color.a;
    float e = smoothstep(delay, delay + u_popDuration, u_burstTime);
    e *= 1.0 - smoothstep(u_fadeStart, u_lifetime, u_burstTime);

    // Twinkle, eased in only after the pop so the draw-in stays crisp;
    // disabled entirely under Reduce Motion (u_twinkle = 0).
    float settle = u_twinkle * smoothstep(delay + u_popDuration, delay + u_popDuration + 0.15, u_burstTime);
    float ph = fract(delay * 7.31);
    float sp = 1.6 + 1.7 * fract(delay * 13.73);
    float tw = mix(1.0, 0.78 + 0.22 * sin(u_burstTime * sp * 6.2831 + ph * 6.2831), settle);
    e *= tw;

    // Tap poke: brief whole-figure flare (brightness in dark mode, alpha in light).
    float glowing = e * (1.0 + 0.8 * u_flare);
    float3 col = _geometry.color.rgb * mix(1.0, 0.45, u_onLight);
    col *= mix(glowing, 1.0, u_onLight);
    float a = mix(1.0, min(e + 0.5 * u_flare, 1.0), u_onLight);
    _geometry.color = float4(col, a);
    """

    private static func fadeStart(for reduceMotion: Bool) -> Float {
        reduceMotion ? reducedFadeStart : fadeStart
    }

    private static func lifetime(for reduceMotion: Bool) -> Float {
        reduceMotion ? reducedLifetime : lifetime
    }

    private static func popDuration(for reduceMotion: Bool) -> Float {
        reduceMotion ? reducedPopDuration : popDuration
    }

    /// Deliberately *not* theme-tinted, so the burst sparkles against the
    /// starfield body.
    private static func starColor(index: Int, count: Int) -> SIMD3<Float> {
        StarPalette.burstSequence[index % StarPalette.burstSequence.count]
    }
}
