//
//  IsoclineWordmarkRevealView.swift
//  xT
//
//  The launch reveal — a port of the ISOCLINE_I_TO_WORD draft. The "I." stands
//  centred and large; it recedes in depth and to the left while SOCLINE is
//  revealed from behind it, until the lockup is whole. Then the word lets go and
//  the app is already there.
//
//  · The word is only ever the master outline (F7), split into the I glyph, the
//    point, and SOCLINE — never live text.
//  · The I.'s move is slow at first, quick through the middle, slower as it
//    settles (asymmetric ease, longer tail). SOCLINE stays hidden wherever it
//    sits behind the I. (clipped). Day paper cream, night paper seed-hued —
//    both resolve from Theme.Colors, so the dial and appearance just work.
//  · Reduce Motion: the finished lockup, still. Tap: skip to the settle.
//  · The reveal waits out the app lock so its moment isn't spent unseen, and
//    fires `onFinished` once only paper remains — the caller removes the layer
//    over matching paper, so the handoff is seamless.
//

import SwiftUI

// MARK: - The word, in pieces

/// The wordmark master split into the three pieces the reveal animates, plus
/// the font-unit geometry its choreography needs. The path bodies mirror the
/// same generated data `IsoclineMarkPaths` emits (F7 / build_isocline_marks.py)
/// — if the masters are ever regenerated, refresh them here to match.
enum IsoclineWordmarkParts {

    // Geometry — font units, y-down (F7).

    /// The wordmark's optical centre (its viewBox centre).
    static let wordCenter = CGPoint(x: IsoclineMarkPaths.wordmarkViewBox.midX,
                                    y: IsoclineMarkPaths.wordmarkViewBox.midY)

    /// The "I." mark's optical centre (its square viewBox centre — font x 319).
    static let markCenter = CGPoint(x: IsoclineMarkPaths.markViewBox.midX,
                                    y: IsoclineMarkPaths.markViewBox.midY)

    /// The I glyph's edges in the wordmark, and SOCLINE's move point.
    static let iGlyphLeft: CGFloat = 45
    static let iGlyphRight: CGFloat = 327
    static let soclineLeft: CGFloat = 754

    /// The I glyph's right edge, measured from the mark centre (8 units) —
    /// tracks the mark's recession, so it is the reveal edge for SOCLINE.
    static var iGlyphRightFromMarkCenter: CGFloat { iGlyphRight - markCenter.x }

    /// The point of the "I." — a true circle, on its own so it can dissolve.
    static let dotCenter = CGPoint(x: 511, y: -82)
    static let dotRadius: CGFloat = 82

    /// The whole word's width in font units.
    static var wordWidth: CGFloat { IsoclineMarkPaths.wordmarkViewBox.width }

    /// The wordmark's first subpath — the I glyph.
    static let iGlyph: Path = {
        var p = Path()
        p.move(to: pt(45, 0))
        p.addLine(to: pt(327, 0))
        p.addLine(to: pt(327, -60))
        p.addLine(to: pt(256, -60))
        p.addLine(to: pt(256, -638))
        p.addLine(to: pt(327, -638))
        p.addLine(to: pt(327, -698))
        p.addLine(to: pt(45, -698))
        p.addLine(to: pt(45, -638))
        p.addLine(to: pt(116, -638))
        p.addLine(to: pt(116, -60))
        p.addLine(to: pt(45, -60))
        p.closeSubpath()
        return p
    }()

    /// Every wordmark subpath after the I — "SOCLINE".
    static let socline: Path = {
        var p = Path()
        p.move(to: pt(754, 12))
        p.addCurve(to: pt(1003, -203), control1: pt(909, 12), control2: pt(1003, -79))
        p.addCurve(to: pt(791, -418), control1: pt(1003, -325), control2: pt(925, -388))
        p.addLine(to: pt(746, -427))
        p.addCurve(to: pt(615, -540), control1: pt(652, -449), control2: pt(615, -476))
        p.addCurve(to: pt(749, -642), control1: pt(615, -597), control2: pt(658, -642))
        p.addCurve(to: pt(887, -541), control1: pt(837, -642), control2: pt(887, -610))
        p.addLine(to: pt(887, -497))
        p.addLine(to: pt(990, -497))
        p.addLine(to: pt(990, -698))
        p.addLine(to: pt(887, -698))
        p.addLine(to: pt(887, -642))
        p.addLine(to: pt(883, -642))
        p.addCurve(to: pt(736, -710), control1: pt(866, -675), control2: pt(817, -710))
        p.addCurve(to: pt(504, -512), control1: pt(591, -710), control2: pt(504, -629))
        p.addCurve(to: pt(723, -288), control1: pt(504, -379), control2: pt(590, -316))
        p.addLine(to: pt(771, -277))
        p.addCurve(to: pt(887, -167), control1: pt(858, -258), control2: pt(887, -229))
        p.addCurve(to: pt(743, -56), control1: pt(887, -100), control2: pt(841, -56))
        p.addCurve(to: pt(599, -160), control1: pt(648, -56), control2: pt(599, -91))
        p.addLine(to: pt(599, -204))
        p.addLine(to: pt(496, -204))
        p.addLine(to: pt(496, 0))
        p.addLine(to: pt(599, 0))
        p.addLine(to: pt(599, -59))
        p.addLine(to: pt(603, -59))
        p.addCurve(to: pt(754, 12), control1: pt(621, -24), control2: pt(672, 12))
        p.closeSubpath()
        p.move(to: pt(1502, -56))
        p.addCurve(to: pt(1334, -253), control1: pt(1404, -56), control2: pt(1334, -123))
        p.addLine(to: pt(1334, -445))
        p.addCurve(to: pt(1502, -642), control1: pt(1334, -575), control2: pt(1404, -642))
        p.addCurve(to: pt(1670, -445), control1: pt(1600, -642), control2: pt(1670, -575))
        p.addLine(to: pt(1670, -253))
        p.addCurve(to: pt(1502, -56), control1: pt(1670, -123), control2: pt(1600, -56))
        p.closeSubpath()
        p.move(to: pt(1502, 12))
        p.addCurve(to: pt(1824, -349), control1: pt(1689, 12), control2: pt(1824, -120))
        p.addCurve(to: pt(1502, -710), control1: pt(1824, -578), control2: pt(1689, -710))
        p.addCurve(to: pt(1180, -349), control1: pt(1315, -710), control2: pt(1180, -578))
        p.addCurve(to: pt(1502, 12), control1: pt(1180, -120), control2: pt(1315, 12))
        p.closeSubpath()
        p.move(to: pt(2303, 12))
        p.addCurve(to: pt(2560, -169), control1: pt(2438, 12), control2: pt(2529, -74))
        p.addLine(to: pt(2509, -198))
        p.addCurve(to: pt(2329, -72), control1: pt(2479, -122), control2: pt(2416, -72))
        p.addCurve(to: pt(2152, -267), control1: pt(2223, -72), control2: pt(2152, -137))
        p.addLine(to: pt(2152, -446))
        p.addCurve(to: pt(2312, -641), control1: pt(2152, -569), control2: pt(2208, -641))
        p.addCurve(to: pt(2451, -528), control1: pt(2400, -641), control2: pt(2451, -595))
        p.addLine(to: pt(2451, -481))
        p.addLine(to: pt(2554, -481))
        p.addLine(to: pt(2554, -698))
        p.addLine(to: pt(2451, -698))
        p.addLine(to: pt(2451, -639))
        p.addLine(to: pt(2446, -639))
        p.addCurve(to: pt(2293, -710), control1: pt(2428, -674), control2: pt(2379, -710))
        p.addCurve(to: pt(1998, -348), control1: pt(2132, -710), control2: pt(1998, -583))
        p.addCurve(to: pt(2303, 12), control1: pt(1998, -140), control2: pt(2111, 12))
        p.closeSubpath()
        p.move(to: pt(2716, 0))
        p.addLine(to: pt(3240, 0))
        p.addLine(to: pt(3240, -197))
        p.addLine(to: pt(3137, -197))
        p.addLine(to: pt(3137, -65))
        p.addLine(to: pt(2927, -65))
        p.addLine(to: pt(2927, -638))
        p.addLine(to: pt(3002, -638))
        p.addLine(to: pt(3002, -698))
        p.addLine(to: pt(2716, -698))
        p.addLine(to: pt(2716, -638))
        p.addLine(to: pt(2787, -638))
        p.addLine(to: pt(2787, -60))
        p.addLine(to: pt(2716, -60))
        p.closeSubpath()
        p.move(to: pt(3388, 0))
        p.addLine(to: pt(3670, 0))
        p.addLine(to: pt(3670, -60))
        p.addLine(to: pt(3599, -60))
        p.addLine(to: pt(3599, -638))
        p.addLine(to: pt(3670, -638))
        p.addLine(to: pt(3670, -698))
        p.addLine(to: pt(3388, -698))
        p.addLine(to: pt(3388, -638))
        p.addLine(to: pt(3459, -638))
        p.addLine(to: pt(3459, -60))
        p.addLine(to: pt(3388, -60))
        p.closeSubpath()
        p.move(to: pt(3830, 0))
        p.addLine(to: pt(4044, 0))
        p.addLine(to: pt(4044, -60))
        p.addLine(to: pt(3973, -60))
        p.addLine(to: pt(3973, -587))
        p.addLine(to: pt(3978, -587))
        p.addLine(to: pt(4336, 0))
        p.addLine(to: pt(4459, 0))
        p.addLine(to: pt(4459, -638))
        p.addLine(to: pt(4530, -638))
        p.addLine(to: pt(4530, -698))
        p.addLine(to: pt(4316, -698))
        p.addLine(to: pt(4316, -638))
        p.addLine(to: pt(4387, -638))
        p.addLine(to: pt(4387, -182))
        p.addLine(to: pt(4382, -182))
        p.addLine(to: pt(4070, -698))
        p.addLine(to: pt(3830, -698))
        p.addLine(to: pt(3830, -638))
        p.addLine(to: pt(3901, -638))
        p.addLine(to: pt(3901, -60))
        p.addLine(to: pt(3830, -60))
        p.closeSubpath()
        p.move(to: pt(4687, 0))
        p.addLine(to: pt(5240, 0))
        p.addLine(to: pt(5240, -197))
        p.addLine(to: pt(5137, -197))
        p.addLine(to: pt(5137, -65))
        p.addLine(to: pt(4898, -65))
        p.addLine(to: pt(4898, -330))
        p.addLine(to: pt(5050, -330))
        p.addLine(to: pt(5050, -264))
        p.addLine(to: pt(5119, -264))
        p.addLine(to: pt(5119, -461))
        p.addLine(to: pt(5050, -461))
        p.addLine(to: pt(5050, -395))
        p.addLine(to: pt(4898, -395))
        p.addLine(to: pt(4898, -633))
        p.addLine(to: pt(5129, -633))
        p.addLine(to: pt(5129, -517))
        p.addLine(to: pt(5232, -517))
        p.addLine(to: pt(5232, -698))
        p.addLine(to: pt(4687, -698))
        p.addLine(to: pt(4687, -638))
        p.addLine(to: pt(4758, -638))
        p.addLine(to: pt(4758, -60))
        p.addLine(to: pt(4687, -60))
        p.closeSubpath()
        return p
    }()

    /// The point of the "I.".
    static let dot: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: dotCenter.x - dotRadius,
                                y: dotCenter.y - dotRadius,
                                width: dotRadius * 2,
                                height: dotRadius * 2))
        return p
    }()
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x, y: y)
}

// MARK: - Small math (ported from the draft)

private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
    min(max(value, low), high)
}

private func seg(_ k: Double, _ from: Double, _ to: Double) -> Double {
    clamp((k - from) / (to - from), 0, 1)
}

private func smootherstep(_ t: Double) -> Double {
    let t = clamp(t, 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
}

private func lerp(_ from: Double, _ to: Double, _ fraction: Double) -> Double {
    from + (to - from) * fraction
}

// MARK: - Reveal view

/// The launch reveal, played once over the paper ground. `onFinished` fires when
/// the word has let go and only paper remains — the caller can then remove the
/// layer; its paper matches the app's, so the swap is invisible.
struct IsoclineWordmarkRevealView: View {
    /// Fires once the reveal is over (lockup faded back to paper).
    var onFinished: () -> Void = {}
    /// Debug/preview: when set, hold this frame of the draft's timeline
    /// instead of playing (the draft's `#t=` + `&freeze=1`).
    var freezeAt: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.authenticationManager) private var authManager
    @State private var startedAt: Date?

    // The draft's timeline, in seconds. tMove carries the whole story.
    private static let tIn = 0.55            // "I." arrives
    private static let tHold0 = 0.75
    private static let tMove = 1.25          // the move
    private static let tHold1 = 1.2          // the whole lockup, at rest
    private static let tOut = 0.5            // the word lets go
    private static var t1: Double { tIn + tHold0 }            // 1.30 — move starts
    private static var t2: Double { t1 + tMove }              // 2.55 — move ends
    private static var t3: Double { t2 + tHold1 }             // 3.75 — let-go starts
    private static var t4: Double { t3 + tOut }                // 4.25 — only paper
    /// Reduce Motion: the draft's frozen frame — the finished lockup, still.
    private static var rmK: Double { t2 + 0.6 }
    /// How long the still lockup is held under Reduce Motion.
    private static let rmHold = 1.2

    /// How large the "I." stands before it recedes in depth.
    private static let scale0: CGFloat = 1.45
    /// The move: slow start, quick middle, slower settle (longer tail) —
    /// the draft's cubic-bezier(0.5, 0, 0.3, 1).
    private static let moveCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.5, y: 0),
                                                     endControlPoint: UnitPoint(x: 0.3, y: 1))

    var body: some View {
        if let freezeAt {
            canvas(k: reduceMotion ? Self.rmK : freezeAt)
        } else {
            TimelineView(.animation(paused: startedAt == nil)) { timeline in
                canvas(k: k(at: timeline.date))
                    .onChange(of: elapsed(at: timeline.date) >= doneAt) { _, done in
                        if done { onFinished() }
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: skip)
            .onAppear(perform: startIfUnlocked)
            .onChange(of: authManager.showAuthentication) { _, showing in
                // The lock came down (or cleared) — the reveal only begins
                // once the lock screen is out of the way.
                if !showing { startIfUnlocked() }
            }
        }
    }

    /// The canvas isn't a11y-relevant: the reveal is a transient brand moment,
    /// and Reduce Motion users get the same lockup statically.
    private func canvas(k: Double) -> some View {
        Canvas { context, size in
            draw(&context, size: size, k: k)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Isocline")
    }

    // MARK: - Clock

    private func startIfUnlocked() {
        guard startedAt == nil, !authManager.showAuthentication else { return }
        startedAt = Date()
    }

    private func elapsed(at date: Date) -> Double {
        guard let startedAt else { return 0 }
        return max(0, date.timeIntervalSince(startedAt))
    }

    /// The draft's clock: elapsed time, clamped to the end. Under Reduce
    /// Motion it always reads the frozen settled frame.
    private func k(at date: Date) -> Double {
        if reduceMotion { return Self.rmK }
        return min(elapsed(at: date), Self.t4)
    }

    private var doneAt: Double {
        reduceMotion ? Self.rmHold : Self.t4
    }

    /// Tap: jump to the settle and let the lockup let go naturally.
    private func skip() {
        guard let start = startedAt else { return }
        let now = Date().timeIntervalSince(start)
        if now < Self.t3 {
            startedAt = start.addingTimeInterval(now - Self.t3)
        }
    }

    // MARK: - The frame at k (the draft's frame(), ported)

    private func draw(_ context: inout GraphicsContext, size: CGSize, k: Double) {
        let paper = Theme.Colors.appBackground
        let ink = Theme.Colors.textPrimary

        // Fit (the draft's layout rule): as wide as 62% of the canvas,
        // clamped to the wordmark's comfortable range, centred.
        let width = max(96, min(size.width * 0.62, 640))
        let s = width / IsoclineWordmarkParts.wordWidth
        let cx = size.width / 2, cy = size.height / 2
        func x(_ fontX: CGFloat) -> CGFloat { cx + (fontX - IsoclineWordmarkParts.wordCenter.x) * s }
        func y(_ fontY: CGFloat) -> CGFloat { cy + (fontY - IsoclineWordmarkParts.wordCenter.y) * s }

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))

        // The move drives everything: slow start, quick middle, slower settle.
        let move = Self.moveCurve.value(at: seg(k, Self.t1, Self.t2))
        let initialDrift = IsoclineWordmarkParts.wordCenter.x - IsoclineWordmarkParts.markCenter.x
        let drift = initialDrift * (1 - move)                 // the I's carry left
        let markScale = CGFloat(lerp(Self.scale0, 1, move))    // ...and recession in depth
        let markCenterX = IsoclineWordmarkParts.markCenter.x + drift
        // SOCLINE starts tucked at the I's right edge and slides to its rest.
        let soclineLeft = lerp(Double(IsoclineWordmarkParts.iGlyphLeft + initialDrift + IsoclineWordmarkParts.iGlyphRight),
                               Double(IsoclineWordmarkParts.soclineLeft), move)

        let arrival = smootherstep(seg(k, 0, Self.tIn))
        let letGo = 1 - smootherstep(seg(k, Self.t3, Self.t4))
        let all = arrival * letGo
        let dot = all * (1 - smootherstep(seg(k, Self.t1, Self.t2)))          // the point dissolves as the word forms
        let word = all * smootherstep(seg(k, Self.t1, Self.t1 + Self.tMove * 0.7)) // SOCLINE fades in with the slide

        // SOCLINE — behind the receding I., clipped so it never shows where
        // the mark hides it. The clip tracks the I's right edge as it shrinks.
        if word > 0.004 {
            let clipLeft = x(markCenterX + IsoclineWordmarkParts.iGlyphRightFromMarkCenter * markScale)
            if clipLeft < size.width {
                let socline = IsoclineWordmarkParts.socline
                    .applying(Self.fontTransform(pivot: CGPoint(x: IsoclineWordmarkParts.soclineLeft, y: 0),
                                                 screenPivot: CGPoint(x: x(soclineLeft), y: y(0)),
                                                 scale: s))
                // drawLayer scopes the clip: it must hide SOCLINE only, not
                // the point and the I drawn after it.
                context.drawLayer { layer in
                    layer.clip(to: Path(CGRect(x: clipLeft, y: 0,
                                                width: size.width - clipLeft,
                                                height: size.height)))
                    layer.fill(socline, with: .color(ink.opacity(word)))
                }
            }
        }

        // The point, then the I — both pivot on the mark's centre and recede
        // in depth together, carried left by the drift.
        let mark = Self.fontTransform(pivot: IsoclineWordmarkParts.markCenter,
                                      screenPivot: CGPoint(x: x(markCenterX),
                                                           y: y(IsoclineWordmarkParts.markCenter.y)),
                                      scale: s * markScale)
        if dot > 0.004 {
            context.fill(IsoclineWordmarkParts.dot.applying(mark), with: .color(ink.opacity(dot)))
        }
        if all > 0.004 {
            context.fill(IsoclineWordmarkParts.iGlyph.applying(mark), with: .color(ink.opacity(all)))
        }
    }

    /// Font-space `pivot` lands on `screenPivot`, everything scaled by
    /// `scale` — the canvas transform stack of the draft (translate →
    /// scale → translate-by-pivot), written as one explicit affine:
    /// screen = screenPivot + (font − pivot) × scale.
    private static func fontTransform(pivot: CGPoint, screenPivot: CGPoint, scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                           tx: screenPivot.x - pivot.x * scale,
                           ty: screenPivot.y - pivot.y * scale)
    }
}

#if DEBUG
#Preview("The reveal") {
    IsoclineWordmarkRevealView()
        .ignoresSafeArea()
}

#Preview("Night paper") {
    IsoclineWordmarkRevealView()
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
}

#Preview("Freeze — the I. arrives") {
    IsoclineWordmarkRevealView(freezeAt: 0.75)
        .ignoresSafeArea()
}

#Preview("Freeze — mid-move") {
    IsoclineWordmarkRevealView(freezeAt: 1.9)
        .ignoresSafeArea()
}

#Preview("Freeze — the finished lockup") {
    IsoclineWordmarkRevealView(freezeAt: 3.0)
        .ignoresSafeArea()
}

#Preview("Reduce Motion — the finished lockup, still") {
    // Reduce Motion holds the draft's frozen frame (rmK = t2 + 0.6).
    IsoclineWordmarkRevealView(freezeAt: 3.15)
        .ignoresSafeArea()
}
#endif
