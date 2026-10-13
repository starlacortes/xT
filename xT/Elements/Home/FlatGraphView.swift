//
//  FlatGraphView.swift
//  xT
//
//  The Home curve — the product's hero instrument (elements H1, H4–H7). A full-bleed
//  hormone-level graph drawn on paper. The curve's data line is kept inside a plot band
//  defined by `plotInsets`: the top inset clears the flush readout (H2), the bottom inset
//  clears the phase strip + overlay card (H10). The fill closes at the screen bottom, so it
//  reads behind the card.
//
//  Isocline retune (§6): fill top-opacity 0.3, no dashed therapeutic reference lines
//  (provenance is carried by the readout's provenance line, not by line style), a neutral
//  accent range band only when the user set a range (H5), hollow rings for measured labs
//  (H6, never snapped to the curve), and a concentric "now" point — the same perfect
//  circle as the "I." mark (H7). Dose / next-dose markers moved to the phase strip.
//

import SwiftUI

struct FlatGraphView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    /// Insets that keep the data line clear of the flush readout (top) and the phase strip
    /// + overlay card (bottom). Replaces the old `dataRegionFraction` (H1).
    var plotInsets: EdgeInsets = EdgeInsets()

    /// Animated data vector for smooth curve morphing between data sets.
    @State private var animatedValues: AnimatableVector = .zero

    // MARK: - Scrub state (bound from HomeView)

    @Binding var scrubFraction: CGFloat?
    @Binding var scrubValue: Double?
    @Binding var scrubDate: Date?

    @State private var densePoints: [(date: Date, value: Double, xFraction: CGFloat)] = []
    /// Cached day/week/month grid markers (H1's stationary time rules). `CurveLayout
    /// .timeMarkers` walks the window a day at a time, so it's keyed to the data —
    /// not recomputed on every scrub-driven body re-evaluation (`scrubFraction`/
    /// `scrubValue` bindings change at gesture frequency and don't affect the markers).
    @State private var dayMarkers: [(date: Date, label: String)] = []
    @State private var drawProgress: CGFloat = 0
    @State private var areaReveal: CGFloat = 0
    @State private var dotSlide: CGFloat = 0

    private var points: [MedicationManager.EstimatedPoint] {
        medicationManager.recentLevels
    }

    private var effectiveValues: [Double] {
        let v = animatedValues.values
        return v.isEmpty ? points.map(\.value) : v
    }

    private var currentLevel: Double? {
        medicationManager.currentHormoneLevel?.value
    }

    /// Rose → lavender tint driven by the current level relative to the therapeutic
    /// ceiling for the selected medication (a data constant, not a design token).
    private var levelTint: Color {
        guard let level = currentLevel,
              let medication = medicationManager.selectedMedication else {
            return Theme.Colors.accent
        }
        let ceiling: Double = medication == "Testosterone" ? 1200 : 600
        let t = min(max(level / ceiling, 0), 1)
        return Color.lerp(Theme.Colors.levelLow, Theme.Colors.levelHigh, t)
    }

    /// The stroke gradient runs levelLow → levelHigh along the curve (left = earlier time).
    private var strokeStyle: LinearGradient {
        LinearGradient(colors: [Theme.Colors.levelLow, Theme.Colors.levelHigh],
                       startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let plotTop = plotInsets.top
            let plotBottom = max(h - plotInsets.bottom, plotTop + 1)
            let values = effectiveValues
            let bounds = CurveLayout.valueBounds(values)

            ZStack(alignment: .topLeading) {
                if points.isEmpty {
                    emptyState(w: w, h: h)
                } else {
                    rangeBandLayer(bounds: bounds, w: w, plotTop: plotTop, plotBottom: plotBottom)

                    curveLayer(values: values, bounds: bounds, w: w, h: h,
                               plotTop: plotTop, plotBottom: plotBottom)

                    gridLayer(values: values, bounds: bounds, w: w,
                              plotTop: plotTop, plotBottom: plotBottom)

                    dayGridLayer(w: w, plotTop: plotTop, plotBottom: plotBottom)

                    labRingsLayer(bounds: bounds, w: w, plotTop: plotTop, plotBottom: plotBottom)

                    nowPoint(bounds: bounds, w: w, plotTop: plotTop, plotBottom: plotBottom)

                    scrubIndicatorLine(w: w, h: h)
                }
            }
            .clipped()
            .overlay {
                if !points.isEmpty {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(scrubGesture(in: geo))
                }
            }
            .task {
                if animatedValues.values.isEmpty {
                    animatedValues = AnimatableVector(values: points.map(\.value))
                }
                generateDensePoints()
                recomputeDayMarkers(width: w)
            }
            .onAppear {
                guard drawProgress == 0 else { return }
                if reduceMotion {
                    drawProgress = 1; areaReveal = 1; dotSlide = 1
                    return
                }
                withAnimation(.easeOut(duration: 1.0)) {
                    drawProgress = 1
                }
                withAnimation(Theme.Motion.entrance.delay(0.4)) {
                    areaReveal = 1
                    dotSlide = 1
                }
            }
            .onChange(of: points.map(\.value)) { _, newValues in
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    animatedValues = AnimatableVector(values: newValues)
                }
                generateDensePoints()
                recomputeDayMarkers(width: w)
            }
        }
    }

    // MARK: - Empty state

    private func emptyState(w: CGFloat, h: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: w, height: h)
            .overlay(
                Text("Log a dose to see your curve")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textTertiary)
            )
    }

    // MARK: - Curve layer

    private func curveLayer(values: [Double],
                            bounds: (min: Double, max: Double, range: Double),
                            w: CGFloat, h: CGFloat,
                            plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        let (minV, _, range) = bounds
        let useAnim = !animatedValues.values.isEmpty
        let activeValues = useAnim ? animatedValues : AnimatableVector(values: values)

        let fillGradient = LinearGradient(
            stops: [
                .init(color: levelTint.opacity(Theme.Curve.Fill.topOpacity), location: 0),
                .init(color: levelTint.opacity(Theme.Curve.Fill.bottomOpacity), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )

        return ZStack {
            AnimatableFillShape(values: activeValues, minV: minV, range: range,
                                plotTop: plotTop, plotBottom: plotBottom, fillBottom: h)
                .fill(fillGradient)
                .mask(alignment: .top) {
                    Rectangle().frame(height: h * areaReveal)
                }

            AnimatableCurveShape(values: activeValues, minV: minV, range: range,
                                 plotTop: plotTop, plotBottom: plotBottom)
                .trim(from: 0, to: drawProgress)
                .stroke(strokeStyle,
                        style: StrokeStyle(lineWidth: Theme.Line.curve, lineCap: .round, lineJoin: .round))
                .modifier(CurveGlow(enabled: colorScheme == .dark && !reduceTransparency,
                                    color: levelTint))
        }
    }

    // MARK: - Grid layer

    private func gridLayer(values: [Double],
                           bounds: (min: Double, max: Double, range: Double),
                           w: CGFloat,
                           plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        let (minV, maxV, range) = bounds
        let ticks = CurveLayout.niceTicks(min: minV, max: maxV * 1.1, count: 3)

        return ZStack {
            ForEach(ticks.indices, id: \.self) { i in
                let y = CurveLayout.yPos(value: ticks[i], min: minV, range: range,
                                         plotTop: plotTop, plotBottom: plotBottom)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(Theme.Colors.Graph.gridLine, lineWidth: Theme.Colors.hairlineWidth)

                Text(verbatim: AppNumberFormatters.hormoneLevel.string(ticks[i]))
                    .statLabel()
                    .foregroundStyle(Theme.Colors.Graph.yAxisLabel)
                    .position(x: w - 20, y: y)
            }
        }
    }

    // MARK: - Day grid (stationary time rules)

    /// Vertical hairlines at day boundaries across the window, drawn WITHOUT
    /// weekday labels — the phase strip under the curve is the calendar element
    /// (H9), and two calendar rows read as noise. The tiering (day → week →
    /// month) still comes from `CurveLayout.timeMarkers`, so the rules thin out
    /// on the trend windows. Unlike the scrub line, they hold still — a fixed
    /// time axis under the moving readout.
    ///
    /// X is time-proportional here (and on the curve) because `recentLevels`
    /// samples the window at a uniform step.
    @ViewBuilder
    private func dayGridLayer(w: CGFloat, plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        if let first = points.first?.date, let last = points.last?.date, last > first, !dayMarkers.isEmpty {
            let total = last.timeIntervalSince(first)

            ForEach(dayMarkers.indices, id: \.self) { i in
                let x = CGFloat(dayMarkers[i].date.timeIntervalSince(first) / total) * w

                Path { p in
                    p.move(to: CGPoint(x: x, y: plotTop))
                    p.addLine(to: CGPoint(x: x, y: plotBottom))
                }
                .stroke(Theme.Colors.Graph.gridLine, lineWidth: Theme.Colors.hairlineWidth)
            }
        }
    }

    // MARK: - Range band (H5)

    @ViewBuilder
    private func rangeBandLayer(bounds: (min: Double, max: Double, range: Double),
                                w: CGFloat, plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        // U18 / X9: only ever drawn against a range the user set. `rangeBand` is nil for
        // clinical defaults, so no goal line the user never chose ends up on their chart.
        if let band = medicationManager.rangeBand {
            let (minV, _, range) = bounds
            let yHigh = clamp(CurveLayout.yPos(value: band.high, min: minV, range: range,
                                               plotTop: plotTop, plotBottom: plotBottom),
                              plotTop, plotBottom)
            let yLow = clamp(CurveLayout.yPos(value: band.low, min: minV, range: range,
                                              plotTop: plotTop, plotBottom: plotBottom),
                             plotTop, plotBottom)
            let top = min(yHigh, yLow)
            let height = max(abs(yLow - yHigh), 1)

            Rectangle()
                .fill(Theme.Colors.accent.opacity(Theme.Curve.RangeBand.opacity))
                .frame(width: w, height: height)
                .position(x: w / 2, y: top + height / 2)

            Text(rangeLabel(band))
                .statLabel()
                .foregroundStyle(Theme.Colors.textSecondary)
                .position(x: 0, y: top)
                .offset(x: rangeLabelInset, y: Theme.Spacing.sm)
                .fixedSize()
        }
    }

    private var rangeLabelInset: CGFloat { 54 }   // clears the label's own centering

    private func rangeLabel(_ band: MedicationManager.RangeBand) -> String {
        let low = AppNumberFormatters.hormoneLevel.string(band.low)
        let high = AppNumberFormatters.hormoneLevel.string(band.high)
        return String(localized: "Your range \(low)–\(high)",
                      comment: "Label on the Home curve's range band, e.g. 'YOUR RANGE 100–600'")
    }

    // MARK: - Lab rings (H6)

    @ViewBuilder
    private func labRingsLayer(bounds: (min: Double, max: Double, range: Double),
                               w: CGFloat, plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        if let first = points.first?.date, let last = points.last?.date, last > first {
            let labs = medicationManager.labPoints(in: first...last)
            let (minV, _, range) = bounds
            let total = last.timeIntervalSince(first)

            ForEach(Array(labs.enumerated()), id: \.offset) { _, lab in
                let fraction = CGFloat(lab.date.timeIntervalSince(first) / total)
                let x = min(max(fraction * w, 8), w - 8)
                // Plotted at the measured value, never snapped to the modeled curve — the
                // gap between ring and curve IS the information (H6).
                let y = CurveLayout.yPos(value: lab.measured, min: minV, range: range,
                                         plotTop: plotTop, plotBottom: plotBottom)
                Circle()
                    .fill(Theme.Colors.appBackground)
                    .overlay(
                        Circle().strokeBorder(Theme.Colors.textPrimary, lineWidth: Theme.Line.labRing)
                    )
                    .frame(width: Theme.Curve.LabPoint.diameter, height: Theme.Curve.LabPoint.diameter)
                    .position(x: x, y: y)
            }
        }
    }

    // MARK: - Now point (H7)

    @ViewBuilder
    private func nowPoint(bounds: (min: Double, max: Double, range: Double),
                          w: CGFloat, plotTop: CGFloat, plotBottom: CGFloat) -> some View {
        if currentLevel != nil, !densePoints.isEmpty, let lastDate = densePoints.last?.date {
            let now = Date()
            let targetDate = min(now, lastDate)
            let nearest = densePoints.enumerated().min(by: {
                abs($0.element.date.timeIntervalSince(targetDate)) < abs($1.element.date.timeIntervalSince(targetDate))
            }) ?? (offset: densePoints.count - 1, element: densePoints[densePoints.count - 1])
            let (minV, _, range) = bounds

            // The point enters at the curve's right endpoint and slides left to "now".
            let count = densePoints.count
            let endIndex = count - 1
            let fIndex = Double(nearest.offset) + Double(1 - dotSlide) * Double(endIndex - nearest.offset)
            let i0 = min(max(Int(fIndex.rounded(.down)), 0), endIndex)
            let i1 = min(i0 + 1, endIndex)
            let frac = CGFloat(fIndex - Double(i0))
            let x0 = CurveLayout.markerX(index: i0, count: count, width: w)
            let x1 = CurveLayout.markerX(index: i1, count: count, width: w)
            let dotX = x0 + (x1 - x0) * frac
            let vInterp = densePoints[i0].value + (densePoints[i1].value - densePoints[i0].value) * Double(frac)
            let dotY = CurveLayout.yPos(value: vInterp, min: minV, range: range,
                                        plotTop: plotTop, plotBottom: plotBottom)

            ZStack {
                // Concentric halo — the same perfect circle as the "I." mark; no blur.
                Circle()
                    .fill(Theme.Colors.accent.opacity(Theme.Curve.NowPoint.haloOpacity))
                    .frame(width: Theme.Curve.NowPoint.haloDiameter, height: Theme.Curve.NowPoint.haloDiameter)
                    .position(x: dotX, y: dotY)
                Circle()
                    .fill(levelTint)
                    .frame(width: Theme.Curve.NowPoint.dotDiameter, height: Theme.Curve.NowPoint.dotDiameter)
                    .position(x: dotX, y: dotY)
            }
            .opacity(dotSlide)
        }
    }

    // MARK: - Scrub indicator line

    @ViewBuilder
    private func scrubIndicatorLine(w: CGFloat, h: CGFloat) -> some View {
        if let fraction = scrubFraction, !densePoints.isEmpty {
            let x = fraction * w
            Rectangle()
                .fill(Theme.Colors.textPrimary.opacity(0.4))
                .frame(width: Theme.Colors.hairlineWidth)
                .position(x: x, y: h / 2)
                .frame(height: h)
        }
    }

    // MARK: - Day grid markers (cache)

    private func recomputeDayMarkers(width: CGFloat) {
        guard let first = points.first?.date, let last = points.last?.date, last > first else {
            dayMarkers = []
            return
        }
        dayMarkers = CurveLayout.timeMarkers(first: first, last: last, width: width)
    }

    // MARK: - Dense scrub points

    private func generateDensePoints() {
        let recent = medicationManager.recentLevels
        guard let first = recent.first?.date,
              let last = recent.last?.date else {
            densePoints = []
            return
        }
        let stepDays = medicationManager.chartWindow().denseStepDays
        let dense = medicationManager.estimatedLevels(from: first, to: last, stepDays: stepDays)
        guard dense.count > 1 else { return }
        densePoints = dense.enumerated().map { i, pt in
            (date: pt.date, value: pt.value,
             xFraction: CGFloat(i) / CGFloat(dense.count - 1))
        }
    }

    // MARK: - Scrub gesture

    private func scrubGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let w = geo.size.width
                let fraction = max(0, min(1, value.location.x / w))
                guard !densePoints.isEmpty else { return }
                if let nearest = densePoints.min(by: {
                    abs($0.xFraction - fraction) < abs($1.xFraction - fraction)
                }) {
                    scrubFraction = fraction
                    scrubValue = nearest.value
                    scrubDate = nearest.date
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.022)) {
                    scrubFraction = nil
                    scrubValue = nil
                    scrubDate = nil
                }
            }
    }

    // MARK: - Helpers

    private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}

// MARK: - Curve glow (night paper only)

/// A faint stroke glow, allowed on night paper only and never under Reduce Transparency
/// (§6, `curve.glow`). Not a shadow on a surface — F10's ban is on paper cards, not the
/// instrument curve.
private struct CurveGlow: ViewModifier {
    let enabled: Bool
    let color: Color

    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: color.opacity(Theme.Curve.Glow.opacity),
                           radius: Theme.Curve.Glow.radius)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        FlatGraphView(plotInsets: EdgeInsets(top: 80, leading: 0, bottom: 160, trailing: 0),
                      scrubFraction: .constant(nil),
                      scrubValue: .constant(nil),
                      scrubDate: .constant(nil))
            .background(Theme.Colors.appBackground)
            .environment(\.medicationManager, MedicationManager.shared)
            .frame(height: 400)
    }
}
#endif
