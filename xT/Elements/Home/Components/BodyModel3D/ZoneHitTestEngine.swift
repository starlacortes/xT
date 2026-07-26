import SceneKit

struct ZoneHitResult {
    let label: String
    let worldPosition: SCNVector3
    let worldNormal: SCNVector3
}

@MainActor
final class ZoneHitTestEngine {

    func hitResult(at location: CGPoint, in scnView: SCNView) -> ZoneHitResult? {
        let results = scnView.hitTest(location, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .boundingBoxOnly: false
        ])

        guard let bodyHit = results.first(where: { isBodyGeometry($0.node) }) else {
            return nil
        }

        let worldPt = bodyHit.worldCoordinates
        let worldN  = bodyHit.worldNormal
        guard let label = ZoneCentroidStore.shared.nearestLabel(to: worldPt, within: 0.15) else {
            return nil
        }

        return ZoneHitResult(label: label, worldPosition: worldPt, worldNormal: worldN)
    }

    func zoneAtTap(_ location: CGPoint, in scnView: SCNView) -> String? {
        return hitResult(at: location, in: scnView)?.label
    }

    private func isBodyGeometry(_ node: SCNNode) -> Bool {
        guard node.geometry != nil else { return false }
        if let name = node.name, name.hasPrefix("zone_") {
            return false
        }
        return true
    }
}
