import SceneKit
import simd

struct ZoneHitResult {
    let label: String
    let worldPosition: SCNVector3
    let worldNormal: SCNVector3
}

/// What a tap on the 3-D body produced.
///
/// The old engine returned `ZoneHitResult?`, collapsing two very different outcomes into
/// `nil`: the ray missed the body entirely, and the ray hit the body somewhere with no zone.
/// With 57% of the surface resolving to no zone, the second case was common — and
/// indistinguishable, so the UI had nothing to say and taps on a head or hand just vanished.
enum ZoneTapOutcome {
    /// Hit the body inside a zone.
    case zone(ZoneHitResult)
    /// Hit the body, but on surface that belongs to no clinical zone — head, hands, feet,
    /// below the knee, or the back. Carries the hit point so the UI can mark the spot.
    case noZone(worldPosition: SCNVector3, worldNormal: SCNVector3)
    /// The ray missed the body altogether.
    case miss
}

@MainActor
final class ZoneHitTestEngine {

    /// Set once the model and its baked map have loaded. Until then every tap is a miss —
    /// better than falling back to a guess that would label the wrong body part.
    var zoneMap: ZoneMap?

    func outcome(at location: CGPoint, in scnView: SCNView) -> ZoneTapOutcome {
        let results = scnView.hitTest(location, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue,
            .boundingBoxOnly: false
        ])

        guard let bodyHit = results.first(where: { $0.node.geometry != nil }) else {
            return .miss
        }

        let worldPt = bodyHit.worldCoordinates
        let worldN = bodyHit.worldNormal

        guard let zoneMap else {
            return .noZone(worldPosition: worldPt, worldNormal: worldN)
        }

        let local = SIMD3<Float>(bodyHit.localCoordinates)
        switch zoneMap.resolve(localPoint: local) {
        case .zone(let label):
            return .zone(ZoneHitResult(label: label, worldPosition: worldPt, worldNormal: worldN))
        case .noZone:
            return .noZone(worldPosition: worldPt, worldNormal: worldN)
        }
    }

    /// Convenience for callers that only care about a successful zone hit.
    func hitResult(at location: CGPoint, in scnView: SCNView) -> ZoneHitResult? {
        if case .zone(let result) = outcome(at: location, in: scnView) { return result }
        return nil
    }

    func zoneAtTap(_ location: CGPoint, in scnView: SCNView) -> String? {
        hitResult(at: location, in: scnView)?.label
    }
}
