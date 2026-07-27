import SceneKit
import simd

/// The single definition of how a shipped `body_*.usdz` is placed into world space.
///
/// Before this type existed, three places each hardcoded their own version of this
/// transform — `BodyModel3DView.loadBodyModel`, `blender_generate_body.py`'s centroid
/// exporter, and `CentroidValidationTests` — and they disagreed. That disagreement is
/// what put zone labels on the wrong body parts. Every consumer must go through here.
///
/// ## Three coordinate spaces, not two
///
/// This is the detail that makes the bug so easy to reintroduce. A loaded body USDZ has
/// **three** nested spaces, and only the middle one is what this type converts from:
///
/// 1. **Source space** — the raw bytes in `SCNGeometrySource`. Still Blender's Z-up frame:
///    height runs along `+Z` over `[0, 1.65]`, and `y` is the shallow depth axis. The USDZ
///    carries a rotation node that converts Z-up to Y-up, so this space is *not* what the
///    node hierarchy reports. It is, however, the space that vertex indices refer to and
///    that `SCNHitTestResult.localCoordinates` is expressed in — so the baked per-vertex
///    zone map and its lookup grid both live here, and need no transform at tap time.
/// 2. **Wrapper space** — Y-up, head-down; what `wrapper.boundingBox` reports. Reaching it
///    from source space means applying the geometry node's own `worldTransform`. **This is
///    the space `BodyTransform` takes as input.**
/// 3. **World space** — upright, facing the camera. What this type produces.
///
/// So the full chain is `source → (node.worldTransform) → wrapper → (BodyTransform) → world`.
/// Feeding raw source coordinates straight into `worldPoint(fromLocal:)` skips a step and
/// silently produces a body floating sideways.
///
/// ## What the shipped meshes actually look like
///
/// Measured from all three USDZs in *wrapper* space (identical layout in each):
///
/// - Local Y spans `[0, 1.65]`, and the eye geometry subset sits at `y ≈ 0.107` —
///   **the meshes are stored head-down**, head at local *min* Y, feet at local *max* Y.
///   This is a bug in the Blender pipeline (`normalize_body` pins `min_z → 0` without
///   checking which end is the head); Phase 5 fixes the generator, but the shipped
///   assets have to be read as they are.
/// - The face points toward local **+Z**.
/// - The anatomical midline is local **X = 0** (68.7% of vertices have a sub-millimetre
///   mirror partner across it; the ~4 mm residual is asymmetric arm pose).
///
/// ## Orientation is detected, not assumed
///
/// The correcting rotation comes from `BodyOrientation`, which measures which end of the mesh
/// is the head and which way it faces. An earlier version of this type hardcoded the shipped
/// assets' upside-down storage, which made the generator's bug load-bearing: fixing
/// `blender_generate_body.py` would have silently broken the app. Detection removes that trap.
///
/// ## Why a rotation and not a negated scale
///
/// The old code wrote `scale = (s, -s, s)`, which fixes head-up but has a negative
/// determinant (measured −0.751): an improper, *mirroring* transform. It inverts triangle
/// winding — which is the only reason `isDoubleSided = true` was needed — and it inverts
/// the normal matrix, leaving 27 of 49 exported centroid normals pointing into the body.
///
/// A proper rotation always flips exactly two axes, so it cannot reproduce a one-axis
/// mirror. Of the two candidates that put the head up:
///
/// - `Rx(180)` flips Y and Z — head up, but the face ends up at −Z, away from the camera.
/// - `Rz(180)` flips X and Y — head up, and the face stays at +Z, toward the camera.
///
/// `Rz(180)` is therefore the correct replacement. Relative to the old mirrored render it
/// flips world X, which is invisible on a near-symmetric body but does mean zone seeds must
/// be authored in the frame this type defines, not carried over from the old `nx` convention.
///
/// ## The world frame this establishes
///
/// - `+Y` is up; the feet sit at `y = 0` and the crown at `y = targetHeight`.
/// - `+Z` is the direction the body faces, which is where the default camera sits.
/// - **`+X` is the body's anatomical left.** A person facing you shows their left on your
///   right, and the camera's right is `+X`. This matches the label convention already
///   baked into the persisted data: every "Left …" zone has `x > 0` and every "Right …"
///   zone has `x < 0`.
struct BodyTransform {

    /// World-space height, in metres, that every body type is normalized to.
    static let targetHeight: Float = 1.5

    /// Uniform scale applied to the mesh's local coordinates.
    let scale: Float

    /// Local-space bounding box the transform was derived from.
    let localMin: SIMD3<Float>
    let localMax: SIMD3<Float>

    /// How the mesh is stored, which decides the correcting rotation.
    let orientation: BodyOrientation

    /// Fails if the bounding box is degenerate, which means the mesh did not load.
    init?(localMin: SIMD3<Float>, localMax: SIMD3<Float>,
          orientation: BodyOrientation = .shippedAssets) {
        let height = localMax.y - localMin.y
        guard height > 0.01 else { return nil }
        self.scale = Self.targetHeight / height
        self.localMin = localMin
        self.localMax = localMax
        self.orientation = orientation
    }

    /// Convenience initializer taking a node's `boundingBox` directly.
    init?(boundingBox: (min: SCNVector3, max: SCNVector3),
          orientation: BodyOrientation = .shippedAssets) {
        self.init(localMin: SIMD3<Float>(boundingBox.min),
                  localMax: SIMD3<Float>(boundingBox.max),
                  orientation: orientation)
    }

    // MARK: - Node placement

    /// Rotation that brings the mesh upright and facing +Z without mirroring it.
    var eulerAngles: SIMD3<Float> { orientation.correctingEulerAngles }

    /// Translation that lands the feet on `y = 0` after the rotation.
    ///
    /// The rotation sends local `y` to `-scale * y`, so local `maxY` (the feet, since the
    /// mesh is head-down) arrives at `-scale * maxY`; adding `scale * maxY` puts it at zero
    /// and carries local `minY` (the head) up to `targetHeight`.
    ///
    /// X is deliberately left at zero rather than centred on the bounding box: the local
    /// box is *not* symmetric about X (the arms are posed asymmetrically), but the body's
    /// midline is at local X = 0, so leaving X alone is what keeps the body centred.
    var position: SIMD3<Float> {
        // After the rotation, whichever local Y bound ends up lowest must be lifted to y = 0.
        // A 180° flip about X or Z sends local y to -scale*y, so the local *maximum* arrives at
        // the bottom; without a flip the local *minimum* is already there and must be pushed up.
        SIMD3<Float>(0, orientation.headAtMinY ? localMax.y * scale : -localMin.y * scale, 0)
    }

    /// Applies scale, rotation and position to the wrapper node holding the mesh.
    func apply(to node: SCNNode) {
        let s = SCNFloat(scale)
        node.scale = SCNVector3(s, s, s)
        node.eulerAngles = SCNVector3(eulerAngles)
        node.position = SCNVector3(position)
    }

    // MARK: - Matrices

    /// Maps a point in mesh-local space to world space.
    var worldFromLocal: simd_float4x4 {
        // Composed through a scratch node so it uses SceneKit's own maths and cannot disagree
        // with `apply(to:)`. An earlier version hand-expanded the matrix for one specific
        // rotation, which silently became wrong once orientation was detected rather than fixed.
        let n = SCNNode()
        let s = SCNFloat(scale)
        n.scale = SCNVector3(s, s, s)
        n.eulerAngles = SCNVector3(eulerAngles)
        n.position = SCNVector3(position)
        return simd_float4x4(n.transform)
    }

    /// Maps a point in world space back to mesh-local space.
    var localFromWorld: simd_float4x4 { worldFromLocal.inverse }

    /// Correct matrix for taking local normals to world space.
    ///
    /// For this transform the inverse-transpose happens to agree with the rotation up to a
    /// positive scale factor, but it is computed properly so the type stays correct if the
    /// transform ever gains a non-uniform component.
    var normalMatrix: simd_float3x3 {
        let m = worldFromLocal
        let linear = simd_float3x3(SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                                  SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                  SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        return linear.inverse.transpose
    }

    // MARK: - Point conversion

    func worldPoint(fromLocal p: SIMD3<Float>) -> SIMD3<Float> {
        let r = worldFromLocal * SIMD4<Float>(p, 1)
        return SIMD3<Float>(r.x, r.y, r.z)
    }

    func localPoint(fromWorld p: SIMD3<Float>) -> SIMD3<Float> {
        let r = localFromWorld * SIMD4<Float>(p, 1)
        return SIMD3<Float>(r.x, r.y, r.z)
    }

    func worldNormal(fromLocal n: SIMD3<Float>) -> SIMD3<Float> {
        let v = normalMatrix * n
        let len = simd_length(v)
        return len > 0 ? v / len : v
    }

    // MARK: - Self-check

    /// True when the transform is a proper (non-mirroring) rotation plus uniform scale.
    /// The old `scale.y = -scale` form returns false here; that is the regression this
    /// type exists to prevent.
    var isProper: Bool {
        let m = worldFromLocal
        let linear = simd_float3x3(SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                                  SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                                  SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        return simd_determinant(linear) > 0
    }
}
