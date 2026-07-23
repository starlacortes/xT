//
//  ZoneOverlayView.swift
//  xT
//
//  Shared zone overlay rendering used by all 6 detail sketches.
//  Handles: selected badge, heat map fill, preferred border, avoid zone
//  crosshatch, nearest preview pulsing, tap/long-press gestures.
//

import SwiftUI

// MARK: - CVD Pattern Overlay

struct CVDOverlay: View {
    enum Pattern { case dot, diagonal, crosshatch }
    let pattern: Pattern
    let color: Color

    var body: some View {
        Canvas { context, size in
            let p = Path { path in
                switch pattern {
                case .dot:
                    stride(from: 2, to: Int(size.width), by: 6).forEach { x in
                        stride(from: 2, to: Int(size.height), by: 6).forEach { y in
                            path.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                        }
                    }
                case .diagonal:
                    stride(from: -Int(size.height), to: Int(size.width), by: 8).forEach { i in
                        path.move(to: CGPoint(x: Double(i), y: 0))
                        path.addLine(to: CGPoint(x: Double(i) + size.height, y: size.height))
                    }
                case .crosshatch:
                    stride(from: 0, to: Int(size.width), by: 8).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x - Int(size.height), y: Int(size.height)))
                    }
                    stride(from: 0, to: Int(size.width), by: 8).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + Int(size.height), y: Int(size.height)))
                    }
                }
            }
            context.stroke(p, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5))
        }
    }
}

/// Renders a single zone rectangle with contextual styling based on
/// selection state, heat map data, preference status, avoid-zone marking,
/// route-class CVD patterns, active patch tracking, and nearest-preview snap targeting.
struct ZoneOverlayView: View {
    let zone: String
    let rect: CGRect
    let geo: GeometryProxy
    let selectedSites: [(zone: String, index: Int)]
    let heatMap: [String: Int]
    let recentlyUsedZones: Set<String>
    let preferredZones: Set<String>
    let avoidZones: [String: AvoidZoneInfo]
    let routeClass: RouteClass
    let activePatchDays: [String: Int]
    let daysSinceUse: [String: Int]
    let nearestPreviewZone: String?
    let onTap: (CGPoint) -> Void
    let onLongPress: (String) -> Void

    private var absRect: CGRect {
        CGRect(
            x: rect.origin.x * geo.size.width,
            y: rect.origin.y * geo.size.height,
            width: rect.width * geo.size.width,
            height: rect.height * geo.size.height
        )
    }

    private var selected: (zone: String, index: Int)? {
        selectedSites.first(where: { $0.zone == zone })
    }

    private var isPreferred: Bool { preferredZones.contains(zone) }
    private var isRecent: Bool { recentlyUsedZones.contains(zone) }
    private var isAvoided: Bool { avoidZones[zone] != nil }
    private var isNearest: Bool { nearestPreviewZone == zone }
    private var heatCount: Int { heatMap[zone] ?? 0 }
    private var activePatchDay: Int? { activePatchDays[zone] }
    private var daysSinceUsed: Int? { daysSinceUse[zone] }

    private var cvdPattern: CVDOverlay.Pattern {
        switch routeClass {
        case .injection: return .dot
        case .topical:   return .diagonal
        case .patch:     return .crosshatch
        default:         return .dot
        }
    }

    var body: some View {
        ZStack {
            zoneFill

            // Border: dotted for active patch zones, solid otherwise
            if activePatchDay != nil, !isAvoided, selected == nil {
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

            // Selected badge (top-right)
            if let sel = selected {
                CircleBadge(text: "\(sel.index)", color: Theme.Colors.accent)
                    .position(x: absRect.maxX - 14, y: absRect.minY + 14)
            }

            // Avoid icon (top-right)
            if isAvoided {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .position(x: absRect.maxX - 14, y: absRect.minY + 14)
            }

            // Days-since-use badge (top-left)
            if isRecent, let days = daysSinceUsed {
                Text("\(days)d")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray6).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(x: absRect.minX + 14, y: absRect.minY + 14)
            }

            // Active patch "Day N/7" badge (top-left below days badge)
            if let patchDay = activePatchDay, !isAvoided, selected == nil {
                Text("Day \(patchDay)/7")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Theme.Colors.warning)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray6).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .position(
                        x: absRect.minX + 14,
                        y: absRect.minY + (daysSinceUsed != nil ? 28 : 14)
                    )
            }

            // Heat count badge (center)
            if !isAvoided && selected == nil && heatCount >= 2 {
                Text("\(heatCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .position(x: absRect.midX, y: absRect.midY)
            }

            // Topical "Alternate sides" hint
            if routeClass == .topical && !isAvoided && selected == nil && heatCount > 0 {
                Text("Alternate sides")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                    .position(x: absRect.midX, y: absRect.midY + 14)
            }

            // Nearest preview pulse
            if isNearest {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.Colors.accent.opacity(0.6), lineWidth: 2)
                    .scaleEffect(1.05)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: isNearest
                    )
            }
        }
        .frame(width: absRect.width, height: absRect.height)
        .position(x: absRect.midX, y: absRect.midY)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(selected != nil ? "Selected" : "")
        .allowsHitTesting(false)
    }

    private var accessibilityLabel: String {
        if isAvoided, let reason = avoidZones[zone]?.reason, !reason.isEmpty {
            return "\(zone), marked as avoid. Reason: \(reason)"
        } else if isAvoided {
            return "\(zone), marked as avoid"
        } else {
            return "\(zone)"
        }
    }

    private var accessibilityHint: String {
        if isAvoided {
            return "Long press to unmark zone"
        }
        return "Double-tap to select this administration site"
    }

    @ViewBuilder
    private var zoneFill: some View {
        let fill = fillShape
        if !isAvoided && selected == nil && heatCount > 0 {
            fill.overlay(CVDOverlay(pattern: cvdPattern, color: .primary))
        } else {
            fill
        }
    }

    @ViewBuilder
    private var fillShape: some View {
        if selected != nil {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.accent.opacity(0.3))
        } else if isAvoided {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.35))
                .overlay(AvoidCrosshatch())
        } else if heatCount >= 4 {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.accent.opacity(0.5))
        } else if heatCount >= 2 {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.warning.opacity(0.25))
        } else if heatCount == 1 {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.accentSecondary.opacity(0.15))
        } else if isRecent {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.25))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(.clear)
        }
    }
}

/// Small numbered circle badge for multi-site selection.
struct CircleBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 18, height: 18)
            .background(color)
            .clipShape(Circle())
    }
}