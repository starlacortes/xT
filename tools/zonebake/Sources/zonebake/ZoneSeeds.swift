import Foundation
import simd

/// The 49 zone seeds, as absolute positions in the world frame `BodyTransform` establishes.
///
/// ## Labels are a persisted contract
///
/// Every `label` below must stay byte-identical to the strings already on disk.
/// `InjectionSite.zoneLabel` is the migration key for dose history and avoid-zone settings
/// (`InjectionSite.swift:11,136,182`), so renaming a zone silently orphans a user's records.
/// This bake fixes *geometry*, never taxonomy.
///
/// ## Why metres and not bounding-box fractions
///
/// The generator authored zones as fractions of the mesh bounding box, and that indirection
/// caused the bug this refactor exists to fix. Three things go wrong with it:
///
/// 1. **The box is not centred on the body.** Measured world X runs −0.289…+0.262, so the
///    anatomical midline sits at fraction 0.5245, not 0.5. Every zone authored at "0.50"
///    was actually 1.4 cm onto the body's right.
/// 2. **The depth axis was inverted**, mirroring every zone about the coronal mid-plane.
///    Fitting all eight axis-sign combinations against the shipped centroids confirmed it:
///    mean placement error fell from 0.108 to 0.047 with depth flipped, consistently across
///    all three body types.
/// 3. **Fractions hide the pose.** The arms hang at the sides, so at forearm height the arm's
///    entire depth range is negative (z −0.088…−0.014 at y = 0.89). A "front of forearm"
///    authored as a high depth fraction lands behind the body.
///
/// World space has none of these problems: the feet are at y = 0, the crown at y = 1.5, the
/// midline at x = 0, and +z is the direction the body faces. Positions below are metres,
/// measured off the mesh via `swift run zonebake --anatomy`.
///
/// ## Coordinate reminders
///
/// - **+x is the body's anatomical left**, which is why every "Left …" zone has x > 0. This
///   matches the convention already in the persisted data.
/// - +y is up, +z is anterior (front).
/// - Torso front surface sits near z = +0.06, the back near z = −0.13 (the buttocks push the
///   body's depth centre to about z = −0.03).
///
/// A seed only *locates* a zone. It is snapped to the nearest surface vertex and then grown
/// geodesically, so small inaccuracies self-correct and the baked map records real surface
/// points rather than these authored approximations.
struct ZoneSeed {
    let label: String
    /// Target position in world metres. Snapped to the nearest surface vertex at bake time.
    let position: SIMD3<Float>
    /// Geodesic reach in metres, measured along the skin from the snapped seed.
    ///
    /// Where two zones meet, the nearer seed wins and the boundary lands midway along the
    /// surface, so this mainly governs how far a zone pushes into *unclaimed* surface. That
    /// is also what carves out the non-clinical regions: head, hands, feet and below-knee are
    /// simply beyond every zone's reach and fall out as `noZone` with no hand-drawn mask.
    let extent: Float

    init(_ label: String, _ x: Float, _ y: Float, _ z: Float, extent: Float) {
        self.label = label
        self.position = SIMD3<Float>(x, y, z)
        self.extent = extent
    }
}

enum ZoneSeeds {

    /// Zones that legitimately straddle the midline; the bake report exempts only these from
    /// the midline check.
    static let midlineLabels: Set<String> = ["Upper Chest", "Periumbilical", "Neck"]

    static let all: [ZoneSeed] = [
        // MARK: Torso — upper
        // Neck at the narrowest slice (measured y = 1.28–1.33); shoulders begin at y ≈ 1.22.
        // Extent kept short: the jaw and chin are only ~5 cm along the surface from the
        // throat and are densely tessellated, so a larger reach pulls the neck zone onto
        // the face (543 vertices for 0.010 m² at extent 0.070).
        ZoneSeed("Neck",                     0.000, 1.265,  0.055, extent: 0.050),
        ZoneSeed("Upper Chest",              0.000, 1.120,  0.065, extent: 0.090),
        ZoneSeed("Left Upper Chest",         0.075, 1.120,  0.055, extent: 0.080),
        ZoneSeed("Right Upper Chest",       -0.075, 1.120,  0.055, extent: 0.080),
        ZoneSeed("Left Shoulder",            0.150, 1.210, -0.010, extent: 0.080),
        ZoneSeed("Right Shoulder",          -0.150, 1.210, -0.010, extent: 0.080),
        ZoneSeed("Left Lower Chest",         0.090, 1.020,  0.060, extent: 0.085),
        ZoneSeed("Right Lower Chest",       -0.090, 1.020,  0.060, extent: 0.085),

        // MARK: Torso — lower
        ZoneSeed("Upper Left Abdomen",       0.060, 0.940,  0.060, extent: 0.085),
        ZoneSeed("Upper Right Abdomen",     -0.060, 0.940,  0.060, extent: 0.085),
        ZoneSeed("Periumbilical",            0.000, 0.870,  0.060, extent: 0.070),
        ZoneSeed("Lower Left Abdomen",       0.060, 0.800,  0.050, extent: 0.080),
        ZoneSeed("Lower Right Abdomen",     -0.060, 0.800,  0.050, extent: 0.080),
        // Glutes are the posterior surface; the back sits near z = −0.13 at this height.
        ZoneSeed("Left Upper Glute",         0.070, 0.820, -0.120, extent: 0.095),
        ZoneSeed("Right Upper Glute",       -0.070, 0.820, -0.120, extent: 0.095),
        ZoneSeed("Left Lower Glute",         0.075, 0.740, -0.130, extent: 0.090),
        ZoneSeed("Right Lower Glute",       -0.075, 0.740, -0.130, extent: 0.090),
        // Ventrogluteal is the lateral hip, between the iliac crest and the greater trochanter.
        ZoneSeed("Left Ventrogluteal",       0.135, 0.850, -0.030, extent: 0.085),
        ZoneSeed("Right Ventrogluteal",     -0.135, 0.850, -0.030, extent: 0.085),

        // MARK: Arms — left (anatomical left, +x)
        // A-pose: arms hang at the sides and separate from the torso at y ≈ 0.95. The
        // generator's comment claims a T-pose, which the measured 0.55 m body width refutes.
        ZoneSeed("Left Deltoid",             0.170, 1.160,  0.010, extent: 0.070),
        ZoneSeed("Left Posterior Deltoid",   0.165, 1.160, -0.075, extent: 0.070),
        ZoneSeed("Left Upper Arm",           0.190, 1.030,  0.000, extent: 0.070),
        ZoneSeed("Left Triceps",             0.175, 1.030, -0.075, extent: 0.070),
        ZoneSeed("Left Forearm",             0.198, 0.890, -0.020, extent: 0.070),
        ZoneSeed("Left Posterior Forearm",   0.195, 0.890, -0.080, extent: 0.070),
        // Wrist sits at y ≈ 0.76; the hand starts just below and is densely tessellated, so
        // this extent is deliberately short to keep the zone off the hand.
        ZoneSeed("Left Inner Wrist",         0.220, 0.765,  0.010, extent: 0.050),

        // MARK: Arms — right
        // The pose is not quite symmetric — the right arm measures ~1.2 cm further out — so
        // these are the measured right-side positions rather than mirrored left ones.
        ZoneSeed("Right Deltoid",           -0.175, 1.160,  0.010, extent: 0.070),
        ZoneSeed("Right Posterior Deltoid", -0.170, 1.160, -0.075, extent: 0.070),
        ZoneSeed("Right Upper Arm",         -0.200, 1.030,  0.000, extent: 0.070),
        ZoneSeed("Right Triceps",           -0.185, 1.030, -0.075, extent: 0.070),
        ZoneSeed("Right Forearm",           -0.210, 0.890, -0.020, extent: 0.070),
        ZoneSeed("Right Posterior Forearm", -0.207, 0.890, -0.080, extent: 0.070),
        ZoneSeed("Right Inner Wrist",       -0.240, 0.765,  0.010, extent: 0.050),

        // MARK: Thighs — left (thigh spans y ≈ 0.32 crotch-to-knee 0.72)
        ZoneSeed("Upper Left Thigh",         0.105, 0.640,  0.050, extent: 0.090),
        ZoneSeed("Mid Left Thigh",           0.108, 0.520,  0.045, extent: 0.085),
        ZoneSeed("Lower Left Thigh",         0.120, 0.410,  0.028, extent: 0.085),
        ZoneSeed("Outer Left Thigh",         0.163, 0.520, -0.015, extent: 0.085),
        ZoneSeed("Inner Left Thigh",         0.052, 0.520, -0.010, extent: 0.080),
        ZoneSeed("Upper Left Hamstring",     0.105, 0.640, -0.085, extent: 0.090),
        ZoneSeed("Mid Left Hamstring",       0.108, 0.520, -0.080, extent: 0.085),
        ZoneSeed("Lower Left Hamstring",     0.118, 0.410, -0.078, extent: 0.085),

        // MARK: Thighs — right
        ZoneSeed("Upper Right Thigh",       -0.105, 0.640,  0.050, extent: 0.090),
        ZoneSeed("Mid Right Thigh",         -0.108, 0.520,  0.045, extent: 0.085),
        ZoneSeed("Lower Right Thigh",       -0.120, 0.410,  0.028, extent: 0.085),
        ZoneSeed("Outer Right Thigh",       -0.163, 0.520, -0.015, extent: 0.085),
        ZoneSeed("Inner Right Thigh",       -0.052, 0.520, -0.010, extent: 0.080),
        ZoneSeed("Upper Right Hamstring",   -0.105, 0.640, -0.085, extent: 0.090),
        ZoneSeed("Mid Right Hamstring",     -0.108, 0.520, -0.080, extent: 0.085),
        ZoneSeed("Lower Right Hamstring",   -0.118, 0.410, -0.078, extent: 0.085),
    ]
}
