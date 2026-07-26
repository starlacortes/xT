import SceneKit

@MainActor
final class ZoneCentroidStore {
    static let shared = ZoneCentroidStore()

    private let baseRadius: Float = 0.07
    private let growthPerDose: Float = 0.02
    private let maxRadius: Float = 0.25

    private(set) var centroids: [String: SCNVector3] = [:]
    private var normals: [String: SCNVector3] = [:]
    private var allLabels: [String] = []

    private struct CentroidData: Codable {
        let pos: [Float]
        let normal: [Float]
    }

    private init() {
        loadCentroids(for: .neutral)
    }

    func loadCentroids(for bodyType: BodyType) {
        let names = [bodyType.centroidsName, "zone_centroids_neutral", "zone_centroids"]
        for name in names {
            if let url  = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let dict = try? JSONDecoder().decode([String: CentroidData].self, from: data) {
                centroids = dict.compactMapValues { entry in
                    guard entry.pos.count >= 3 else { return nil }
                    return SCNVector3(entry.pos[0], entry.pos[1], entry.pos[2])
                }
                normals = dict.compactMapValues { entry in
                    guard entry.normal.count >= 3 else { return nil }
                    return SCNVector3(entry.normal[0], entry.normal[1], entry.normal[2])
                }
                allLabels = Array(centroids.keys).sorted()
                #if DEBUG
                assertCentroidsSeparated()
                #endif
                return
            }
        }
    }

    func centroid(for label: String) -> SCNVector3? {
        centroids[label]
    }

    func normal(for label: String) -> SCNVector3? {
        normals[label]
    }

    func nearestLabel(to worldPos: SCNVector3, within maxDist: Float) -> String? {
        var bestDist = maxDist
        var bestLabel: String?
        for (label, pos) in centroids {
            let dx = pos.x - worldPos.x
            let dy = pos.y - worldPos.y
            let dz = pos.z - worldPos.z
            let d = sqrt(dx*dx + dy*dy + dz*dz)
            if d < bestDist {
                bestDist = d
                bestLabel = label
            }
        }
        return bestLabel
    }

    func radius(forCount count: Int) -> Float {
        let r = baseRadius + growthPerDose * Float(count)
        return min(r, maxRadius)
    }

    func zonesOverlap(_ a: String, _ b: String, heatMap: [String: Int]) -> Bool {
        guard let pa = centroids[a], let pb = centroids[b] else { return false }
        let ra = radius(forCount: heatMap[a] ?? 0)
        let rb = radius(forCount: heatMap[b] ?? 0)
        let dx = pa.x - pb.x
        let dy = pa.y - pb.y
        let dz = pa.z - pb.z
        let dist = sqrt(dx*dx + dy*dy + dz*dz)
        return dist < (ra + rb)
    }

    var labels: [String] { allLabels }

    // MARK: - Validation

    /// Asserts that no two zone centroids are near-duplicates (distance < 0.01).
    /// Catches data-entry errors like duplicated or misplaced centroids in the
    /// JSON without flagging anatomically adjacent zones that are intentionally
    /// close (e.g. same-thigh alternates, abdominal quadrants, gluteal zones).
    /// Only runs in DEBUG builds.
    private func assertCentroidsSeparated() {
        let entries = Array(centroids)
        let minSeparation: Float = 0.01
        for i in 0..<entries.count {
            for j in (i+1)..<entries.count {
                let a = entries[i].value
                let b = entries[j].value
                let dx = a.x - b.x
                let dy = a.y - b.y
                let dz = a.z - b.z
                let dist = sqrt(dx*dx + dy*dy + dz*dz)
                assert(dist >= minSeparation,
                       "ZoneCentroidStore: \"\(entries[i].key)\" and \"\(entries[j].key)\" are near-duplicates (\(String(format: "%.3f", dist)) < \(String(format: "%.3f", minSeparation))). Check centroid JSON.")
            }
        }
    }

    // MARK: - Zone Metadata (migrated from BodySketchData)

    /// Maps a zone label to its body region (e.g. "Left Deltoid" → "arms").
    /// Derived from zone label naming conventions.
    func region(for zoneLabel: String) -> String? {
        let lower = zoneLabel.lowercased()
        if lower.contains("thigh") || lower.contains("hamstring") { return "thighs" }
        if lower.contains("glute") || lower.contains("ventrogluteal") { return "glutes" }
        if lower.contains("deltoid") || lower.contains("tricep") || lower.contains("forearm")
            || lower.contains("upper arm") || lower.contains("posterior") { return "arms" }
        if lower.contains("shoulder") || lower.contains("chest") || lower.contains("abdomen")
            || lower.contains("periumbilical") || lower.contains("neck") || lower.contains("wrist") {
            return "upperBody"
        }
        return nil
    }

    /// Derives view context (front/back) from camera yaw angle.
    /// front = -π/4…π/4, right = π/4…3π/4, back = 3π/4…π or -π…-3π/4, left = -3π/4…-π/4
    static func viewContext(from yaw: Float) -> String {
        let angle = atan2(sin(yaw), cos(yaw)) // normalize to -π…π
        switch angle {
        case let a where a >= -.pi/4 && a <= .pi/4: return "front"
        case let a where a > .pi/4 && a <= 3 * .pi / 4: return "right"
        case let a where a < -.pi/4 && a >= -3 * .pi / 4: return "left"
        default: return "back"
        }
    }

    // MARK: - Preferred Zones (migrated from BodySketchData)

    /// Clinical consensus on preferred administration sites.
    /// Key: "MedicationName|RouteClass" (e.g. "Testosterone|injection").
    static let preferredZones: [String: [String]] = [
        "Testosterone|injection": [
            "Right Ventrogluteal", "Left Ventrogluteal",
            "Upper Right Thigh", "Upper Left Thigh",
            "Right Deltoid", "Left Deltoid",
        ],
        "Testosterone|topical": [
            "Left Shoulder", "Right Shoulder",
            "Left Upper Arm", "Right Upper Arm",
            "Upper Left Abdomen", "Upper Right Abdomen",
        ],
        "Testosterone|patch": [
            "Upper Left Abdomen", "Upper Right Abdomen",
            "Lower Left Abdomen", "Lower Right Abdomen",
            "Left Upper Glute", "Right Upper Glute",
        ],
        "Testosterone|oral": [],

        "Estrogen|injection": [
            "Right Ventrogluteal", "Left Ventrogluteal",
            "Upper Right Thigh", "Upper Left Thigh",
            "Right Deltoid", "Left Deltoid",
            "Periumbilical", "Upper Left Abdomen", "Upper Right Abdomen",
        ],
        "Estrogen|topical": [
            "Left Forearm", "Right Forearm",
            "Left Shoulder", "Right Shoulder",
            "Upper Left Thigh", "Upper Right Thigh",
        ],
        "Estrogen|patch": [
            "Lower Left Abdomen", "Lower Right Abdomen",
            "Left Upper Glute", "Right Upper Glute",
        ],
        "Estrogen|oral": [],

        "Progesterone|injection": [
            "Right Ventrogluteal", "Left Ventrogluteal",
            "Upper Right Thigh", "Upper Left Thigh",
        ],
        "Progesterone|topical": [
            "Left Forearm", "Right Forearm",
            "Left Inner Wrist", "Right Inner Wrist",
            "Neck", "Upper Chest",
        ],
        "Progesterone|patch": [
            "Upper Left Abdomen", "Upper Right Abdomen",
            "Left Upper Glute", "Right Upper Glute",
        ],
    ]

    /// Returns the preferred zone labels for a given medication + route class.
    static func preferredZones(medication: String, routeClass: RouteClass) -> [String] {
        let key = "\(medication)|\(routeClass.rawValue)"
        return preferredZones[key] ?? []
    }

    // MARK: - Recommended Zones

    /// Anatomically suitable injection/patch/topical zones for each route class.
    static func recommendedZones(for routeClass: RouteClass) -> [String] {
        switch routeClass {
        case .injection:
            return [
                "Upper Left Thigh", "Mid Left Thigh", "Lower Left Thigh",
                "Outer Left Thigh", "Inner Left Thigh",
                "Upper Right Thigh", "Mid Right Thigh", "Lower Right Thigh",
                "Outer Right Thigh", "Inner Right Thigh",
                "Left Ventrogluteal", "Right Ventrogluteal",
                "Left Upper Glute", "Right Upper Glute",
                "Left Lower Glute", "Right Lower Glute",
                "Upper Left Abdomen", "Upper Right Abdomen",
                "Lower Left Abdomen", "Lower Right Abdomen",
                "Periumbilical",
                "Left Deltoid", "Right Deltoid",
                "Left Upper Arm", "Right Upper Arm",
            ]
        case .topical:
            return [
                "Left Forearm", "Right Forearm",
                "Left Inner Wrist", "Right Inner Wrist",
                "Left Shoulder", "Right Shoulder",
                "Left Upper Arm", "Right Upper Arm",
                "Upper Left Abdomen", "Upper Right Abdomen",
                "Lower Left Abdomen", "Lower Right Abdomen",
                "Upper Left Thigh", "Upper Right Thigh",
                "Inner Left Thigh", "Inner Right Thigh",
                "Neck",
            ]
        case .patch:
            return [
                "Upper Left Abdomen", "Upper Right Abdomen",
                "Lower Left Abdomen", "Lower Right Abdomen",
                "Left Upper Glute", "Right Upper Glute",
                "Left Upper Arm", "Right Upper Arm",
                "Upper Chest",
                "Left Upper Chest", "Right Upper Chest",
                "Left Shoulder", "Right Shoulder",
            ]
        case .oral:
            return []
        }
    }
}
