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
}
