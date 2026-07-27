import Foundation
import SceneKit
import simd

/// A shipped `body_*.usdz` loaded with everything the bake needs: vertex positions in both
/// spaces, per-vertex outward normals, edge adjacency, and the eyeball vertex mask.
///
/// ## Where each piece comes from, and why
///
/// Positions and normals come from SceneKit, because that is exactly what the app sees at
/// runtime — reading them any other way risks baking a map against different data than the
/// app resolves against.
///
/// Topology comes from `usdcat --flatten`, because SceneKit does *not* expose usable
/// topology for these meshes. Their `SCNGeometryElement`s are `.polygon` primitives whose
/// indices address face-varying corners (up to 57591) rather than the 14444 points, so
/// edges cannot be recovered from them. The USD `faceVertexCounts` / `faceVertexIndices`
/// arrays index the point array directly and are authoritative.
struct BodyMesh {

    let bodyType: String
    let transform: BodyTransform

    /// Vertex positions in *source* space — the raw `SCNGeometrySource` frame, which is
    /// still Blender's Z-up. This is the space `SCNHitTestResult.localCoordinates` reports,
    /// so the runtime lookup grid is built here and needs no conversion at tap time.
    let sourcePositions: [SIMD3<Float>]

    /// The same vertices in world space: upright, facing +Z, +X is the body's anatomical
    /// left. Seeds are authored in this frame because it is the only one a human can reason
    /// about. Geodesic distances are measured here too, since only world space is uniformly
    /// scaled to the 1.5 m target height.
    let worldPositions: [SIMD3<Float>]

    /// Outward unit normals per vertex, world space. USD stores normals face-varying (one
    /// per corner), so these are the corner normals averaged onto their shared vertex.
    let worldNormals: [SIMD3<Float>]

    /// Undirected adjacency from quad edges. Index-parallel to the vertex arrays.
    let neighbors: [[Int32]]

    /// The faces triangulated as a flat index triple list. Only the preview renderer needs
    /// this — the shipped geometry's own elements are face-varying `.polygon` primitives and
    /// cannot be reused for a vertex-coloured render.
    let faceTriangles: [Int32]

    /// Vertices belonging to the `Eye_brown` material subset. Never clinical surface.
    let eyeVertices: Set<Int>

    var vertexCount: Int { sourcePositions.count }

    // MARK: - Loading

    enum LoadError: Error, CustomStringConvertible {
        case sceneLoad(String)
        case noGeometry(String)
        case usdcat(String)
        case parse(String)
        case mismatch(String)

        var description: String {
            switch self {
            case .sceneLoad(let s):  return "could not load scene: \(s)"
            case .noGeometry(let s): return "no body geometry found: \(s)"
            case .usdcat(let s):     return "usdcat failed: \(s)"
            case .parse(let s):      return "could not parse USD: \(s)"
            case .mismatch(let s):   return "data mismatch: \(s)"
            }
        }
    }

    static func load(usdzURL: URL, bodyType: String) throws -> BodyMesh {
        guard let modelScene = try? SCNScene(url: usdzURL, options: [.checkConsistency: true,
                                                                     .flattenScene: false]) else {
            throw LoadError.sceneLoad(usdzURL.lastPathComponent)
        }

        // Mirror the app's load path exactly: wrap the USDZ's children, then place the
        // wrapper with the shared transform.
        let wrapper = SCNNode()
        for child in modelScene.rootNode.childNodes { wrapper.addChildNode(child) }
        let scene = SCNScene()
        scene.rootNode.addChildNode(wrapper)

        // Detect how this asset is stored rather than assuming. Wrapper space is reached by
        // each geometry node's own transform, which folds in the USDZ's Z-up→Y-up rotation.
        var wrapperSpace: [SIMD3<Float>] = []
        wrapper.enumerateChildNodes { node, _ in
            guard let g = node.geometry, let v = g.sources(for: .vertex).first else { return }
            let M = simd_float4x4(node.worldTransform)
            for p in readVec3(v) {
                let r = M * SIMD4<Float>(p, 1)
                wrapperSpace.append(SIMD3<Float>(r.x, r.y, r.z))
            }
        }
        guard let orientation = BodyOrientation(wrapperSpaceVertices: wrapperSpace) else {
            throw LoadError.noGeometry("could not determine orientation of \(usdzURL.lastPathComponent)")
        }

        let bb = wrapper.boundingBox
        guard let transform = BodyTransform(boundingBox: (min: bb.min, max: bb.max),
                                            orientation: orientation) else {
            throw LoadError.noGeometry("degenerate bounding box")
        }
        transform.apply(to: wrapper)

        // Find the single skinned body mesh node.
        var meshNode: SCNNode?
        var best = 0
        wrapper.enumerateChildNodes { node, _ in
            guard let geo = node.geometry,
                  let vsrc = geo.sources(for: .vertex).first else { return }
            if vsrc.vectorCount > best { best = vsrc.vectorCount; meshNode = node }
        }
        guard let meshNode,
              let geometry = meshNode.geometry,
              let vertexSource = geometry.sources(for: .vertex).first else {
            throw LoadError.noGeometry(usdzURL.lastPathComponent)
        }

        let sourcePositions = readVec3(vertexSource)
        let cornerNormals = geometry.sources(for: .normal).first.map { readVec3($0) } ?? []

        // source → world in one matrix: the geometry node's worldTransform already folds in
        // the USDZ's internal Z-up→Y-up rotation *and* the wrapper transform applied above.
        let sourceToWorld = simd_float4x4(meshNode.worldTransform)
        let normalMatrix = simd_float3x3(
            SIMD3<Float>(sourceToWorld.columns.0.x, sourceToWorld.columns.0.y, sourceToWorld.columns.0.z),
            SIMD3<Float>(sourceToWorld.columns.1.x, sourceToWorld.columns.1.y, sourceToWorld.columns.1.z),
            SIMD3<Float>(sourceToWorld.columns.2.x, sourceToWorld.columns.2.y, sourceToWorld.columns.2.z)
        ).inverse.transpose

        let worldPositions = sourcePositions.map { p -> SIMD3<Float> in
            let r = sourceToWorld * SIMD4<Float>(p, 1)
            return SIMD3<Float>(r.x, r.y, r.z)
        }

        // Topology from USD.
        let usd = try USDTopology.extract(usdzURL: usdzURL)
        guard usd.pointCount == sourcePositions.count else {
            throw LoadError.mismatch("USD points \(usd.pointCount) != SceneKit vertices \(sourcePositions.count)")
        }
        guard usd.faceVertexIndices.count == cornerNormals.count || cornerNormals.isEmpty else {
            throw LoadError.mismatch("USD corners \(usd.faceVertexIndices.count) != normals \(cornerNormals.count)")
        }

        // Average face-varying corner normals onto their shared vertex.
        var accum = [SIMD3<Float>](repeating: .zero, count: sourcePositions.count)
        if !cornerNormals.isEmpty {
            for (corner, vertex) in usd.faceVertexIndices.enumerated() {
                let v = Int(vertex)
                guard v >= 0 && v < accum.count else { continue }
                accum[v] += cornerNormals[corner]
            }
        }
        let worldNormals: [SIMD3<Float>] = accum.map { n in
            let w = normalMatrix * n
            let len = simd_length(w)
            return len > 1e-9 ? w / len : SIMD3<Float>(0, 0, 1)
        }

        // Edges from face rings, and a triangle fan per face for the preview renderer.
        var neighborSets = [Set<Int32>](repeating: [], count: sourcePositions.count)
        var faceTriangles: [Int32] = []
        faceTriangles.reserveCapacity(usd.faceVertexCounts.count * 6)
        var cursor = 0
        for count in usd.faceVertexCounts {
            let n = Int(count)
            guard n >= 3, cursor + n <= usd.faceVertexIndices.count else { cursor += n; continue }
            for k in 0..<n {
                let a = usd.faceVertexIndices[cursor + k]
                let b = usd.faceVertexIndices[cursor + (k + 1) % n]
                guard a >= 0, Int(a) < neighborSets.count, b >= 0, Int(b) < neighborSets.count, a != b else { continue }
                neighborSets[Int(a)].insert(b)
                neighborSets[Int(b)].insert(a)
            }
            for k in 1..<(n - 1) {
                faceTriangles.append(usd.faceVertexIndices[cursor])
                faceTriangles.append(usd.faceVertexIndices[cursor + k])
                faceTriangles.append(usd.faceVertexIndices[cursor + k + 1])
            }
            cursor += n
        }
        // Sorted, not just converted. Swift randomizes `Set` iteration order per process, so
        // an unsorted adjacency list makes Dijkstra's tie-breaking differ between runs: two
        // bakes of the same asset produced maps differing in a handful of boundary vertices.
        // The baked maps are checked-in artifacts, so they have to be reproducible.
        let neighbors = neighborSets.map { $0.sorted() }

        // Eye vertices, from the material subset's face indices.
        var eyeVertices = Set<Int>()
        if let eyeFaces = usd.subsetFaces["Eye_brown"] {
            var faceStart = [Int](repeating: 0, count: usd.faceVertexCounts.count)
            var c = 0
            for (i, n) in usd.faceVertexCounts.enumerated() { faceStart[i] = c; c += Int(n) }
            for face in eyeFaces {
                let f = Int(face)
                guard f >= 0, f < faceStart.count else { continue }
                let n = Int(usd.faceVertexCounts[f])
                for k in 0..<n where faceStart[f] + k < usd.faceVertexIndices.count {
                    eyeVertices.insert(Int(usd.faceVertexIndices[faceStart[f] + k]))
                }
            }
        }

        return BodyMesh(bodyType: bodyType,
                        transform: transform,
                        sourcePositions: sourcePositions,
                        worldPositions: worldPositions,
                        worldNormals: worldNormals,
                        neighbors: neighbors,
                        faceTriangles: faceTriangles,
                        eyeVertices: eyeVertices)
    }

    // MARK: - Helpers

    private static func readVec3(_ src: SCNGeometrySource) -> [SIMD3<Float>] {
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

    /// World-space bounding box.
    var worldBounds: (min: SIMD3<Float>, max: SIMD3<Float>) {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in worldPositions { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        return (lo, hi)
    }

    /// Total surface area in m², summed over the triangulated faces.
    var surfaceArea: Float {
        var total: Float = 0
        var i = 0
        while i + 2 < faceTriangles.count {
            let a = worldPositions[Int(faceTriangles[i])]
            let b = worldPositions[Int(faceTriangles[i + 1])]
            let c = worldPositions[Int(faceTriangles[i + 2])]
            total += simd_length(simd_cross(b - a, c - a)) * 0.5
            i += 3
        }
        return total
    }

    /// Per-vertex surface area: a third of each incident triangle's area.
    ///
    /// Vertex *counts* are a misleading measure of coverage on this mesh. MakeHuman topology
    /// is far denser on the head, hands and feet than on the torso and limbs, so a zone that
    /// covers a large patch of thigh holds fewer vertices than a thumbnail-sized patch of
    /// face. Everything reported as "coverage" is therefore area-weighted.
    var vertexAreas: [Float] {
        var areas = [Float](repeating: 0, count: vertexCount)
        var i = 0
        while i + 2 < faceTriangles.count {
            let ia = Int(faceTriangles[i]), ib = Int(faceTriangles[i + 1]), ic = Int(faceTriangles[i + 2])
            let a = worldPositions[ia], b = worldPositions[ib], c = worldPositions[ic]
            let third = simd_length(simd_cross(b - a, c - a)) / 6
            areas[ia] += third; areas[ib] += third; areas[ic] += third
            i += 3
        }
        return areas
    }

    /// Mean edge length within a world-space height band, for sizing geodesic extents.
    func meanEdgeLength(yRange: ClosedRange<Float>) -> (mean: Float, edges: Int) {
        var total: Float = 0
        var count = 0
        for (i, ns) in neighbors.enumerated() {
            guard yRange.contains(worldPositions[i].y) else { continue }
            for j in ns where Int(j) > i {
                total += simd_distance(worldPositions[i], worldPositions[Int(j)])
                count += 1
            }
        }
        return (count > 0 ? total / Float(count) : 0, count)
    }

    /// Number of connected components in the adjacency graph. The body should be one
    /// component plus the eyeballs; many components means the topology parse went wrong.
    func connectedComponentCount() -> Int {
        var seen = [Bool](repeating: false, count: vertexCount)
        var components = 0
        var stack: [Int] = []
        for start in 0..<vertexCount where !seen[start] {
            components += 1
            seen[start] = true
            stack.append(start)
            while let v = stack.popLast() {
                for u in neighbors[v] where !seen[Int(u)] {
                    seen[Int(u)] = true
                    stack.append(Int(u))
                }
            }
        }
        return components
    }

    /// Mean edge length in world units — the natural scale for judging boundary precision.
    var meanEdgeLength: Float {
        var total: Float = 0
        var count = 0
        for (i, ns) in neighbors.enumerated() {
            for j in ns where Int(j) > i {
                total += simd_distance(worldPositions[i], worldPositions[Int(j)])
                count += 1
            }
        }
        return count > 0 ? total / Float(count) : 0
    }
}
