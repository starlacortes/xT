//
//  FlatGraphView.swift
//  xT
//
//  Full-bleed hormone level graph rendered with cubic-bezier curves.
//  The curve's color drifts along a rose → lavender ramp keyed to the
//  current level. Grid lines, Y-axis labels, and peak/trough reference
//  lines use the user's therapeutic targets from Settings.
//
//  Designed as a non-interactive background layer — sits behind the
//  home-screen glass card with `allowsHitTesting(false)`.
//

import SwiftUI

struct FlatGraphView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fraction of total height that the data curve occupies.
    /// 0.55 keeps the curve above the glass card on the home screen.
    var dataRegionFraction: CGFloat = 0.55

    /// Animated data vector for smooth curve morphing between data sets.
    /// Falls back to live data via `effectiveValues` until first animation cycle.
    @State private var animatedValues: AnimatableVector = .zero

    // MARK: - Scrub state (bound from HomeView)

    @Binding var scrubFraction: CGFloat?
    @Binding var scrubValue: Double?
    @Binding var scrubDate: Date?

    /// Pharmacokinetically-aware dense interpolation points for smooth scrubbing.
    @State private var densePoints: [(date: Date, value: Double, xFraction: CGFloat)] = []
    @State private var drawProgress: CGFloat = 0
    @State private var areaReveal: CGFloat = 0
    @State private var dotSlide: CGFloat = 0

    private var points: [MedicationManager.EstimatedPoint] {
        medicationManager.recentLevels
    }

    /// Safe read: uses animated values when available, falls back to raw points.
    private var effectiveValues: [Double] {
        let v = animatedValues.values
        return v.isEmpty ? points.map(\.value) : v
    }

    private var currentLevel: Double? {
        medicationManager.currentHormoneLevel?.value
    }

    /// Rose → lavender tint driven by the current level relative to the
    /// therapeutic ceiling for the selected medication.
    private var levelTint: Color {
        guard let level = currentLevel,
              let medication = medicationManager.selectedMedication else {
            return Theme.Colors.accent
        }
        let ceiling: Double = medication == "Testosterone" ? 1200 : 600
        let t = min(max(level / ceiling, 0), 1)
        return Color.lerp(Theme.Colors.levelLow, Theme.Colors.levelHigh, t)
    }

    // MARK: - Therapeutic targets

    private var target: MedicationManager.TherapeuticTarget? {
        medicationManager.userTherapeuticTarget
    }

    private var effectiveTroughMin: Double {
        guard let t = target else {
            return medicationManager.selectedMedication == "Testosterone"
                ? MedicationManager.TherapeuticTarget.defaultTestosterone.troughMin
                : MedicationManager.TherapeuticTarget.default.troughMin
        }
        return t.troughMin
    }

    private var effectiveTroughMax: Double {
        guard let t = target else {
            return medicationManager.selectedMedication == "Testosterone"
                ? MedicationManager.TherapeuticTarget.defaultTestosterone.troughMax
                : MedicationManager.TherapeuticTarget.default.troughMax
        }
        return t.troughMax
    }

    private var effectivePeakCeiling: Double {
        guard let t = target else {
            return medicationManager.selectedMedication == "Testosterone"
                ? MedicationManager.TherapeuticTarget.defaultTestosterone.peakCeiling
                : MedicationManager.TherapeuticTarget.default.peakCeiling
        }
        return t.peakCeiling
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = effectiveValues
            let bounds = CurveLayout.valueBounds(values)
            ZStack(alignment: .topLeading) {
                if points.isEmpty {
                    emptyState(w: w, h: h)
                } else {
                    curveLayer(values: values, bounds: bounds, w: w, h: h)

                    gridLayer(values: values, bounds: bounds, w: w, h: h)

                    // Only drawn against the user's own target. The population
                    // defaults these used to fall back to were rendered as
                    // "Trough 100–200" — a goal line the user never set, on their
                    // own chart. With no target configured, the curve stands alone.
                    if medicationManager.userTherapeuticTarget != nil {
                        therapeuticReferenceLines(bounds: bounds, w: w, h: h)
                    }

                    currentDot(bounds: bounds, w: w, h: h)

                    lastDoseDot(bounds: bounds, w: w, h: h)

                    nextDoseDot(bounds: bounds, w: w, h: h)

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
            }
            .onAppear {
                guard drawProgress == 0 else { return }
                if reduceMotion {
                    drawProgress = 1; areaReveal = 1; dotSlide = 1
                    return
                }
                // Line draws left → right, decelerating gently into place.
                withAnimation(.easeOut(duration: 1.0)) {
                    drawProgress = 1
                }
                // Area falls in + dot travels the curve together on a soft spring so the
                // dot settles naturally onto "now". Starts once the line is mostly drawn.
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
            }
            .onChange(of: medicationManager.userTherapeuticTarget?.peakCeiling) { _, _ in }
        }
    }

    // MARK: - Empty state

    private func emptyState(w: CGFloat, h: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.Colors.accent.opacity(0.05))
            .frame(width: w, height: h)
            .overlay(
                Text("Log a dose to see your curve")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.accent.opacity(0.4))
            )
    }

    // MARK: - Dense scrub points

    private func generateDensePoints() {
        let recent = medicationManager.recentLevels
        guard let first = recent.first?.date,
              let last = recent.last?.date else {
            densePoints = []
            return
        }
        // The scrub/dot resolution comes from the same rule that sized the drawn curve,
        // so the two cannot drift apart. This used to be a second, independent per-route
        // formula here (`halfLife / 40`) against `refreshState`'s (`halfLife / 30`), both
        // keyed off the manager's global route rather than the ester being plotted.
        let stepDays = medicationManager.chartWindow().denseStepDays
        let dense = medicationManager.estimatedLevels(from: first, to: last, stepDays: stepDays)
        guard dense.count > 1 else { return }
        densePoints = dense.enumerated().map { i, pt in
            (date: pt.date, value: pt.value,
             xFraction: CGFloat(i) / CGFloat(dense.count - 1))
        }
    }

    // MARK: - Scrub indicator line

    @ViewBuilder
    private func scrubIndicatorLine(w: CGFloat, h: CGFloat) -> some View {
        if let fraction = scrubFraction, !densePoints.isEmpty {
            let x = fraction * w
            Rectangle()
                .fill(Theme.Colors.Graph.levelText.opacity(0.5))
                .frame(width: 2)
                .position(x: x, y: h / 2)
                .frame(height: h)
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
                // Snap-back ~45% faster than the original 0.04s hold so the
                // estimated level returns to "now" quickly after lift-off.
                withAnimation(.easeOut(duration: 0.022)) {
                    scrubFraction = nil
                    scrubValue = nil
                    scrubDate = nil
                }
            }
    }

    // MARK: - Curve layer

    private func curveLayer(values: [Double],
                            bounds: (min: Double, max: Double, range: Double),
                            w: CGFloat, h: CGFloat) -> some View {
        let (minV, _, range) = bounds
        let useAnim = !animatedValues.values.isEmpty

        let fillPath: Path = useAnim
            ? AnimatableFillShape(values: animatedValues, minV: minV, range: range, dataFraction: dataRegionFraction).path(in: CGRect(x: 0, y: 0, width: w, height: h))
            : CurveLayout.curveFillPath(values: values, min: minV, range: range, width: w, height: h, dataFraction: dataRegionFraction)

        let strokePath: Path = useAnim
            ? AnimatableCurveShape(values: animatedValues, minV: minV, range: range, dataFraction: dataRegionFraction).path(in: CGRect(x: 0, y: 0, width: w, height: h))
            : CurveLayout.curvePath(values: values, min: minV, range: range, width: w, height: h, dataFraction: dataRegionFraction)

        return ZStack {
            if useAnim {
                AnimatableFillShape(values: animatedValues, minV: minV, range: range, dataFraction: dataRegionFraction)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: levelTint.opacity(0.42), location: 0),
                                .init(color: levelTint.opacity(0.0), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(alignment: .top) {
                        Rectangle().frame(height: h * areaReveal)
                    }
                AnimatableCurveShape(values: animatedValues, minV: minV, range: range, dataFraction: dataRegionFraction)
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        levelTint,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
            } else {
                fillPath
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: levelTint.opacity(0.42), location: 0),
                                .init(color: levelTint.opacity(0.0), location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(alignment: .top) {
                        Rectangle().frame(height: h * areaReveal)
                    }
                strokePath
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        levelTint,
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    // MARK: - Grid layer

    private func gridLayer(values: [Double],
                           bounds: (min: Double, max: Double, range: Double),
                           w: CGFloat, h: CGFloat) -> some View {
        let (minV, maxV, range) = bounds
        let ticks = CurveLayout.niceTicks(min: minV, max: maxV * 1.1, count: 3)
        let color = Theme.Colors.Graph.gridLine

        return ZStack {
            ForEach(ticks.indices, id: \.self) { i in
                let y = CurveLayout.yPos(value: ticks[i], min: minV, range: range,
                                          height: h, dataFraction: dataRegionFraction)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
                .stroke(color, lineWidth: 0.5)

                Text(verbatim: AppNumberFormatters.hormoneLevel.string(ticks[i]))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.Colors.Graph.yAxisLabel)
                    .position(x: w - 20, y: y)
            }
        }
    }

    // MARK: - Therapeutic reference lines

    private func therapeuticReferenceLines(bounds: (min: Double, max: Double, range: Double),
                                           w: CGFloat, h: CGFloat) -> some View {
        let (minV, _, range) = bounds
        let lineColor = Theme.Colors.successBrand.opacity(0.14)

        return ZStack {
            let peakY = CurveLayout.yPos(value: effectivePeakCeiling, min: minV, range: range,
                                          height: h, dataFraction: dataRegionFraction)
            dashedLine(at: peakY, w: w, color: lineColor)
            Text("Peak ceiling \(AppNumberFormatters.hormoneLevel.string(effectivePeakCeiling))")
                .font(.system(size: 8))
                .foregroundStyle(Theme.Colors.successBrand.opacity(0.38))
                .position(x: 8, y: peakY - 8)
                .fixedSize()

            let troughMinY = CurveLayout.yPos(value: effectiveTroughMin, min: minV, range: range,
                                               height: h, dataFraction: dataRegionFraction)
            let troughMaxY = CurveLayout.yPos(value: effectiveTroughMax, min: minV, range: range,
                                               height: h, dataFraction: dataRegionFraction)

            dashedLine(at: troughMinY, w: w, color: lineColor)
            dashedLine(at: troughMaxY, w: w, color: lineColor)

            Text("Trough \(AppNumberFormatters.hormoneLevel.string(effectiveTroughMin))–\(AppNumberFormatters.hormoneLevel.string(effectiveTroughMax))")
                .font(.system(size: 8))
                .foregroundStyle(Theme.Colors.successBrand.opacity(0.38))
                .position(x: 8, y: troughMaxY + 8)
                .fixedSize()
        }
    }

    private func dashedLine(at y: CGFloat, w: CGFloat, color: Color) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: w, y: y))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 0.5, dash: [3, 5]))
    }

    // MARK: - Current dot

    @ViewBuilder
    private func currentDot(bounds: (min: Double, max: Double, range: Double),
                            w: CGFloat, h: CGFloat) -> some View {
        if currentLevel != nil,
           !densePoints.isEmpty,
           let lastDate = densePoints.last?.date {
            let now = Date()
            let targetDate = min(now, lastDate)
            let nearest = densePoints.enumerated().min(by: {
                abs($0.element.date.timeIntervalSince(targetDate)) < abs($1.element.date.timeIntervalSince(targetDate))
            }) ?? (offset: densePoints.count - 1, element: densePoints[densePoints.count - 1])
            let (minV, _, range) = bounds

            // Dot enters at the curve's right endpoint and travels leftward along
            // the actual curve path to the "now" point. `dotSlide` 0 = right end,
            // 1 = now. At rest (dotSlide == 1) this resolves to the "now" point on the curve.
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
            // The dot rides directly on the curve (x and y) as it slides in from the right.
            let dotY = CurveLayout.yPos(value: vInterp, min: minV, range: range,
                                        height: h, dataFraction: dataRegionFraction)

            ZStack {
                Circle()
                    .fill(levelTint.opacity(0.22))
                    .frame(width: 26, height: 26)
                    .position(x: dotX, y: dotY)
                    .blur(radius: 6)
                Circle()
                    .fill(levelTint)
                    .frame(width: 12, height: 12)
                    .position(x: dotX, y: dotY)
            }
            .opacity(dotSlide)
        }
    }

    // MARK: - Last dose dot

    @ViewBuilder
    private func lastDoseDot(bounds: (min: Double, max: Double, range: Double),
                             w: CGFloat, h: CGFloat) -> some View {
        if let lastDoseDate = medicationManager.lastDoseDate,
           !points.isEmpty {
            let visibleStart = points.first!.date
            let visibleEnd = points.last!.date
            let totalTime = visibleEnd.timeIntervalSince(visibleStart)
            if totalTime > 0, lastDoseDate >= visibleStart, lastDoseDate <= visibleEnd {
                let fraction = lastDoseDate.timeIntervalSince(visibleStart) / totalTime
                let px = fraction * w
                let (minV, _, range) = bounds
                let py = CurveLayout.yPos(value: nearestCurveValue(at: lastDoseDate), min: minV, range: range,
                                          height: h, dataFraction: dataRegionFraction)

                ZStack {
                    Circle()
                        .fill(Theme.Colors.accentSecondary.opacity(0.22))
                        .frame(width: 12, height: 12)
                        .position(x: px, y: py)
                    Circle()
                        .fill(Theme.Colors.accentSecondary)
                        .frame(width: 4, height: 4)
                        .position(x: px, y: py)
                    Text("dose")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accentSecondary.opacity(0.6))
                        .position(x: px, y: py + 12)
                }
            }
        }
    }

    // MARK: - Next dose dot

    @ViewBuilder
    private func nextDoseDot(bounds: (min: Double, max: Double, range: Double),
                             w: CGFloat, h: CGFloat) -> some View {
        if let nextDoseDate = medicationManager.nextDoseDate,
           !points.isEmpty {
            let firstDate = points.first!.date
            let lastDate = points.last!.date
            let totalTime = lastDate.timeIntervalSince(firstDate)
            if totalTime > 0, nextDoseDate >= firstDate, nextDoseDate <= lastDate {
                let fraction = nextDoseDate.timeIntervalSince(firstDate) / totalTime
                let px = fraction * w
                let (minV, _, range) = bounds
                let samples = densePoints.isEmpty ? points.map { (date: $0.date, value: $0.value) } : densePoints.map { (date: $0.date, value: $0.value) }
                let nearestValue = samples.min(by: { abs($0.date.timeIntervalSince(nextDoseDate)) < abs($1.date.timeIntervalSince(nextDoseDate)) })?.value ?? points.last!.value
                let py = CurveLayout.yPos(value: nearestValue, min: minV, range: range,
                                          height: h, dataFraction: dataRegionFraction)

                ZStack {
                    Circle()
                        .stroke(levelTint.opacity(0.3), lineWidth: 1)
                        .frame(width: 18, height: 18)
                        .position(x: px, y: py)
                    Circle()
                        .stroke(levelTint, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .position(x: px, y: py)
                    Text("next dose")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Theme.Colors.Graph.yAxisLabel.opacity(0.55))
                        .position(x: px, y: py + 14)
                }
            }
        }
    }

    private func nearestCurveValue(at date: Date) -> Double {
        let source: [(date: Date, value: Double)] = densePoints.isEmpty
            ? points.map { (date: $0.date, value: $0.value) }
            : densePoints.map { (date: $0.date, value: $0.value) }
        return source.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })?.value ?? 0
    }

}

#if DEBUG
#Preview {
    SpoofPreview {
        FlatGraphView(scrubFraction: .constant(nil), scrubValue: .constant(nil), scrubDate: .constant(nil))
            .background(Color(.systemBackground))
            .environment(\.medicationManager, MedicationManager.shared)
            .frame(height: 400)
    }
}
#endif
