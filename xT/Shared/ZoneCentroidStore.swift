import SceneKit
import simd

/// Zone metadata: the clinical tables, plus a facade over whichever `ZoneMap` is currently
/// loaded for geometry.
///
/// ## What changed and why
///
/// This type used to own zone geometry, loading `zone_centroids_<type>.json` and answering
/// `nearestLabel(to:within:)` by scanning 49 points in 3-D Euclidean space. That is gone.
/// Geometry now lives in the baked `ZoneMap`, for two reasons:
///
/// - **The nearest-centroid scan could not partition a body surface.** 57% of the mesh
///   resolved to no zone, `Inner Right Thigh` was unreachable, and the wrist zones claimed
///   14% of the body because a hand is close to a thigh through the air but far along skin.
/// - **Two sources of centroid truth is the bug that caused this.** The exporter, the app and
///   the tests each had their own idea of where a zone was. There is now one baked map, and
///   this type forwards to it rather than keeping a parallel copy.
///
/// `loadCentroids(for:)` is also gone. It had exactly one call site — `init` with `.neutral` —
/// so the feminine and masculine meshes were hit-tested against neutral centroids, offset by up
/// to 8 cm. `ZoneMap` is loaded per body type by `BodyModel3DView`.
@MainActor
final class ZoneCentroidStore {
    static let shared = ZoneCentroidStore()

    /// Extra radius per recorded dose, so a frequently-used site glows larger.
    private let growthPerDose: Float = 0.02
    private let maxRadius: Float = 0.25
    /// Used only when no map is loaded yet.
    private let fallbackRadius: Float = 0.07

    /// The active map, set by `BodyModel3DView` once the model for the selected body type has
    /// loaded. Nil before then; every geometry accessor degrades to nil rather than guessing.
    weak var zoneMap: ZoneMap?

    private init() {}

    // MARK: - Labels

    /// All 49 zone labels. Comes from the generated `ZoneID` enum rather than from a loaded
    /// asset, so settings screens can list zones before any 3-D model exists.
    nonisolated var labels: [String] { ZoneID.allCases.map(\.rawValue) }

    // MARK: - Geometry (forwarded to the baked map)

    func centroid(for label: String) -> SCNVector3? {
        guard let v = zoneMap?.centroid(for: label) else { return nil }
        return SCNVector3(v)
    }

    func normal(for label: String) -> SCNVector3? {
        guard let v = zoneMap?.normal(for: label) else { return nil }
        return SCNVector3(v)
    }

    /// Glow radius for a zone: its measured patch radius, grown by recorded dose count.
    ///
    /// The base is the zone's real extent from the bake, replacing a flat `0.07` that bore no
    /// relation to how big the zone actually is — a wrist and a glute were drawn the same size.
    func radius(for label: String, count: Int) -> Float {
        let base = zoneMap?.radius(for: label) ?? fallbackRadius
        return min(base + growthPerDose * Float(count), maxRadius)
    }

    /// Do two zones' glows overlap at their current dose counts?
    func zonesOverlap(_ a: String, _ b: String, heatMap: [String: Int]) -> Bool {
        guard let pa = zoneMap?.centroid(for: a), let pb = zoneMap?.centroid(for: b) else { return false }
        let ra = radius(for: a, count: heatMap[a] ?? 0)
        let rb = radius(for: b, count: heatMap[b] ?? 0)
        return simd_distance(pa, pb) < (ra + rb)
    }

    // MARK: - Zone Metadata

    /// Maps a zone label to its body region.
    ///
    /// This was a chain of `lowercased().contains(...)` tests whose result depended on the
    /// order they were written in — "Left Posterior Forearm" matched on "posterior" and landed
    /// in `arms` only because that clause happened to come before the one containing
    /// "forearm". An explicit table cannot be reordered into a different answer.
    nonisolated func region(for zoneLabel: String) -> String? {
        Self.regionsByLabel[zoneLabel]
    }

    nonisolated private static let regionsByLabel: [String: String] = {
        var map: [String: String] = [:]
        func assign(_ region: String, _ zones: [ZoneID]) {
            for z in zones { map[z.rawValue] = region }
        }
        assign("thighs", [
            .upperLeftThigh, .midLeftThigh, .lowerLeftThigh, .outerLeftThigh, .innerLeftThigh,
            .upperRightThigh, .midRightThigh, .lowerRightThigh, .outerRightThigh, .innerRightThigh,
            .upperLeftHamstring, .midLeftHamstring, .lowerLeftHamstring,
            .upperRightHamstring, .midRightHamstring, .lowerRightHamstring,
        ])
        assign("glutes", [
            .leftUpperGlute, .rightUpperGlute, .leftLowerGlute, .rightLowerGlute,
            .leftVentrogluteal, .rightVentrogluteal,
        ])
        assign("arms", [
            .leftDeltoid, .rightDeltoid, .leftPosteriorDeltoid, .rightPosteriorDeltoid,
            .leftUpperArm, .rightUpperArm, .leftTriceps, .rightTriceps,
            .leftForearm, .rightForearm, .leftPosteriorForearm, .rightPosteriorForearm,
            .leftInnerWrist, .rightInnerWrist,
        ])
        assign("upperBody", [
            .neck, .upperChest, .leftUpperChest, .rightUpperChest,
            .leftLowerChest, .rightLowerChest, .leftShoulder, .rightShoulder,
            .upperLeftAbdomen, .upperRightAbdomen, .periumbilical,
            .lowerLeftAbdomen, .lowerRightAbdomen,
        ])
        return map
    }()

    /// Derives view context from camera yaw.
    /// front = -π/4…π/4, right = π/4…3π/4, back = 3π/4…π or -π…-3π/4, left = -3π/4…-π/4
    nonisolated static func viewContext(from yaw: Float) -> String {
        let angle = atan2(sin(yaw), cos(yaw)) // normalize to -π…π
        switch angle {
        case let a where a >= -.pi/4 && a <= .pi/4: return "front"
        case let a where a > .pi/4 && a <= 3 * .pi / 4: return "right"
        case let a where a < -.pi/4 && a >= -3 * .pi / 4: return "left"
        default: return "back"
        }
    }

    // MARK: - Preferred Zones

    /// Clinical consensus on preferred administration sites.
    /// Key: "MedicationName|RouteClass" (e.g. "Testosterone|injection").
    nonisolated static let preferredZones: [String: [String]] = [
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
        // (Progesterone rows removed — unreachable: MedicationType only has
        // estrogen/testosterone cases.)
    ]

    /// Returns the preferred zone labels for a given medication + route class.
    nonisolated static func preferredZones(medication: String, routeClass: RouteClass) -> [String] {
        let key = "\(medication)|\(routeClass.rawValue)"
        return preferredZones[key] ?? []
    }

    // MARK: - Recommended Zones

    /// Anatomically suitable injection/patch/topical zones for each route class.
    nonisolated static func recommendedZones(for routeClass: RouteClass) -> [String] {
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
