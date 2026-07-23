//
//  OverviewBackMidsection.swift
//  xT
//
//  Full-body back overview — glutes + thighs emphasis.
//  Tapping thighs navigates to DetailThighsBack;
//  tapping glutes navigates to DetailGlutesBack.
//

import SwiftUI

struct OverviewBackMidsectionSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width; let h = rect.height
        let headW = w * 0.18; let headH = h * 0.08
        p.addEllipse(in: CGRect(x: w * 0.41, y: h * 0.01, width: headW, height: headH))
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.08))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.12))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.12))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.08, y: h * 0.13))
        p.addLine(to: CGPoint(x: w * 0.06, y: h * 0.24))
        p.addLine(to: CGPoint(x: w * 0.04, y: h * 0.35))
        p.addLine(to: CGPoint(x: w * 0.08, y: h * 0.46))
        p.addLine(to: CGPoint(x: w * 0.10, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.18, y: h * 0.50))
        p.addLine(to: CGPoint(x: w * 0.20, y: h * 0.32))
        p.addLine(to: CGPoint(x: w * 0.24, y: h * 0.20))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.16))
        p.addCurve(to: CGPoint(x: w * 0.22, y: h * 0.80),
                   control1: CGPoint(x: w * 0.18, y: h * 0.40),
                   control2: CGPoint(x: w * 0.15, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.40))
        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.65))
        p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.70, y: h * 0.98))
        p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.80))
        p.addCurve(to: CGPoint(x: w * 0.72, y: h * 0.16),
                   control1: CGPoint(x: w * 0.85, y: h * 0.65),
                   control2: CGPoint(x: w * 0.82, y: h * 0.40))
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

struct OverviewBackMidsectionOverlay: View {
    let onNavigateToDetail: (String) -> Void

    private let regions: [(label: String, sketchId: String, rect: CGRect)] = [
        ("Glutes", "glutesBack", CGRect(x: 0.15, y: 0.18, width: 0.70, height: 0.18)),
        ("Left Thigh (Back)",  "thighsBack", CGRect(x: 0.08, y: 0.42, width: 0.34, height: 0.54)),
        ("Right Thigh (Back)", "thighsBack", CGRect(x: 0.58, y: 0.42, width: 0.34, height: 0.54)),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(regions.indices, id: \.self) { i in
                let r = regions[i]
                OverviewRegionOverlay(label: r.label, rect: r.rect, geo: geo, isHighlighted: false, onTap: { onNavigateToDetail(r.sketchId) })
            }
        }
    }
}