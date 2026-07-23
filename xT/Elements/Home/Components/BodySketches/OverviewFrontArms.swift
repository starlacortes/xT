//
//  OverviewFrontArms.swift
//  xT
//
//  Full-body front overview (~1:2.5 aspect ratio) with arms emphasis.
//  Tapping arm/shoulder regions navigates to DetailArmsFront.
//

import SwiftUI

struct OverviewFrontArmsSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width; let h = rect.height

        // Head
        let headW = w * 0.18; let headH = h * 0.08
        p.addEllipse(in: CGRect(x: w * 0.41, y: h * 0.01, width: headW, height: headH))

        // Neck
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.12))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.12))
        p.closeSubpath()

        // Torso + arms as single silhouette
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.13))  // left shoulder tip
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.24))  // left arm outer
        p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.52))  // left hand
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.50))  // inner arm
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.32))
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.16))  // armpit
        // Torso left side
        p.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.80),
                   control1: CGPoint(x: w * 0.18, y: h * 0.40),
                   control2: CGPoint(x: w * 0.15, y: h * 0.65))
        // Left leg
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.40))  // crotch
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
        // Torso right side
        p.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.16),
                   control1: CGPoint(x: w * 0.85, y: h * 0.65),
                   control2: CGPoint(x: w * 0.82, y: h * 0.40))
        // Right arm
        p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.32))
        p.addLine(to: CGPoint(x: w * 0.82, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.90, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.96, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.94, y: h * 0.24))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.13))
        p.closeSubpath()
        return p
    }
}

/// Region overlay for navigation from overview → detail sketch
struct OverviewRegionOverlay: View {
    let label: String
    let rect: CGRect
    let geo: GeometryProxy
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        let absRect = CGRect(
            x: rect.origin.x * geo.size.width,
            y: rect.origin.y * geo.size.height,
            width: rect.width * geo.size.width,
            height: rect.height * geo.size.height
        )

        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? Theme.Colors.accent.opacity(0.18) : .clear)
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isHighlighted ? Theme.Colors.accentSecondary.opacity(0.5) : Color.gray.opacity(0.2),
                    lineWidth: 1.5
                )
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHighlighted ? Theme.Colors.accentSecondary : .secondary)
                .position(x: absRect.midX, y: absRect.midY)
        }
        .frame(width: absRect.width, height: absRect.height)
        .position(x: absRect.midX, y: absRect.midY)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct OverviewFrontArmsOverlay: View {
    let onNavigateToDetail: (String) -> Void

    // Region rects for the overview (arms + shoulders)
    private let regions: [(label: String, sketchId: String, rect: CGRect)] = [
        ("Left Arm/Shoulder", "armsFront", CGRect(x: 0.03, y: 0.13, width: 0.25, height: 0.32)),
        ("Right Arm/Shoulder", "armsFront", CGRect(x: 0.72, y: 0.13, width: 0.25, height: 0.32)),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(regions.indices, id: \.self) { i in
                let region = regions[i]
                OverviewRegionOverlay(
                    label: region.label,
                    rect: region.rect,
                    geo: geo,
                    isHighlighted: false,
                    onTap: { onNavigateToDetail(region.sketchId) }
                )
            }
        }
    }
}