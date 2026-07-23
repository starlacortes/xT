//
//  BodySketchData.swift
//  xT
//
//  Static data definitions for body sketch zones: bounding rectangles,
//  preferred zone mappings per medication/route, zone→sketch lookups,
//  avoid zone integration, and hit-testing helpers.
//

import Foundation

/// Pure data — no SwiftUI views. Contains all zone geometry, preferred-zone
/// clinical mappings, and lookup helpers used by BodySitePickerView and
/// individual detail-sketch overlays.
enum BodySketchData {

    // MARK: - Zone Bounding Rectangles

    /// Each entry: (sketchId, zoneLabel) → CGRect where all values
    /// are normalized 0…1 relative to the sketch's coordinate space.
    /// For topical/patch routes on upperBodyFront, rects are ~2× larger
    /// than injection-precision rects (stored separately).
    static let zoneBoundingRects: [String: [String: CGRect]] = [
        // ── Thighs Front (10 zones) ──
        "thighsFront": [
            "Upper Left Thigh":   CGRect(x: 0.05, y: 0.10, width: 0.40, height: 0.25),
            "Upper Right Thigh":  CGRect(x: 0.55, y: 0.10, width: 0.40, height: 0.25),
            "Mid Left Thigh":     CGRect(x: 0.05, y: 0.35, width: 0.40, height: 0.25),
            "Mid Right Thigh":    CGRect(x: 0.55, y: 0.35, width: 0.40, height: 0.25),
            "Lower Left Thigh":   CGRect(x: 0.05, y: 0.60, width: 0.40, height: 0.30),
            "Lower Right Thigh":  CGRect(x: 0.55, y: 0.60, width: 0.40, height: 0.30),
            "Outer Left Thigh":   CGRect(x: 0.02, y: 0.15, width: 0.18, height: 0.70),
            "Outer Right Thigh":  CGRect(x: 0.80, y: 0.15, width: 0.18, height: 0.70),
            "Inner Left Thigh":   CGRect(x: 0.22, y: 0.15, width: 0.18, height: 0.70),
            "Inner Right Thigh":  CGRect(x: 0.60, y: 0.15, width: 0.18, height: 0.70),
        ],

        // ── Thighs Back (6 zones) ──
        "thighsBack": [
            "Upper Left Hamstring":   CGRect(x: 0.05, y: 0.10, width: 0.40, height: 0.25),
            "Upper Right Hamstring":  CGRect(x: 0.55, y: 0.10, width: 0.40, height: 0.25),
            "Mid Left Hamstring":     CGRect(x: 0.05, y: 0.35, width: 0.40, height: 0.25),
            "Mid Right Hamstring":    CGRect(x: 0.55, y: 0.35, width: 0.40, height: 0.25),
            "Lower Left Hamstring":   CGRect(x: 0.05, y: 0.60, width: 0.40, height: 0.30),
            "Lower Right Hamstring":  CGRect(x: 0.55, y: 0.60, width: 0.40, height: 0.30),
        ],

        // ── Glutes Back (6 zones) ──
        "glutesBack": [
            "Left Upper Glute":      CGRect(x: 0.05, y: 0.05, width: 0.40, height: 0.28),
            "Right Upper Glute":     CGRect(x: 0.55, y: 0.05, width: 0.40, height: 0.28),
            "Left Ventrogluteal":    CGRect(x: 0.12, y: 0.35, width: 0.30, height: 0.22),
            "Right Ventrogluteal":   CGRect(x: 0.58, y: 0.35, width: 0.30, height: 0.22),
            "Left Lower Glute":      CGRect(x: 0.08, y: 0.58, width: 0.36, height: 0.28),
            "Right Lower Glute":     CGRect(x: 0.56, y: 0.58, width: 0.36, height: 0.28),
        ],

        // ── Arms Front (6 zones) ──
        "armsFront": [
            "Left Deltoid":       CGRect(x: 0.05, y: 0.05, width: 0.35, height: 0.22),
            "Right Deltoid":      CGRect(x: 0.60, y: 0.05, width: 0.35, height: 0.22),
            "Left Upper Arm":     CGRect(x: 0.08, y: 0.30, width: 0.28, height: 0.30),
            "Right Upper Arm":    CGRect(x: 0.64, y: 0.30, width: 0.28, height: 0.30),
            "Left Forearm":       CGRect(x: 0.10, y: 0.64, width: 0.24, height: 0.28),
            "Right Forearm":      CGRect(x: 0.66, y: 0.64, width: 0.24, height: 0.28),
        ],

        // ── Arms Back (6 zones) ──
        "armsBack": [
            "Left Posterior Deltoid":   CGRect(x: 0.05, y: 0.05, width: 0.35, height: 0.22),
            "Right Posterior Deltoid":  CGRect(x: 0.60, y: 0.05, width: 0.35, height: 0.22),
            "Left Triceps":             CGRect(x: 0.08, y: 0.30, width: 0.28, height: 0.30),
            "Right Triceps":            CGRect(x: 0.64, y: 0.30, width: 0.28, height: 0.30),
            "Left Posterior Forearm":   CGRect(x: 0.10, y: 0.64, width: 0.24, height: 0.28),
            "Right Posterior Forearm":  CGRect(x: 0.66, y: 0.64, width: 0.24, height: 0.28),
        ],

        // ── Upper Body Front (large rects for topical/patch; 13 zones) ──
        "upperBodyFront": [
            "Left Shoulder":        CGRect(x: 0.02, y: 0.02, width: 0.34, height: 0.18),
            "Right Shoulder":       CGRect(x: 0.64, y: 0.02, width: 0.34, height: 0.18),
            "Left Upper Chest":     CGRect(x: 0.10, y: 0.22, width: 0.30, height: 0.16),
            "Right Upper Chest":    CGRect(x: 0.60, y: 0.22, width: 0.30, height: 0.16),
            "Upper Chest":          CGRect(x: 0.28, y: 0.22, width: 0.44, height: 0.16),
            "Left Lower Chest":     CGRect(x: 0.14, y: 0.40, width: 0.26, height: 0.14),
            "Right Lower Chest":    CGRect(x: 0.60, y: 0.40, width: 0.26, height: 0.14),
            "Upper Left Abdomen":   CGRect(x: 0.08, y: 0.56, width: 0.32, height: 0.16),
            "Upper Right Abdomen":  CGRect(x: 0.60, y: 0.56, width: 0.32, height: 0.16),
            "Periumbilical":        CGRect(x: 0.30, y: 0.56, width: 0.40, height: 0.16),
            "Lower Left Abdomen":   CGRect(x: 0.08, y: 0.74, width: 0.32, height: 0.16),
            "Lower Right Abdomen":  CGRect(x: 0.60, y: 0.74, width: 0.32, height: 0.16),
            "Neck":                 CGRect(x: 0.30, y: 0.00, width: 0.40, height: 0.08),
            "Left Inner Wrist":     CGRect(x: 0.05, y: 0.88, width: 0.16, height: 0.08),
            "Right Inner Wrist":    CGRect(x: 0.79, y: 0.88, width: 0.16, height: 0.08),
        ],
    ]

    /// "Precision" versions of upperBodyFront zones for injection routes
    /// (smaller hit targets, roughly half the area).
    static let upperBodyFrontPrecisionRects: [String: CGRect] = [
        "Left Shoulder":        CGRect(x: 0.08, y: 0.04, width: 0.22, height: 0.12),
        "Right Shoulder":       CGRect(x: 0.70, y: 0.04, width: 0.22, height: 0.12),
        "Left Upper Chest":     CGRect(x: 0.16, y: 0.24, width: 0.18, height: 0.10),
        "Right Upper Chest":    CGRect(x: 0.66, y: 0.24, width: 0.18, height: 0.10),
        "Upper Chest":          CGRect(x: 0.34, y: 0.24, width: 0.32, height: 0.10),
        "Left Lower Chest":     CGRect(x: 0.18, y: 0.42, width: 0.16, height: 0.10),
        "Right Lower Chest":    CGRect(x: 0.66, y: 0.42, width: 0.16, height: 0.10),
        "Upper Left Abdomen":   CGRect(x: 0.14, y: 0.58, width: 0.20, height: 0.12),
        "Upper Right Abdomen":  CGRect(x: 0.66, y: 0.58, width: 0.20, height: 0.12),
        "Periumbilical":        CGRect(x: 0.34, y: 0.58, width: 0.32, height: 0.12),
        "Lower Left Abdomen":   CGRect(x: 0.14, y: 0.75, width: 0.20, height: 0.12),
        "Lower Right Abdomen":  CGRect(x: 0.66, y: 0.75, width: 0.20, height: 0.12),
        "Neck":                 CGRect(x: 0.34, y: 0.00, width: 0.32, height: 0.06),
        "Left Inner Wrist":     CGRect(x: 0.10, y: 0.88, width: 0.10, height: 0.06),
        "Right Inner Wrist":    CGRect(x: 0.80, y: 0.88, width: 0.10, height: 0.06),
    ]

    // MARK: - Zone → Sketch Mapping

    /// Maps every zone label back to its parent sketch ID.
    /// Used by the avoid-zone editor and export to locate zones on sketches.
    static let zoneToSketch: [String: String] = [
        // Thighs Front
        "Upper Left Thigh":  "thighsFront", "Upper Right Thigh":  "thighsFront",
        "Mid Left Thigh":    "thighsFront", "Mid Right Thigh":    "thighsFront",
        "Lower Left Thigh":  "thighsFront", "Lower Right Thigh":  "thighsFront",
        "Outer Left Thigh":  "thighsFront", "Outer Right Thigh":  "thighsFront",
        "Inner Left Thigh":  "thighsFront", "Inner Right Thigh":  "thighsFront",
        // Thighs Back
        "Upper Left Hamstring":  "thighsBack", "Upper Right Hamstring":  "thighsBack",
        "Mid Left Hamstring":    "thighsBack", "Mid Right Hamstring":    "thighsBack",
        "Lower Left Hamstring":  "thighsBack", "Lower Right Hamstring":  "thighsBack",
        // Glutes Back
        "Left Upper Glute":    "glutesBack", "Right Upper Glute":    "glutesBack",
        "Left Ventrogluteal":  "glutesBack", "Right Ventrogluteal":  "glutesBack",
        "Left Lower Glute":    "glutesBack", "Right Lower Glute":    "glutesBack",
        // Arms Front
        "Left Deltoid":    "armsFront", "Right Deltoid":    "armsFront",
        "Left Upper Arm":  "armsFront", "Right Upper Arm":  "armsFront",
        "Left Forearm":    "armsFront", "Right Forearm":    "armsFront",
        // Arms Back
        "Left Posterior Deltoid":   "armsBack", "Right Posterior Deltoid":   "armsBack",
        "Left Triceps":             "armsBack", "Right Triceps":             "armsBack",
        "Left Posterior Forearm":   "armsBack", "Right Posterior Forearm":   "armsBack",
        // Upper Body Front
        "Left Shoulder":        "upperBodyFront", "Right Shoulder":        "upperBodyFront",
        "Left Upper Chest":     "upperBodyFront", "Right Upper Chest":     "upperBodyFront",
        "Upper Chest":          "upperBodyFront",
        "Left Lower Chest":     "upperBodyFront", "Right Lower Chest":     "upperBodyFront",
        "Upper Left Abdomen":   "upperBodyFront", "Upper Right Abdomen":   "upperBodyFront",
        "Periumbilical":        "upperBodyFront",
        "Lower Left Abdomen":   "upperBodyFront", "Lower Right Abdomen":   "upperBodyFront",
        "Neck":                 "upperBodyFront",
        "Left Inner Wrist":     "upperBodyFront", "Right Inner Wrist":    "upperBodyFront",
    ]

    // MARK: - Sketch Metadata

    /// 1:1 aspect ratio for all detail sketches.
    static let sketchAspectRatios: [String: CGFloat] = [
        "thighsFront": 1.0, "thighsBack": 1.0,
        "glutesBack": 1.0,
        "armsFront": 1.0, "armsBack": 1.0,
        "upperBodyFront": 1.0,
    ]

    /// Which anatomical view each sketch represents.
    static let sketchViewContext: [String: String] = [
        "thighsFront": "front", "thighsBack": "back",
        "glutesBack": "back",
        "armsFront": "front", "armsBack": "back",
        "upperBodyFront": "front",
    ]

    /// Map a sketch ID to the body region it covers.
    static let sketchToRegion: [String: String] = [
        "thighsFront": "thighs", "thighsBack": "thighs",
        "glutesBack": "glutes",
        "armsFront": "arms", "armsBack": "arms",
        "upperBodyFront": "upperBody",
    ]

    // MARK: - Preferred Zones per (Medication, Route)

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
        "Testosterone|oral": [],  // oral → no site tracking

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

    // MARK: - Helpers

    /// Returns the preferred zone labels for a given medication + route class.
    static func preferredZones(medication: String, routeClass: RouteClass) -> [String] {
        let key = "\(medication)|\(routeClass.rawValue)"
        return preferredZones[key] ?? []
    }

    /// Returns the zone label at a tapped normalized point within a sketch,
    /// or nil if the tap landed in dead space. Smallest-area zones are
    /// checked first so overlapping rects resolve predictably.
    static func zoneLabel(
        forTap point: CGPoint,
        sketchId: String,
        routeClass: RouteClass
    ) -> String? {
        let rects: [String: CGRect]
        if sketchId == "upperBodyFront" && routeClass.requiresPreciseTap {
            rects = upperBodyFrontPrecisionRects
        } else {
            rects = zoneBoundingRects[sketchId] ?? [:]
        }

        // Sort by area ascending — smallest zones take precedence
        let sorted = rects.sorted {
            ($0.value.width * $0.value.height) < ($1.value.width * $1.value.height)
        }
        for (label, rect) in sorted {
            if rect.contains(point) { return label }
        }
        return nil
    }

    /// Returns the nearest zone and its centroid for a dead-space tap,
    /// used by the snap-to-zone feature and nearest-preview label.
    static func nearestZone(
        to point: CGPoint,
        sketchId: String,
        routeClass: RouteClass
    ) -> (label: String, centroid: CGPoint)? {
        let rects: [String: CGRect]
        if sketchId == "upperBodyFront" && routeClass.requiresPreciseTap {
            rects = upperBodyFrontPrecisionRects
        } else {
            rects = zoneBoundingRects[sketchId] ?? [:]
        }
        guard !rects.isEmpty else { return nil }

        var closest: (label: String, centroid: CGPoint, distance: CGFloat)?
        for (label, rect) in rects {
            let centroid = CGPoint(x: rect.midX, y: rect.midY)
            let dist = sqrt(
                pow(point.x - centroid.x, 2) +
                pow(point.y - centroid.y, 2)
            )
            if closest == nil || dist < closest!.distance {
                closest = (label, centroid, dist)
            }
        }
        return closest.map { ($0.label, $0.centroid) }
    }

    /// Returns the sketch ID that contains a given zone label.
    /// Useful for the avoid-zone editor and export to cross-reference zones.
    static func sketchId(for zoneLabel: String) -> String? {
        return zoneToSketch[zoneLabel]
    }

    /// Returns the bounding rect centroid for a specific zone label within a sketch.
    /// Used to snap in-zone taps to the zone centroid when snap-to-zone is active.
    static func zoneCentroid(
        for label: String,
        sketchId: String,
        routeClass: RouteClass
    ) -> CGPoint? {
        let rects: [String: CGRect]
        if sketchId == "upperBodyFront" && routeClass.requiresPreciseTap {
            rects = upperBodyFrontPrecisionRects
        } else {
            rects = zoneBoundingRects[sketchId] ?? [:]
        }
        guard let rect = rects[label] else { return nil }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// Returns all zone labels for a given sketch.
    static func zoneLabels(for sketchId: String) -> [String] {
        // Merge standard + precision rects so all zones available.
        let standard = zoneBoundingRects[sketchId] ?? [:]
        guard sketchId == "upperBodyFront" else {
            return Array(standard.keys)
        }
        var all = Set(standard.keys)
        all.formUnion(upperBodyFrontPrecisionRects.keys)
        return Array(all)
    }
}