import Foundation
import simd

/// Works out which way a loaded body mesh is facing, instead of assuming.
///
/// ## Why this exists
///
/// The shipped assets are stored **head-down** and facing **−Y** in Blender's frame. That is
/// not intentional: `blender_generate_body.py`'s `normalize_body` pins the mesh's minimum Z to
/// zero to put "the feet" on the floor, without ever checking which end is the head. The source
/// OBJ is upright, so something between import and export inverted it, and nothing noticed
/// because a second inversion in the app cancelled it for the height axis alone.
///
/// The app used to hardcode a correction for exactly that storage. Which meant that *fixing*
/// the generator would silently break the app — the bug had become load-bearing. Detecting the
/// orientation instead removes that trap: correct assets and inverted assets both land upright,
/// and the generator can be fixed independently.
///
/// ## How the detection works
///
/// Both tests use strong, measured geometric signals rather than landmarks that need topology:
///
/// - **Which end is the head?** The extreme slice at the feet end is much wider than the one at
///   the head end, because it contains two feet spread apart while the other contains a crown.
///   Measured on the source mesh: 4.67 vs 1.67 units of lateral width, a 2.8× ratio.
/// - **Which way is the front?** The feet point forward. Comparing the sole/toe slice against
///   the ankle slice just above it, the foot reaches ~10 cm further forward than the ankle but
///   only ~0.5 mm further back — a 20× asymmetry, and the clearest directional cue on the mesh.
///
///   A nose-protrusion test at head height was tried first and rejected: the occiput extends
///   about as far back as the nose does forward (measured −0.108 vs +0.079 about a head-band
///   mean), and the densely tessellated face drags that mean forward, so the test confidently
///   returned the wrong answer. The feet have no such ambiguity.
struct BodyOrientation {

    /// True when the mesh is stored with the head at minimum Y (i.e. upside down).
    let headAtMinY: Bool
    /// Sign of the axis the body faces, +1 for +Z or −1 for −Z.
    let frontZSign: Float

    /// Detects orientation from vertices in wrapper space (Y is the height axis).
    ///
    /// Returns nil when the mesh is too small or degenerate to judge.
    init?(wrapperSpaceVertices verts: [SIMD3<Float>]) {
        guard verts.count >= 64 else { return nil }

        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in verts { lo = simd_min(lo, p); hi = simd_max(hi, p) }
        let height = hi.y - lo.y
        guard height > 0.01 else { return nil }

        // Lateral width of the extreme 6% slice at each end.
        let bandHeight = height * 0.06
        func lateralWidth(minY: Float, maxY: Float) -> Float {
            var xLo = Float.greatestFiniteMagnitude
            var xHi = -Float.greatestFiniteMagnitude
            for p in verts where p.y >= minY && p.y <= maxY {
                xLo = min(xLo, p.x); xHi = max(xHi, p.x)
            }
            return xHi > xLo ? xHi - xLo : 0
        }
        let widthAtMinY = lateralWidth(minY: lo.y, maxY: lo.y + bandHeight)
        let widthAtMaxY = lateralWidth(minY: hi.y - bandHeight, maxY: hi.y)
        guard widthAtMinY > 0, widthAtMaxY > 0 else { return nil }

        // The narrower end is the head. Held in a local first: the nested function below
        // would otherwise capture `self` before initialization completes.
        let headAtMin = widthAtMinY < widthAtMaxY
        self.headAtMinY = headAtMin

        // Compare the sole/toe slice against the ankle slice just above it. Working from the
        // feet end, whichever end that is.
        func depthRange(fromFeetFraction a: Float, to b: Float) -> (lo: Float, hi: Float)? {
            // `a` and `b` are fractions of height measured up from the feet.
            let y0: Float, y1: Float
            if headAtMin {
                // Feet are at max Y, so "up from the feet" runs toward min Y.
                y0 = hi.y - height * b
                y1 = hi.y - height * a
            } else {
                y0 = lo.y + height * a
                y1 = lo.y + height * b
            }
            var zLo = Float.greatestFiniteMagnitude
            var zHi = -Float.greatestFiniteMagnitude
            for p in verts where p.y >= y0 && p.y <= y1 {
                zLo = min(zLo, p.z); zHi = max(zHi, p.z)
            }
            return zHi > zLo ? (zLo, zHi) : nil
        }
        guard let foot = depthRange(fromFeetFraction: 0.0, to: 0.035),
              let ankle = depthRange(fromFeetFraction: 0.035, to: 0.075) else { return nil }

        let forwardExtension = foot.hi - ankle.hi
        let backwardExtension = ankle.lo - foot.lo
        self.frontZSign = forwardExtension >= backwardExtension ? 1 : -1
    }

    /// Explicit initializer, for tests and for callers that already know.
    init(headAtMinY: Bool, frontZSign: Float) {
        self.headAtMinY = headAtMinY
        self.frontZSign = frontZSign
    }

    /// The orientation the currently shipped assets have: stored upside down, facing +Z.
    static let shippedAssets = BodyOrientation(headAtMinY: true, frontZSign: 1)

    /// What a correctly generated asset would have.
    static let canonical = BodyOrientation(headAtMinY: false, frontZSign: 1)

    /// Euler angles that bring the mesh upright and facing +Z, as a **proper** rotation.
    ///
    /// A proper rotation always flips exactly two axes, so it can never reproduce a one-axis
    /// mirror — which is precisely why the old `scale.y = -scale` shortcut was wrong. The
    /// combinations below are chosen so the head ends up at +Y and the face at +Z without ever
    /// resorting to a negative determinant.
    var correctingEulerAngles: SIMD3<Float> {
        switch (headAtMinY, frontZSign >= 0) {
        case (true, true):
            // Upside down, facing +Z. Rotating 180° about Z flips Y (head goes up) and X,
            // leaving Z — so the face keeps pointing at the camera.
            return SIMD3<Float>(0, 0, .pi)
        case (true, false):
            // Upside down, facing −Z. Rotating 180° about X flips Y and Z at once.
            return SIMD3<Float>(.pi, 0, 0)
        case (false, true):
            // Already correct.
            return SIMD3<Float>(0, 0, 0)
        case (false, false):
            // Upright but facing away. Yaw 180° about Y.
            return SIMD3<Float>(0, .pi, 0)
        }
    }
}
