//
//  DetailArmsFront.swift
//  xT
//
//  1:1 detail sketch — arms (anterior view) with 6 zone overlays.
//

import SwiftUI

struct ArmsFrontSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width; let h = rect.height

        // Torso center (narrow)
        p.move(to: CGPoint(x: w * 0.35, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.35, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.50))
        p.closeSubpath()

        // Left arm
        p.move(to: CGPoint(x: w * 0.24, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.80))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.16, y: h * 0.90))
        p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.12))
        p.closeSubpath()

        // Right arm
        p.move(to: CGPoint(x: w * 0.76, y: h * 0.05))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.30))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.80))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.90))
        p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.28))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.12))
        p.closeSubpath()
        return p
    }
}

struct ArmsFrontZoneOverlay: View {
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
        let rects = BodySketchData.zoneBoundingRects["armsFront"] ?? [:]
        GeometryReader { geo in
            ZStack {
                if isHeatMapLoading && !reduceMotionEnabled {
                    Rectangle()
                        .fill(.gray.opacity(0.08))
                        .modifier(ShimmerEffect())
                }
                ForEach(BodySketchData.zoneLabels(for: "armsFront"), id: \.self) { zone in
                    if let rect = rects[zone] {
                        ZoneOverlayView(zone: zone, rect: rect, geo: geo, selectedSites: selectedSites, heatMap: heatMap, recentlyUsedZones: recentlyUsedZones, preferredZones: preferredZones, avoidZones: avoidZones, routeClass: routeClass, activePatchDays: activePatchDays, daysSinceUse: daysSinceUse, nearestPreviewZone: nearestPreviewZone, onTap: onTap, onLongPress: onLongPress)
                    }
                }
            }
        }
    }
}