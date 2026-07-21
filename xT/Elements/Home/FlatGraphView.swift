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

                    therapeuticReferenceLines(bounds: bounds, w: w, h: h)

                    peakMarker(bounds: bounds, w: w, h: h)

                    doseMarkers(bounds: bounds, w: w, h: h)

                    scrubIndicatorLine(w: w, h: h)
                }
            }
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
        let method = medicationManager.selectedAdministrationMethod ?? "Injectable"
        let stepDays: Double
        switch method {
        case "Oral":
            stepDays = 15.0 / (24.0 * 60.0)
        case "Cream":
            stepDays = 1.0 / 24.0
        case "Injectable":
            let halfLife = medicationManager.currentEster?.halfLifeDays ?? 5.0
            stepDays = max(1.0 / 24.0, halfLife / 40.0)
        default:
            stepDays = 2.0 / 24.0
        }
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
                withAnimation(.easeOut(duration: 0.15)) {
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
                AnimatableCurveShape(values: animatedValues, minV: minV, range: range, dataFraction: dataRegionFraction)
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
                strokePath
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

                Text("\(Int(ticks[i]))")
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
            Text("Peak ceiling \(Int(effectivePeakCeiling))")
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

            Text("Trough \(Int(effectiveTroughMin))–\(Int(effectiveTroughMax))")
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

    // MARK: - Peak marker

    private func peakMarker(bounds: (min: Double, max: Double, range: Double),
                            w: CGFloat, h: CGFloat) -> some View {
        let (minV, _, range) = bounds
        guard let peakPt = points.max(by: { $0.value < $1.value }) else {
            return AnyView(EmptyView())
        }
        let peakIdx = points.firstIndex(where: { $0.date == peakPt.date }) ?? 0

        let px = CurveLayout.markerX(index: peakIdx, count: points.count, width: w)
        let py = CurveLayout.yPos(value: peakPt.value, min: minV, range: range,
                                    height: h, dataFraction: dataRegionFraction)

        return AnyView(
            ZStack {
                Circle()
                    .fill(levelTint.opacity(0.22))
                    .frame(width: 14, height: 14)
                    .position(x: px, y: py)
                Circle()
                    .fill(levelTint)
                    .frame(width: 6, height: 6)
                    .position(x: px, y: py)
                Text("peak")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(levelTint.opacity(0.7))
                    .position(x: px, y: py + 14)
            }
        )
    }

    // MARK: - Dose markers

    private func doseMarkers(bounds: (min: Double, max: Double, range: Double),
                             w: CGFloat, h: CGFloat) -> some View {
        let (minV, _, range) = bounds
        let activeDoses = medicationManager.doseHistory.filter {
            $0.doseStatus == DoseStatus.taken.rawValue && !$0.isDeleted
        }
        guard !activeDoses.isEmpty, !points.isEmpty else {
            return AnyView(EmptyView())
        }
        let visibleStart = points.first!.date.addingTimeInterval(-12 * 3600)
        let visibleEnd = points.last!.date.addingTimeInterval(12 * 3600)
        let visibleDoses = activeDoses.filter {
            $0.doseDate >= visibleStart && $0.doseDate <= visibleEnd
        }
        guard !visibleDoses.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            ZStack {
                ForEach(visibleDoses, id: \.id) { dose in
                    doseDot(for: dose, minV: minV, range: range, w: w, h: h)
                }
            }
        )
    }

    private func doseDot(for dose: DoseRecord,
                         minV: Double, range: Double,
                         w: CGFloat, h: CGFloat) -> some View {
        var bestIdx = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (i, pt) in points.enumerated() {
            let delta = abs(pt.date.timeIntervalSince(dose.doseDate))
            if delta < bestDelta {
                bestDelta = delta
                bestIdx = i
            }
        }
        guard bestDelta < 7 * 86400 else { return AnyView(EmptyView()) }

        let px = CurveLayout.markerX(index: bestIdx, count: points.count, width: w)
        let py = CurveLayout.yPos(value: points[bestIdx].value, min: minV, range: range,
                                    height: h, dataFraction: dataRegionFraction)

        return AnyView(
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
        )
    }

}

#Preview {
    FlatGraphView(scrubFraction: .constant(nil), scrubValue: .constant(nil), scrubDate: .constant(nil))
        .background(Color(.systemBackground))
        .environment(\.medicationManager, MedicationManager.shared)
        .frame(height: 400)
}
