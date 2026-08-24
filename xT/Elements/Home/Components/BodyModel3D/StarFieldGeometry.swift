import SceneKit
import simd

/// Builds the constellation starfield for the Time diagram: a point-cloud
/// `SCNGeometry` whose points sit on a subsample of the body mesh's own
/// vertices, so the stars trace the body's silhouette exactly.
///
/// The geometry is built in the **mesh's source space** (the raw
/// `SCNGeometrySource` frame) and must be attached as a child of the mesh node
/// with an identity transform — it then inherits the body's full world pose and
/// stays vertex-aligned with the solid skin for free.
enum StarFieldGeometry {

    /// Star size tiers, drawn as separate point elements because point size is
    /// a per-element property. A real night sky is mostly faint stars with a
    /// scattering of bright ones; three tiers approximate that distribution.
    private struct Tier {
        var pointSize: CGFloat
        var minRadius: CGFloat
        var maxRadius: CGFloat
        /// Cumulative probability threshold in [0, 1).
        var threshold: Float
    }

    private static let tiers: [Tier] = [
        Tier(pointSize: 1.8, minRadius: 0.54, maxRadius: 1.8, threshold: 0.70), // faint
        Tier(pointSize: 2.7, minRadius: 1.08, maxRadius: 3.15, threshold: 0.95), // medium
        Tier(pointSize: 4.05, minRadius: 1.8, maxRadius: 5.4, threshold: 1.01), // bright
    ]

    /// Twinkle + selected-region highlight + soft tap bloom, evaluated per star
    /// in the vertex stage. `_geometry.color.a` carries each star's random phase
    /// (assigned at build time); it is consumed here and reset to 1 so it never
    /// leaks into blending. `u_regionGlow` is the same world-space uniform the
    /// body's surface shader uses, so the star highlight and the (fading) skin
    /// pulse agree about where the selected region is. `u_tapCenter` /
    /// `u_tapStart` drive a brief local bloom at the tap point — a fixed-radius
    /// warm glow that rises fast and fades in ~0.5 s, no expanding ring.
    private static let twinkleModifier = """
    #pragma arguments
    float u_currentTime;
    float4 u_regionGlow;
    float3 u_tintColor;
    float  u_tintStrength;
    float3 u_tapCenter;
    float  u_tapStart;

    #pragma body
    float phase = _geometry.color.a;
    float speed = 0.8 + 2.6 * fract(phase * 7.31);
    float tw    = 0.58 + 0.42 * sin(u_currentTime * speed + phase * 25.1327);
    float3 col  = _geometry.color.rgb * tw;

    // Theme palette tint — muted at rest, brighter when a region is active.
    // u_tintStrength defaults to 0 so hosts that never call setStarTint are unchanged.
    col = mix(col, u_tintColor, u_tintStrength);

    float4 world = scn_node.modelTransform * float4(_geometry.position.xyz, 1.0);
    if (u_regionGlow.w > 0.001) {
        float d = distance(world.xyz, u_regionGlow.xyz);
        float g = 1.0 - smoothstep(u_regionGlow.w * 0.5, u_regionGlow.w * 1.3, d);
        // Ember tint + slow pulse matching the skin shader's 2.4 rad/s pulse.
        float pulse = 0.7 + 0.3 * sin(u_currentTime * 2.4 + phase * 3.0);
        col = mix(col, float3(1.0, 0.42, 0.30), g * 0.55);
        col += float3(1.0, 0.30, 0.22) * g * pulse * 0.6;
    }

    // Soft tap bloom: fixed-radius glow that rises fast and fades (~0.5 s).
    if (u_tapStart > 0.0) {
        float te  = u_currentTime - u_tapStart;
        float d   = distance(world.xyz, u_tapCenter);
        float g   = 1.0 - smoothstep(0.0, 0.13, d);
        float env = smoothstep(0.0, 0.06, te) * (1.0 - smoothstep(0.18, 0.52, te));
        col += float3(1.0, 0.92, 0.78) * g * env * 0.85;
    }

    _geometry.color = float4(col, 1.0);
    """

    /// Builds the point-cloud geometry from mesh source-space vertex positions,
    /// subsampled to roughly `targetCount` stars. The Time screen's backdrop is
    /// near-black in both appearances, and 18k points keep the silhouette
    /// legible at these small point sizes.
    static func make(positions: [SIMD3<Float>], targetCount: Int = 18000) -> SCNGeometry {
        guard !positions.isEmpty else { return SCNGeometry() }

        // Even fractional-stride subsample: deterministic, order-preserving,
        // and lands within one star of the target for any mesh density.
        let step = max(1.0, Float(positions.count) / Float(targetCount))

        var xyz = [Float]()
        var rgba = [Float]()
        var tierIndices: [[UInt32]] = Array(repeating: [], count: tiers.count)
        xyz.reserveCapacity(targetCount * 3)
        rgba.reserveCapacity(targetCount * 4)

        var cursor: Float = 0
        var star: UInt32 = 0
        while Int(cursor) < positions.count {
            let p = positions[Int(cursor)]
            cursor += step

            xyz.append(p.x); xyz.append(p.y); xyz.append(p.z)

            let h = hash(star)
            let color = starColor(h)
            rgba.append(color.x); rgba.append(color.y); rgba.append(color.z)
            rgba.append(rand(h, 3)) // twinkle phase, consumed by the shader

            let roll = rand(h, 4)
            let tier = tiers.firstIndex { roll < $0.threshold } ?? 0
            tierIndices[tier].append(star)
            star += 1
        }

        let count = xyz.count / 3
        let posSource = SCNGeometrySource(
            data: xyz.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .vertex,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 3
        )
        let colorSource = SCNGeometrySource(
            data: rgba.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .color,
            vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.size * 4
        )

        let elements: [SCNGeometryElement] = zip(tiers, tierIndices).compactMap { tier, indices in
            guard !indices.isEmpty else { return nil }
            let element = SCNGeometryElement(indices: indices, primitiveType: .point)
            element.pointSize = tier.pointSize
            element.minimumPointScreenSpaceRadius = tier.minRadius
            element.maximumPointScreenSpaceRadius = tier.maxRadius
            return element
        }

        let geometry = SCNGeometry(sources: [posSource, colorSource], elements: elements)

        let material = SCNMaterial()
        material.lightingModel = .constant       // self-illuminated
        material.blendMode = .add                // additive = glow
        material.writesToDepthBuffer = false     // stars layer, never self-occlude
        material.isDoubleSided = true
        material.shaderModifiers = [.geometry: twinkleModifier]
        geometry.materials = [material]          // shared across all tier elements
        return geometry
    }

    /// Reads source-space positions out of a vertex source (same layout walk as
    /// `ZoneMap`, which keeps its copy private).
    static func readPositions(_ src: SCNGeometrySource) -> [SIMD3<Float>] {
        var out = [SIMD3<Float>]()
        out.reserveCapacity(src.vectorCount)
        let stride = src.dataStride, offset = src.dataOffset, data = src.data
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            for i in 0..<src.vectorCount {
                let b = offset + i * stride
                guard b + 12 <= data.count else { continue }
                out.append(SIMD3<Float>(ptr.loadUnaligned(fromByteOffset: b, as: Float.self),
                                        ptr.loadUnaligned(fromByteOffset: b + 4, as: Float.self),
                                        ptr.loadUnaligned(fromByteOffset: b + 8, as: Float.self)))
            }
        }
        return out
    }

    // MARK: - Deterministic per-star randomness

    private static func starColor(_ h: UInt32) -> SIMD3<Float> {
        StarPalette.fieldColor(pick: rand(h, 0), brightness: 0.55 + 0.45 * rand(h, 1))
    }

    private static func hash(_ x: UInt32) -> UInt32 { SplitMix32.hash(x) }

    private static func rand(_ h: UInt32, _ lane: UInt32) -> Float { SplitMix32.rand(h, lane) }
}
