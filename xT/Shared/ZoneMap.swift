import Foundation
import SceneKit
import simd

/// Resolves a point on the body mesh to a zone label, using the map baked by
/// `tools/zonebake`.
///
/// ## What this replaces
///
/// `ZoneCentroidStore.nearestLabel(to:within:)` scanned 49 centroids for the nearest one in
/// 3-D Euclidean space with a 0.15 cutoff. Measured on the neutral mesh, that left 57% of the
/// surface resolving to no zone at all, made `Inner Right Thigh` unreachable, and let the two
/// wrist zones claim 14% of the whole body — a hand is ~4 cm from the thigh through the air
/// while being most of a metre away along the skin. Re-running the audit with *correctly
/// placed* centroids still left 43% dead space, which is why the mechanism had to change and
/// not just the data.
///
/// Here the answer is looked up rather than guessed: every mesh vertex carries a baked zone
/// ID, and a tap resolves to the nearest vertex.
///
/// ## Coordinate space
///
/// The grid is built in the mesh's **source space** — the raw `SCNGeometrySource` frame, which
/// is still Blender's Z-up. That is deliberate: `SCNHitTestResult.localCoordinates` is
/// expressed in exactly this space, so a tap needs no transform at all and cannot drift out of
/// sync with however the wrapper node happens to be posed. See `BodyTransform` for why there
/// are three spaces rather than two.
@MainActor
final class ZoneMap {

    /// Outcome of resolving a point. The distinction matters: the old code returned `nil`
    /// both for "the ray missed the body" and "this spot has no zone", which is why taps on
    /// the head or a hand were silently swallowed instead of being explained to the user.
    enum Resolution: Equatable {
        case zone(String)
        case noZone
    }

    private(set) var bodyType: BodyType
    private let zoneIDs: [UInt16]
    private let labels: [String]
    private let radii: [Float]
    private let centroids: [SIMD3<Float>]
    private let normals: [SIMD3<Float>]

    /// Vertex positions in source space, and a uniform grid over them.
    private let positions: [SIMD3<Float>]
    private let cellSize: Float
    private let gridOrigin: SIMD3<Float>
    private var grid: [Int64: [Int32]] = [:]

    // MARK: - Loading

    enum LoadError: Error, CustomStringConvertible {
        case missingResource(String)
        case decodeFailed(String)
        case schemaVersion(Int)
        case corruptIDs(String)
        case vertexCountMismatch(expected: Int, actual: Int)

        var description: String {
            switch self {
            case .missingResource(let n): return "zone map resource \(n).json not found in bundle"
            case .decodeFailed(let n):    return "could not decode \(n).json"
            case .schemaVersion(let v):   return "unsupported zone map schema version \(v)"
            case .corruptIDs(let n):      return "\(n).json vertex ID blob length disagrees with vertexCount"
            case .vertexCountMismatch(let e, let a):
                return "zone map baked for \(e) vertices but mesh has \(a) — the map and the asset are out of sync"
            }
        }
    }

    /// Loads the baked map for `bodyType` and indexes it against `meshNode`'s geometry.
    ///
    /// Throws rather than degrading. A vertex-count mismatch means the map was baked against a
    /// different version of the asset, and every label it produced would be wrong — failing
    /// loudly is the only safe response, because silently mislabelling injection sites is
    /// exactly the bug being fixed.
    init(bodyType: BodyType, meshNode: SCNNode) throws {
        let name = ZoneMapFile.resourceName(for: bodyType.rawValue)
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Models")
            ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            throw LoadError.missingResource(name)
        }
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ZoneMapFile.self, from: data) else {
            throw LoadError.decodeFailed(name)
        }
        guard file.schemaVersion == ZoneMapFile.currentSchemaVersion else {
            throw LoadError.schemaVersion(file.schemaVersion)
        }
        guard let ids = file.decodeZoneIDs() else {
            throw LoadError.corruptIDs(name)
        }

        guard let vertexSource = meshNode.geometry?.sources(for: .vertex).first else {
            throw LoadError.vertexCountMismatch(expected: file.vertexCount, actual: 0)
        }
        let positions = Self.readPositions(vertexSource)
        guard positions.count == file.vertexCount else {
            throw LoadError.vertexCountMismatch(expected: file.vertexCount, actual: positions.count)
        }

        self.bodyType = bodyType
        self.zoneIDs = ids
        self.labels = file.zones.map(\.label)
        self.radii = file.zones.map(\.radius)
        self.centroids = file.zones.map { SIMD3<Float>($0.centroid[0], $0.centroid[1], $0.centroid[2]) }
        self.normals = file.zones.map { SIMD3<Float>($0.normal[0], $0.normal[1], $0.normal[2]) }
        self.positions = positions

        // Cell size is a compromise: large enough that most queries inspect one ring of
        // cells, small enough that a cell holds few vertices. The mesh's mean edge length is
        // ~8 mm but varies by more than 4× between the face and the thigh, so 2 cm keeps the
        // dense regions from producing huge buckets.
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        for p in positions { lo = simd_min(lo, p) }
        self.cellSize = 0.02
        self.gridOrigin = lo

        for (i, p) in positions.enumerated() {
            grid[Self.key(for: p, origin: lo, cell: cellSize), default: []].append(Int32(i))
        }
    }

    // MARK: - Resolution

    /// Resolves a point in the mesh's source space (i.e. `SCNHitTestResult.localCoordinates`).
    func resolve(localPoint p: SIMD3<Float>) -> Resolution {
        guard let vertex = nearestVertex(to: p) else { return .noZone }
        let id = zoneIDs[vertex]
        guard id != ZoneMapFile.noZoneID, Int(id) < labels.count else { return .noZone }
        return .zone(labels[Int(id)])
    }

    /// Nearest vertex by expanding ring search over the grid.
    ///
    /// Rings expand until a hit is found and then one ring further, because a vertex in the
    /// next ring out can still be closer than one found diagonally in the current ring.
    private func nearestVertex(to p: SIMD3<Float>) -> Int? {
        let base = Self.cellIndex(for: p, origin: gridOrigin, cell: cellSize)
        var best = -1
        var bestDist = Float.greatestFiniteMagnitude

        var radius = 0
        var foundAtRadius = -1
        while radius <= 8 {
            for dx in -radius...radius {
                for dy in -radius...radius {
                    for dz in -radius...radius {
                        // Only the shell of this ring; the interior was covered already.
                        if radius > 0 && abs(dx) != radius && abs(dy) != radius && abs(dz) != radius { continue }
                        let k = Self.packed(base.x + Int32(dx), base.y + Int32(dy), base.z + Int32(dz))
                        guard let bucket = grid[k] else { continue }
                        for vi in bucket {
                            let d = simd_distance_squared(positions[Int(vi)], p)
                            if d < bestDist { bestDist = d; best = Int(vi) }
                        }
                    }
                }
            }
            if best >= 0 {
                if foundAtRadius < 0 { foundAtRadius = radius }
                if radius > foundAtRadius { break }
            }
            radius += 1
        }
        return best >= 0 ? best : nil
    }

    // MARK: - Zone metadata

    var allLabels: [String] { labels }

    func index(of label: String) -> Int? { labels.firstIndex(of: label) }

    /// Baked patch radius in world units — derived from the zone's actual extent, unlike the
    /// old `0.07 + 0.02 × doseCount` guess which was unrelated to the zone's real size.
    func radius(for label: String) -> Float? {
        index(of: label).map { radii[$0] }
    }

    func centroid(for label: String) -> SIMD3<Float>? {
        index(of: label).map { centroids[$0] }
    }

    func normal(for label: String) -> SIMD3<Float>? {
        index(of: label).map { normals[$0] }
    }

    // MARK: - Grid helpers

    private static func cellIndex(for p: SIMD3<Float>, origin: SIMD3<Float>, cell: Float) -> SIMD3<Int32> {
        let r = (p - origin) / cell
        return SIMD3<Int32>(Int32(r.x.rounded(.down)), Int32(r.y.rounded(.down)), Int32(r.z.rounded(.down)))
    }

    private static func key(for p: SIMD3<Float>, origin: SIMD3<Float>, cell: Float) -> Int64 {
        let c = cellIndex(for: p, origin: origin, cell: cell)
        return packed(c.x, c.y, c.z)
    }

    /// Packs a cell coordinate into one key. ±1M cells per axis is far beyond what a 1.5 m
    /// body at 2 cm resolution can reach.
    private static func packed(_ x: Int32, _ y: Int32, _ z: Int32) -> Int64 {
        (Int64(x) &* 2_097_152 &+ Int64(y)) &* 2_097_152 &+ Int64(z)
    }

    private static func readPositions(_ src: SCNGeometrySource) -> [SIMD3<Float>] {
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
}
