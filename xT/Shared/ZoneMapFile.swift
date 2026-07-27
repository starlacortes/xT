import Foundation
import simd

/// On-disk schema for a baked zone map: `zone_map_<bodyType>.json`.
///
/// Written by `tools/zonebake`, read by `ZoneMap` at runtime. Both sides compile this
/// same file — the bake tool symlinks it — so the writer and reader cannot drift apart.
///
/// ## Why per-vertex IDs
///
/// The previous design resolved a tap by scanning 49 centroids for the nearest one in 3-D
/// Euclidean space. That cannot partition a body surface: 57% of the mesh fell outside every
/// centroid's cutoff and the wrist zones claimed 14% of the whole body, because a hand is
/// ~4 cm from the thigh *through space* while being far away *along the skin*. Baking one
/// zone ID per vertex replaces the guess with a lookup.
///
/// ## Vertex indices are a stable key
///
/// `vertexZoneIDs[i]` corresponds to vertex `i` of the mesh's `SCNGeometrySource(.vertex)`,
/// which is verified to be bit-identical to the USD `points` array (checked for all three
/// body types). Face indices would *not* be a stable key — SceneKit expands the USD quads
/// into face-varying corners (14398 quads → 57592 corners) and that expansion is an
/// implementation detail, so anything keyed on it could shift between OS versions.
struct ZoneMapFile: Codable {

    /// Bumped whenever the meaning of any field changes. `ZoneMap` refuses to load a file
    /// whose version it does not recognise, rather than silently mislabelling taps.
    static let currentSchemaVersion = 1

    /// Sentinel stored in `vertexZoneIDs` for surface that belongs to no clinical zone —
    /// head, hands, feet, below the knee, and the eyeballs. Distinct from "no hit at all",
    /// which is the absence of a raycast intersection.
    static let noZoneID: UInt16 = 0xFFFF

    struct Zone: Codable {
        /// Must stay byte-identical to the persisted `InjectionSite.zoneLabel`, which is the
        /// migration key for dose history and avoid-zone settings.
        let label: String
        /// Patch centroid in world space, projected onto the surface.
        let centroid: [Float]
        /// Outward surface normal at the centroid, world space, unit length.
        let normal: [Float]
        /// Radius measured from the patch's own extent — not the old
        /// `0.07 + 0.02 × doseCount` guess, which was unrelated to the zone's real size.
        let radius: Float
        /// Number of mesh vertices assigned to this zone. Zero means the zone is
        /// unreachable, which the bake report treats as a failure.
        let vertexCount: Int
    }

    let schemaVersion: Int
    let bodyType: String
    /// Expected vertex count of the mesh this map was baked against. `ZoneMap` compares this
    /// against the loaded geometry and fails loudly on mismatch — a silent mismatch would
    /// scramble every label.
    let vertexCount: Int
    /// Index in this array *is* the zone ID stored in `vertexZoneIDs`.
    let zones: [Zone]
    /// `UInt16` little-endian, one per vertex. `Data` round-trips as base64 in JSON.
    let vertexZoneIDs: Data

    // MARK: - Accessors

    /// Decodes the packed ID blob. Returns nil if the blob length disagrees with
    /// `vertexCount`, which means the file is corrupt.
    func decodeZoneIDs() -> [UInt16]? {
        guard vertexZoneIDs.count == vertexCount * 2 else { return nil }
        var ids = [UInt16](repeating: 0, count: vertexCount)
        for i in 0..<vertexCount {
            let lo = UInt16(vertexZoneIDs[vertexZoneIDs.startIndex + i * 2])
            let hi = UInt16(vertexZoneIDs[vertexZoneIDs.startIndex + i * 2 + 1])
            ids[i] = lo | (hi << 8)
        }
        return ids
    }

    /// Packs zone IDs into the little-endian blob this schema stores.
    static func encodeZoneIDs(_ ids: [UInt16]) -> Data {
        var out = Data(capacity: ids.count * 2)
        for id in ids {
            out.append(UInt8(id & 0xFF))
            out.append(UInt8((id >> 8) & 0xFF))
        }
        return out
    }

    /// Resource basename for a body type, e.g. `"zone_map_neutral"`.
    static func resourceName(for bodyType: String) -> String { "zone_map_\(bodyType)" }
}
