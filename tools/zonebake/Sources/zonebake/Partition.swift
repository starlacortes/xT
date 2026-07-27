import Foundation
import simd

/// Partitions the mesh surface into zones by geodesic distance.
///
/// ## Why geodesic and not Euclidean
///
/// This is the change that actually fixes the mislabelling. Straight-line distance treats
/// any two points that are close *in space* as close, but skin is a surface: with the arms
/// hanging at the sides, a hand sits ~4 cm from the thigh through the air while being most
/// of a metre away along the body. The old nearest-centroid scan therefore let the two wrist
/// zones claim 14% of the entire mesh, including thigh surface.
///
/// Dijkstra over mesh edges measures distance the way a finger travels — around the surface.
/// Because arm and torso skin are only connected via the shoulder, a wrist seed cannot reach
/// the thigh no matter how close the two are in space. It also makes the result
/// pose-independent: re-posing the arms changes spatial distances but not surface distances.
enum Partition {

    struct Result {
        /// Zone ID per vertex, `ZoneMapFile.noZoneID` where unassigned.
        let zoneIDs: [UInt16]
        /// Geodesic distance to the owning seed, `.infinity` where unassigned.
        let distances: [Float]
        /// Vertex each seed snapped to, parallel to the seed array.
        let seedVertices: [Int]
        /// Seeds whose snap target could not be found at all.
        let unsnappedSeeds: [String]
    }

    /// Multi-source Dijkstra with a per-source reach cap.
    ///
    /// Each seed grows outward until it either meets another zone's frontier (nearest seed
    /// wins, so boundaries land midway along the surface) or exceeds its own `extent`.
    /// Everything still unclaimed is non-clinical surface.
    static func run(mesh: BodyMesh, seeds: [ZoneSeed]) -> Result {
        let n = mesh.vertexCount
        var zoneIDs = [UInt16](repeating: ZoneMapFile.noZoneID, count: n)
        var distances = [Float](repeating: .infinity, count: n)
        var settled = [Bool](repeating: false, count: n)

        // Snap each seed to the nearest eligible surface vertex. Eyeballs are excluded:
        // they are inside the head, so they would otherwise capture face-adjacent seeds.
        var seedVertices: [Int] = []
        var unsnapped: [String] = []
        for seed in seeds {
            let target = seed.position
            var bestIndex = -1
            var bestDist = Float.greatestFiniteMagnitude
            for i in 0..<n where !mesh.eyeVertices.contains(i) {
                let d = simd_distance_squared(mesh.worldPositions[i], target)
                if d < bestDist { bestDist = d; bestIndex = i }
            }
            if bestIndex < 0 {
                unsnapped.append(seed.label)
                seedVertices.append(-1)
            } else {
                seedVertices.append(bestIndex)
            }
        }

        var heap = MinHeap()
        for (zoneIndex, vertex) in seedVertices.enumerated() where vertex >= 0 {
            // If two seeds snap to the same vertex the lower zone index wins; the report
            // flags the loser as empty rather than letting it silently alias.
            if distances[vertex] > 0 {
                distances[vertex] = 0
                zoneIDs[vertex] = UInt16(zoneIndex)
                heap.push(dist: 0, vertex: Int32(vertex), zone: UInt16(zoneIndex))
            }
        }

        while let top = heap.pop() {
            let v = Int(top.vertex)
            if settled[v] { continue }
            // A stale heap entry (superseded by a shorter path) is skipped by comparing
            // against the recorded best.
            if top.dist > distances[v] { continue }
            settled[v] = true
            let zone = top.zone
            let extent = seeds[Int(zone)].extent

            for neighborRaw in mesh.neighbors[v] {
                let u = Int(neighborRaw)
                guard u >= 0, u < n, !settled[u], !mesh.eyeVertices.contains(u) else { continue }
                let step = simd_distance(mesh.worldPositions[v], mesh.worldPositions[u])
                let nd = top.dist + step
                guard nd <= extent, nd < distances[u] else { continue }
                distances[u] = nd
                zoneIDs[u] = zone
                heap.push(dist: nd, vertex: Int32(u), zone: zone)
            }
        }

        // Eyeballs are never clinical surface regardless of what the growth did.
        for i in mesh.eyeVertices where i < n {
            zoneIDs[i] = ZoneMapFile.noZoneID
            distances[i] = .infinity
        }

        return Result(zoneIDs: zoneIDs,
                      distances: distances,
                      seedVertices: seedVertices,
                      unsnappedSeeds: unsnapped)
    }

    // MARK: - Derived per-zone data

    struct ZoneStats {
        let label: String
        let vertices: [Int]
        /// Patch area in m². The meaningful measure of a zone's size, given how uneven the
        /// mesh tessellation is.
        let area: Float
        /// Patch centroid pulled onto the surface (nearest patch vertex to the mean).
        let centroid: SIMD3<Float>
        let normal: SIMD3<Float>
        /// 90th-percentile Euclidean distance from the centroid. Measured from the patch's
        /// own extent, replacing the old `0.07 + 0.02 × doseCount` guess which had nothing
        /// to do with how big the zone actually is.
        let radius: Float
        /// Fraction of the patch's area lying on the opposite side of the midline from its
        /// own centroid.
        ///
        /// A strict "touches both sides" test is too strict to be useful: left and right
        /// glutes genuinely meet at the gluteal cleft, so a patch reaching a centimetre past
        /// x = 0 is correct anatomy, not a bug. What matters is a zone claiming a *substantial*
        /// share of the wrong side.
        let wrongSideFraction: Float
        /// Fraction of patch normals agreeing with the centroid normal — a low value means
        /// the patch has wrapped around a limb.
        let normalAgreement: Float
    }

    static func stats(mesh: BodyMesh, seeds: [ZoneSeed], result: Result) -> [ZoneStats] {
        var buckets = [[Int]](repeating: [], count: seeds.count)
        for (v, id) in result.zoneIDs.enumerated() where id != ZoneMapFile.noZoneID {
            buckets[Int(id)].append(v)
        }
        let vertexAreas = mesh.vertexAreas

        return seeds.enumerated().map { zoneIndex, seed in
            let verts = buckets[zoneIndex]
            guard !verts.isEmpty else {
                return ZoneStats(label: seed.label, vertices: [], area: 0, centroid: .zero,
                                 normal: SIMD3<Float>(0, 0, 1), radius: 0,
                                 wrongSideFraction: 0, normalAgreement: 0)
            }

            var mean = SIMD3<Float>(repeating: 0)
            for v in verts { mean += mesh.worldPositions[v] }
            mean /= Float(verts.count)

            // Snap the mean onto the surface so the glow sits on skin rather than inside
            // the body — the mean of a curved patch is always slightly submerged.
            var centroidVertex = verts[0]
            var bestDist = Float.greatestFiniteMagnitude
            for v in verts {
                let d = simd_distance_squared(mesh.worldPositions[v], mean)
                if d < bestDist { bestDist = d; centroidVertex = v }
            }
            let centroid = mesh.worldPositions[centroidVertex]

            var normalAccum = SIMD3<Float>(repeating: 0)
            for v in verts { normalAccum += mesh.worldNormals[v] }
            let normal = simd_length(normalAccum) > 1e-9
                ? simd_normalize(normalAccum)
                : mesh.worldNormals[centroidVertex]

            var radii = verts.map { simd_distance(mesh.worldPositions[$0], centroid) }
            radii.sort()
            let radius = radii[min(radii.count - 1, Int(Float(radii.count) * 0.9))]

            // Which side does this zone belong to? Taken from the centroid, so it needs no
            // label parsing.
            let ownSide: Float = centroid.x >= 0 ? 1 : -1
            var wrongSideArea: Float = 0
            var patchArea: Float = 0
            for v in verts {
                let a = vertexAreas[v]
                patchArea += a
                if mesh.worldPositions[v].x * ownSide < 0 { wrongSideArea += a }
            }
            let wrongSideFraction = patchArea > 0 ? wrongSideArea / patchArea : 0

            let agreeing = verts.reduce(into: 0) { acc, v in
                if simd_dot(mesh.worldNormals[v], normal) > 0 { acc += 1 }
            }

            return ZoneStats(label: seed.label,
                             vertices: verts,
                             area: verts.reduce(Float(0)) { $0 + vertexAreas[$1] },
                             centroid: centroid,
                             normal: normal,
                             radius: radius,
                             wrongSideFraction: wrongSideFraction,
                             normalAgreement: Float(agreeing) / Float(verts.count))
        }
    }
}

/// Binary min-heap keyed on distance. Small and purpose-built; the alternative was pulling
/// in a dependency for one priority queue.
private struct MinHeap {
    struct Entry { var dist: Float; var vertex: Int32; var zone: UInt16 }
    private var items: [Entry] = []

    var isEmpty: Bool { items.isEmpty }

    mutating func push(dist: Float, vertex: Int32, zone: UInt16) {
        items.append(Entry(dist: dist, vertex: vertex, zone: zone))
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard items[i].dist < items[parent].dist else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func pop() -> Entry? {
        guard !items.isEmpty else { return nil }
        let top = items[0]
        let last = items.removeLast()
        if !items.isEmpty {
            items[0] = last
            var i = 0
            while true {
                let l = 2 * i + 1, r = 2 * i + 2
                var smallest = i
                if l < items.count && items[l].dist < items[smallest].dist { smallest = l }
                if r < items.count && items[r].dist < items[smallest].dist { smallest = r }
                if smallest == i { break }
                items.swapAt(i, smallest)
                i = smallest
            }
        }
        return top
    }
}
