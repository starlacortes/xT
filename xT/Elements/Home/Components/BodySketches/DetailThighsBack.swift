//
//  DetailThighsBack.swift
//  xT
//
//  1:1 detail sketch — thighs (posterior view) with 6 hamstring zone overlays.
//

import SwiftUI

// MARK: - Silhouette Shape

struct ThighsBackSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // Left thigh (posterior)
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.02))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.02))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.15))
        p.closeSubpath()

        // Right thigh
        p.move(to: CGPoint(x: w * 0.60, y: h * 0.02))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.02))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.15))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.45))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.20))
        p.closeSubpath()

        return p
    }
}

// MARK: - Zone Overlay View

struct ThighsBackZoneOverlay: View {
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
        BodySketchData.zoneLabels(for: "thighsBack")
    }

    var body: some View {
        let rects = BodySketchData.zoneBoundingRects["thighsBack"] ?? [:]

        GeometryReader { geo in
            ZStack {
                if isHeatMapLoading && !reduceMotionEnabled {
                    Rectangle()
                        .fill(.gray.opacity(0.08))
                        .modifier(ShimmerEffect())
                }

                ForEach(zoneLabels, id: \.self) { zone in
                    if let rect = rects[zone] {
                        zoneOverlay(zone: zone, rect: rect, geo: geo)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zoneOverlay(zone: String, rect: CGRect, geo: GeometryProxy) -> some View {
        let absRect = CGRect(
            x: rect.origin.x * geo.size.width,
            y: rect.origin.y * geo.size.height,
            width: rect.width * geo.size.width,
            height: rect.height * geo.size.height
        )

        let selected = selectedSites.first(where: { $0.zone == zone })
        let isPreferred = preferredZones.contains(zone)
        let isRecent = recentlyUsedZones.contains(zone)
        let isAvoided = avoidZones[zone] != nil
        let isNearest = nearestPreviewZone == zone
        let heatCount = heatMap[zone] ?? 0
        let patchDay = activePatchDays[zone]
        let daysUsed = daysSinceUse[zone]
        let pat: CVDOverlay.Pattern = {
            switch routeClass {
            case .injection: return .dot
            case .topical:   return .diagonal
            case .patch:     return .crosshatch
            default:         return .dot
            }
        }()

        ZStack {
            let fill = fillShape(selected: selected != nil, isAvoided: isAvoided, heatCount: heatCount, isRecent: isRecent)
            if !isAvoided && selected == nil && heatCount > 0 {
                fill.overlay(CVDOverlay(pattern: pat, color: .primary))
            } else {
                fill
            }

            // Border: dotted for active patch zones
            if let _ = patchDay, !isAvoided, selected == nil {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        Theme.Colors.warning,
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isNearest ? Theme.Colors.accent : (
                            isPreferred ? Theme.Colors.warning.opacity(0.15) : Color.gray.opacity(0.15)
                        ),
                        lineWidth: isNearest ? 2 : (isPreferred ? 1 : 0.5)
                    )
            }

            if let sel = selected {
                Text("\(sel.index)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
                    .position(x: absRect.maxX - 14, y: absRect.minY + 14)
            }

            if isAvoided {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .position(x: absRect.maxX - 14, y: absRect.minY + 14)
            }

            // Days-since-use badge (top-left)
            if isRecent, let days = daysUsed {
                Text("\(days)d")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray6).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: absRect.minX + 14, y: absRect.minY + 14)
            }

            // Active patch "Day N/7" badge
            if let pDay = patchDay, !isAvoided, selected == nil {
                Text("Day \(pDay)/7")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Theme.Colors.warning)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray6).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(
                        x: absRect.minX + 14,
                        y: absRect.minY + (daysUsed != nil ? 28 : 14)
                    )
            }

            // Heat count badge (without misleading "d")
            if !isAvoided && selected == nil && heatCount >= 2 {
                Text("\(heatCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .position(x: absRect.midX, y: absRect.midY)
            }

            // Topical "Alternate sides"
            if routeClass == .topical && !isAvoided && selected == nil && heatCount > 0 {
                Text("Alternate sides")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .position(x: absRect.midX, y: absRect.midY + 14)
            }

            if isNearest {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.Colors.accent.opacity(0.6), lineWidth: 2)
                    .scaleEffect(1.05)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isNearest)
            }
        }
        .frame(width: absRect.width, height: absRect.height)
        .position(x: absRect.midX, y: absRect.midY)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func fillShape(selected: Bool, isAvoided: Bool, heatCount: Int, isRecent: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.accent.opacity(0.3))
        } else if isAvoided {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.35))
                .overlay(AvoidCrosshatch())
        } else if heatCount >= 4 {
            RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.accent.opacity(0.5))
        } else if heatCount >= 2 {
            RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.warning.opacity(0.25))
        } else if heatCount == 1 {
            RoundedRectangle(cornerRadius: 6).fill(Theme.Colors.accentSecondary.opacity(0.15))
        } else if isRecent {
            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.25))
        } else {
            RoundedRectangle(cornerRadius: 6).fill(.clear)
        }
    }
}