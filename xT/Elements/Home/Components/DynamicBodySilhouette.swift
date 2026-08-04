//
//  DynamicBodySilhouette.swift
//  xT
//
//  The animatable body outline shared by the Body Architecture detail view and the
//  body point-cloud constellation.
//
//  Extracted from BodyShapeDetailView, whose own view was unreachable — nothing
//  navigated to it — but which also held this shape and the easing helpers it needs.
//

import SwiftUI

// MARK: - Math Helpers

private func lerpD(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * min(max(t, 0), 1)
}

private func easeD(_ t: Double) -> Double {
    t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}

private func progressD(_ months: Double, start: Double, end: Double) -> Double {
    easeD(min(max((months - start) / (end - start), 0), 1))
}

// MARK: - Animatable Body Silhouette Shape

struct DynamicBodySilhouette: Shape {
    var elapsedMonths: Double

    var animatableData: Double {
        get { elapsedMonths }
        set { elapsedMonths = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Virtual space is 100×120 (matching HTML prototype)
        let vW: CGFloat = 100, vH: CGFloat = 120
        let scale = min(rect.width / vW, rect.height / vH)
        let ox = (rect.width - vW * scale) / 2
        let oy = (rect.height - vH * scale) / 2

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(x) * scale, y: oy + CGFloat(y) * scale)
        }

        let m = elapsedMonths
        let cx = 50.0
        let waistW = lerpD(20, 14, progressD(m, start: 3, end: 20))
        let hipW   = lerpD(24, 34, progressD(m, start: 3, end: 22))
        let bustW  = lerpD(22, 28, progressD(m, start: 2, end: 24))

        var path = Path()
        // Neck/shoulder start — left side
        path.move(to: pt(cx - 8, 10))
        // Left shoulder to bust
        path.addCurve(
            to: pt(cx - bustW, 45),
            control1: pt(cx - 25, 25),
            control2: pt(cx - bustW, 40)
        )
        // Bust to waist
        path.addCurve(
            to: pt(cx - waistW, 70),
            control1: pt(cx - bustW + 2, 55),
            control2: pt(cx - waistW, 65)
        )
        // Waist to hip (left)
        path.addCurve(
            to: pt(cx - 20, 115),
            control1: pt(cx - hipW, 85),
            control2: pt(cx - hipW, 100)
        )
        // Bottom — left to right
        path.addLine(to: pt(cx + 20, 115))
        // Hip to waist (right)
        path.addCurve(
            to: pt(cx + waistW, 70),
            control1: pt(cx + hipW, 100),
            control2: pt(cx + hipW, 85)
        )
        // Waist to bust (right)
        path.addCurve(
            to: pt(cx + bustW, 45),
            control1: pt(cx + waistW, 65),
            control2: pt(cx + bustW - 2, 55)
        )
        // Bust to shoulder (right)
        path.addCurve(
            to: pt(cx + 8, 10),
            control1: pt(cx + bustW, 40),
            control2: pt(cx + 25, 25)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Animatable Body Silhouette Shape (masculinizing)

/// Testosterone counterpart to `DynamicBodySilhouette`. Where the estrogen shape
/// grows a bust and hips while narrowing the waist, this one broadens the
/// shoulders and upper torso from anabolic muscle growth and holds the waist and
/// hips essentially flat — there's no clinical basis in this app's content for
/// claiming hip narrowing or fat redistribution on T, so it isn't animated here.
struct DynamicBodySilhouetteT: Shape {
    var elapsedMonths: Double

    var animatableData: Double {
        get { elapsedMonths }
        set { elapsedMonths = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let vW: CGFloat = 100, vH: CGFloat = 120
        let scale = min(rect.width / vW, rect.height / vH)
        let ox = (rect.width - vW * scale) / 2
        let oy = (rect.height - vH * scale) / 2

        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(x) * scale, y: oy + CGFloat(y) * scale)
        }

        let m = elapsedMonths
        let cx = 50.0
        // Muscle growth is fastest in months 3-12 and largely plateaus by month 24
        // (TimeContentEngine.tMuscleTimeline), so the shoulder/chest broadening
        // ramps over the same window rather than the estrogen shape's 2-3 year arc.
        let shoulderW = lerpD(8, 15, progressD(m, start: 1, end: 14))
        let chestW    = lerpD(19, 24, progressD(m, start: 2, end: 16))
        let waistW    = 20.0
        let hipW      = 21.0

        var path = Path()
        path.move(to: pt(cx - shoulderW, 10))
        // Shoulder to chest
        path.addCurve(
            to: pt(cx - chestW, 42),
            control1: pt(cx - shoulderW - 3, 22),
            control2: pt(cx - chestW - 1, 32)
        )
        // Chest to waist
        path.addCurve(
            to: pt(cx - waistW, 70),
            control1: pt(cx - chestW + 1, 54),
            control2: pt(cx - waistW - 1, 62)
        )
        // Waist to hip (left)
        path.addCurve(
            to: pt(cx - hipW, 115),
            control1: pt(cx - hipW, 85),
            control2: pt(cx - hipW, 100)
        )
        // Bottom — left to right
        path.addLine(to: pt(cx + hipW, 115))
        // Hip to waist (right)
        path.addCurve(
            to: pt(cx + waistW, 70),
            control1: pt(cx + hipW, 100),
            control2: pt(cx + hipW, 85)
        )
        // Waist to chest (right)
        path.addCurve(
            to: pt(cx + chestW, 42),
            control1: pt(cx + waistW + 1, 62),
            control2: pt(cx + chestW - 1, 54)
        )
        // Chest to shoulder (right)
        path.addCurve(
            to: pt(cx + shoulderW, 10),
            control1: pt(cx + chestW + 1, 32),
            control2: pt(cx + shoulderW + 3, 22)
        )
        path.closeSubpath()
        return path
    }
}
