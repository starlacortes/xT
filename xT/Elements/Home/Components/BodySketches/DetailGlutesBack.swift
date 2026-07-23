//
//  DetailGlutesBack.swift
//  xT
//
//  1:1 detail sketch — glutes (posterior view) with 6 zone overlays.
//

import SwiftUI

// MARK: - Silhouette Shape

struct GlutesBackSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // Simplified gluteal silhouette — two rounded forms with cleft
        // Left glute
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.05))
        p.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.02),
                   control1: CGPoint(x: w * 0.12, y: h * -0.02),
                   control2: CGPoint(x: w * 0.38, y: h * -0.01))
        p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.96))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.94))
        p.addLine(to: CGPoint(x: w * 0.02, y: h * 0.55))
        p.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.05),
                   control1: CGPoint(x: w * 0.04, y: h * 0.30),
                   control2: CGPoint(x: w * 0.06, y: h * 0.10))
        p.closeSubpath()

        // Right glute
        p.move(to: CGPoint(x: w * 0.58, y: h * 0.02))
        p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.05),
                   control1: CGPoint(x: w * 0.62, y: h * -0.01),
                   control2: CGPoint(x: w * 0.88, y: h * -0.02))
        p.addCurve(to: CGPoint(x: w * 0.98, y: h * 0.55),
                   control1: CGPoint(x: w * 0.94, y: h * 0.10),
                   control2: CGPoint(x: w * 0.96, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.94))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.96))
        p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.28))
        p.closeSubpath()

        return p
    }
}

// MARK: - Zone Overlay View

struct GlutesBackZoneOverlay: View {
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

    private var zoneLabels: [String] {
        BodySketchData.zoneLabels(for: "glutesBack")
    }

    var body: some View {
        let rects = BodySketchData.zoneBoundingRects["glutesBack"] ?? [:]

        GeometryReader { geo in
            ZStack {
                if isHeatMapLoading && !reduceMotionEnabled {
                    Rectangle()
                        .fill(.gray.opacity(0.08))
                        .modifier(ShimmerEffect())
                }

                ForEach(zoneLabels, id: \.self) { zone in
                    if let rect = rects[zone] {
                        ZoneOverlayView(
                            zone: zone,
                            rect: rect,
                            geo: geo,
                            selectedSites: selectedSites,
                            heatMap: heatMap,
                            recentlyUsedZones: recentlyUsedZones,
                            preferredZones: preferredZones,
                            avoidZones: avoidZones,
                            routeClass: routeClass,
                            activePatchDays: activePatchDays,
                            daysSinceUse: daysSinceUse,
                            nearestPreviewZone: nearestPreviewZone,
                            onTap: onTap,
                            onLongPress: onLongPress
                        )
                    }
                }
            }
        }
    }

}