//
//  DetailUpperBodyFront.swift
//  xT
//
//  1:1 detail sketch — upper body (anterior torso) with 13 zone overlays.
//  Uses larger rects for topical/patch via BodySketchData.zoneBoundingRects
//  or precision rects for injection via upperBodyFrontPrecisionRects.
//

import SwiftUI

struct UpperBodyFrontSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width; let h = rect.height

        // Neck
        p.move(to: CGPoint(x: w * 0.38, y: h * -0.02))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * -0.02))
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.06))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.06))
        p.closeSubpath()

        // Torso
        p.move(to: CGPoint(x: w * 0.10, y: h * 0.04))
        // Left shoulder curve
        p.addCurve(to: CGPoint(x: w * 0.02, y: h * 0.35),
                   control1: CGPoint(x: w * 0.02, y: h * 0.08),
                   control2: CGPoint(x: w * 0.01, y: h * 0.20))
        // Left waist taper
        p.addCurve(to: CGPoint(x: w * 0.14, y: h * 0.92),
                   control1: CGPoint(x: w * 0.05, y: h * 0.60),
                   control2: CGPoint(x: w * 0.08, y: h * 0.80))
        p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.92))
        // Right waist taper
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.35),
                   control1: CGPoint(x: w * 0.92, y: h * 0.80),
                   control2: CGPoint(x: w * 0.95, y: h * 0.60))
        // Right shoulder curve
        p.addCurve(to: CGPoint(x: w * 0.90, y: h * 0.04),
                   control1: CGPoint(x: w * 0.99, y: h * 0.20),
                   control2: CGPoint(x: w * 0.98, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.04))
        p.closeSubpath()
        return p
    }
}

struct UpperBodyFrontZoneOverlay: View {
    let selectedSites: [(zone: String, index: Int)]
    let heatMap: [String: Int]
    let recentlyUsedZones: Set<String>
    let preferredZones: Set<String>
    let avoidZones: [String: AvoidZoneInfo]
    let routeClass: RouteClass
    let isHeatMapLoading: Bool
    let reduceMotionEnabled: Bool
    let activePatchDays: [String: Int]
    let daysSinceUse: [String: Int]
    let nearestPreviewZone: String?
    let onTap: (CGPoint) -> Void
    let onLongPress: (String) -> Void

    var body: some View {
        let usePrecision = routeClass.requiresPreciseTap
        let rects: [String: CGRect] = usePrecision
            ? BodySketchData.upperBodyFrontPrecisionRects
            : (BodySketchData.zoneBoundingRects["upperBodyFront"] ?? [:])

        GeometryReader { geo in
            ZStack {
                if isHeatMapLoading && !reduceMotionEnabled {
                    Rectangle()
                        .fill(.gray.opacity(0.08))
                        .modifier(ShimmerEffect())
                }
                ForEach(BodySketchData.zoneLabels(for: "upperBodyFront"), id: \.self) { zone in
                    if let rect = rects[zone] {
                        ZoneOverlayView(
                            zone: zone, rect: rect, geo: geo,
                            selectedSites: selectedSites,
                            heatMap: heatMap,
                            recentlyUsedZones: recentlyUsedZones,
                            preferredZones: preferredZones,
                            avoidZones: avoidZones,
                            routeClass: routeClass,
                            activePatchDays: activePatchDays,
                            daysSinceUse: daysSinceUse,
                            nearestPreviewZone: nearestPreviewZone,
                            onTap: onTap, onLongPress: onLongPress
                        )
                    }
                }
            }
        }
    }
}