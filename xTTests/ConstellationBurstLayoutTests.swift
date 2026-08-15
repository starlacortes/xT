import Testing
import simd
@testable import xT

/// Layout invariants for the tap-constellation burst. The visuals are tweaked
/// by eye, but the geometry math (determinism, bounds, chain integrity) is
/// pinned here so later tweaks can't silently break the effect.
struct ConstellationBurstLayoutTests {

    @Test func deterministicForSameSeed() {
        let a = ConstellationBurstLayout.make(seed: 42)
        let b = ConstellationBurstLayout.make(seed: 42)
        #expect(a.positions == b.positions)
        #expect(a.connections.count == b.connections.count)
        for (x, y) in zip(a.connections, b.connections) {
            #expect(x == y)
        }
    }

    @Test func differentSeedsGiveDifferentLayouts() {
        let a = ConstellationBurstLayout.make(seed: 1)
        let b = ConstellationBurstLayout.make(seed: 2)
        #expect(a.positions != b.positions)
    }

    @Test func starCountHonoredAndPositionsBounded() {
        let count = 6
        let layout = ConstellationBurstLayout.make(seed: 7, starCount: count)
        #expect(layout.positions.count == count)
        for p in layout.positions {
            let planar = sqrt(p.x * p.x + p.y * p.y)
            #expect(planar <= ConstellationBurstLayout.defaultRadius + 1e-5)
            // Lifted off the surface but close to it, so stars never z-fight.
            #expect(p.z >= 0.006 && p.z <= 0.016)
        }
    }

    @Test func connectionsFormASingleChain() {
        let count = 6
        let layout = ConstellationBurstLayout.make(seed: 99, starCount: count)

        // Exactly one chain through all stars: count − 1 segments, in order.
        #expect(layout.connections.count == count - 1)
        #expect(layout.connections.first?.0 == 0)
        for (a, b) in layout.connections {
            #expect(a >= 0 && a < count && b >= 0 && b < count && a != b)
        }
        // Every star appears; each connection continues from the previous end.
        var seen: Set<Int> = []
        var cursor = layout.connections.first?.0
        #expect(cursor != nil)
        seen.insert(cursor!)
        for (_, b) in layout.connections {
            #expect(!seen.contains(b)) // chain never revisits a star
            seen.insert(b)
            cursor = b
        }
        #expect(seen.count == count)
    }
}
