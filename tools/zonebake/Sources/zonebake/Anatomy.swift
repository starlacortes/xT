import Foundation
import simd

/// Measures where the body's parts actually are, so seeds can be placed against the mesh
/// instead of against assumptions.
///
/// This exists because guessing cost real time. The arm seeds were first authored from
/// plausible-looking height fractions and the right wrist landed on the *hand* — 223 vertices
/// covering only 0.0023 m², because hand topology is dense and hand surface is small. The
/// generator's own comment claims a T-pose while the mesh actually ships in an A-pose, so
/// inherited numbers cannot be trusted either.
///
/// Run with `swift run zonebake --anatomy`.
enum Anatomy {

    /// At each height, splits the cross-section into connected clusters along X. A torso-only
    /// slice yields one cluster; a slice through the arms yields three (right arm, torso,
    /// left arm); a slice through the legs yields two.
    static func report(mesh: BodyMesh) {
        print("")
        print("=========================================================")
        print(" anatomy — \(mesh.bodyType)")
        print("=========================================================")
        print(" slices every 5 cm: X clusters (gap > 2 cm splits a cluster)")
        print("")
        print("   y      verts  clusters  cluster x-ranges (m)")

        let band: Float = 0.05
        var y: Float = 1.50
        while y > 0 {
            let lo = y - band
            let idx = (0..<mesh.vertexCount).filter {
                let py = mesh.worldPositions[$0].y
                return py >= lo && py < y
            }
            if idx.isEmpty { y -= band; continue }

            // Cluster along X, then report each cluster's depth range too — depth is what
            // decides anterior vs posterior placement, and it is the axis the pipeline had
            // inverted, so it is the one worth being certain about.
            let sorted = idx.sorted { mesh.worldPositions[$0].x < mesh.worldPositions[$1].x }
            var clusters: [(xLo: Float, xHi: Float, count: Int, zLo: Float, zHi: Float)] = []
            var current: [Int] = [sorted[0]]
            for v in sorted.dropFirst() {
                let prevX = mesh.worldPositions[current[current.count - 1]].x
                if mesh.worldPositions[v].x - prevX > 0.02 {
                    clusters.append(summarize(current, mesh))
                    current = [v]
                } else { current.append(v) }
            }
            clusters.append(summarize(current, mesh))

            let desc = clusters.map {
                String(format: "[x%+.3f…%+.3f z%+.3f…%+.3f]%d", $0.xLo, $0.xHi, $0.zLo, $0.zHi, $0.count)
            }.joined(separator: " ")
            print(String(format: "   %.2f   %5d      %d      %@", lo, idx.count, clusters.count, desc))
            y -= band
        }

        // Where does the arm surface live? Vertices far from the midline at torso heights.
        print("")
        print(" limb landmarks:")
        landmark(mesh, "lowest arm/hand vertex (|x| > 0.10)") { p in abs(p.x) > 0.10 }
        landmark(mesh, "widest point (max |x|)") { _ in true }

        // Neck: the narrowest slice between the chin and the shoulders.
        var narrowest: (y: Float, width: Float) = (0, .greatestFiniteMagnitude)
        var yy: Float = 1.45
        while yy > 1.15 {
            let idx = (0..<mesh.vertexCount).filter {
                let py = mesh.worldPositions[$0].y
                return py >= yy - 0.02 && py < yy
            }
            if !idx.isEmpty {
                let xs = idx.map { mesh.worldPositions[$0].x }
                let w = (xs.max() ?? 0) - (xs.min() ?? 0)
                if w < narrowest.width { narrowest = (yy, w) }
            }
            yy -= 0.02
        }
        print(String(format: "   neck (narrowest slice 1.15–1.45): y=%.2f width=%.3f m", narrowest.y, narrowest.width))
        print("")
    }

    private static func summarize(_ verts: [Int], _ mesh: BodyMesh)
        -> (xLo: Float, xHi: Float, count: Int, zLo: Float, zHi: Float) {
        var xLo = Float.greatestFiniteMagnitude, xHi = -Float.greatestFiniteMagnitude
        var zLo = Float.greatestFiniteMagnitude, zHi = -Float.greatestFiniteMagnitude
        for v in verts {
            let p = mesh.worldPositions[v]
            xLo = min(xLo, p.x); xHi = max(xHi, p.x)
            zLo = min(zLo, p.z); zHi = max(zHi, p.z)
        }
        return (xLo, xHi, verts.count, zLo, zHi)
    }

    private static func landmark(_ mesh: BodyMesh, _ name: String, _ predicate: (SIMD3<Float>) -> Bool) {
        var minY = Float.greatestFiniteMagnitude
        var maxAbsX: Float = 0
        var atY: Float = 0
        for p in mesh.worldPositions where predicate(p) {
            minY = min(minY, p.y)
            if abs(p.x) > maxAbsX { maxAbsX = abs(p.x); atY = p.y }
        }
        print(String(format: "   %-38s minY=%.3f  max|x|=%.3f at y=%.3f",
                     (name as NSString).utf8String!, minY, maxAbsX, atY))
    }
}
