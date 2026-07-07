//
//  FlatGraphView.swift
//  xT
//
//  Edge-to-edge hormone level graph. The curve's color drifts along a
//  rose→lavender ramp keyed to the current level (deeper rose = lower,
//  lighter lavender = higher), giving a subtle at-a-glance read on where
//  today sits relative to the rest of the week — no card container, sits
//  flush on the home background.
//

import SwiftUI

struct FlatGraphView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var showingGraphDetail: Bool

    private var points: [MedicationManager.EstimatedPoint] {
        medicationManager.recentLevels
    }

    private var currentLevel: Double? {
        medicationManager.currentHormoneLevel?.value
    }

    private var unit: String {
        medicationManager.currentHormoneLevel?.unit ?? "pg/mL"
    }

    /// Rose→lavender tint driven by the current level relative to a typical
    /// clinical ceiling for the selected medication. Deeper rose reads as
    /// "lower", lighter lavender as "higher" — a soft, non-alarming gradient
    /// rather than a strict red/green status color.
    private var levelTint: Color {
        guard let level = currentLevel, let medication = medicationManager.selectedMedication else {
            return Theme.Colors.accent
        }
        let ceiling: Double = medication == "Testosterone" ? 1200 : 600
        let t = min(max(level / ceiling, 0), 1)
        return Color.lerp(Theme.Colors.levelLow, Theme.Colors.levelHigh, t)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            graphBody
                .frame(height: 200)

            Button(action: { showingGraphDetail = true }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(levelTint.opacity(0.4))
            }
            .frame(width: 44, height: 200)
            .contentShape(Rectangle())
        }
        .animation(.easeInOut(duration: 0.6), value: currentLevel)
    }

    // MARK: - Graph body

    @ViewBuilder
    private var graphBody: some View {
        if points.isEmpty {
            Rectangle()
                .fill(Theme.Colors.accent.opacity(0.05))
                .overlay(
                    Text("Log a dose to see your curve")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.accent.opacity(0.4))
                )
        } else {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let values = points.map(\.value)
                let minV = (values.min() ?? 0) * 0.85
                let maxV = (values.max() ?? 1) * 1.1
                let range = maxV - minV

                ZStack(alignment: .topLeading) {
                    curveFillPath(values: values, min: minV, range: range, w: w, h: h)
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

                    curvePath(values: values, min: minV, range: range, w: w, h: h)
                        .stroke(
                            levelTint,
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )

                    if let peakIdx = values.indices.min(by: { values[$0] > values[$1] }) {
                        let px = xPos(index: peakIdx, count: values.count, w: w)
                        let py = yPos(value: values[peakIdx], min: minV, range: range, h: h)

                        Circle()
                            .fill(levelTint.opacity(0.22))
                            .frame(width: 14, height: 14)
                            .position(x: px, y: py)

                        Circle()
                            .fill(levelTint)
                            .frame(width: 6, height: 6)
                            .position(x: px, y: py)
                    }

                    lastDoseMarker(values: values, min: minV, range: range, w: w, h: h)

                    levelLabel
                        .padding(.leading, 22)
                        .padding(.top, 14)
                }
            }
        }
    }

    // MARK: - Level label

    private var levelLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            if let level = currentLevel {
                AnimatedCounter(value: level)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .contentTransition(.numericText())

                Text(unit)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Color.secondary)

                if let word = rangeWord(for: level) {
                    Text("·")
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text(word)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    // MARK: - Path helpers

    private func xPos(index: Int, count: Int, w: CGFloat) -> CGFloat {
        guard count > 1 else { return w / 2 }
        return CGFloat(index) / CGFloat(count - 1) * w
    }

    private func yPos(value: Double, min: Double, range: Double, h: CGFloat) -> CGFloat {
        guard range > 0 else { return h / 2 }
        let norm = (value - min) / range
        return h - CGFloat(norm) * h * 0.85 - h * 0.07
    }

    private func curvePath(values: [Double], min: Double, range: Double, w: CGFloat, h: CGFloat) -> Path {
        Path { path in
            for (i, v) in values.enumerated() {
                let x = xPos(index: i, count: values.count, w: w)
                let y = yPos(value: v, min: min, range: range, h: h)
                if i == 0 {
                    path.move(to: .init(x: x, y: y))
                } else {
                    let prev = CGPoint(
                        x: xPos(index: i - 1, count: values.count, w: w),
                        y: yPos(value: values[i - 1], min: min, range: range, h: h)
                    )
                    let ctrl1 = CGPoint(x: prev.x + (x - prev.x) * 0.5, y: prev.y)
                    let ctrl2 = CGPoint(x: prev.x + (x - prev.x) * 0.5, y: y)
                    path.addCurve(to: .init(x: x, y: y), control1: ctrl1, control2: ctrl2)
                }
            }
        }
    }

    private func curveFillPath(values: [Double], min: Double, range: Double, w: CGFloat, h: CGFloat) -> Path {
        var base = curvePath(values: values, min: min, range: range, w: w, h: h)
        base.addLine(to: .init(x: w, y: h))
        base.addLine(to: .init(x: 0, y: h))
        base.closeSubpath()
        return base
    }

    // MARK: - Last dose marker

    /// Finds the EstimatedPoint closest in time to the last logged dose date
    /// and returns a visual marker positioned on the curve at that point.
    /// Returns nil if no last dose date exists or no points match.
    private func lastDoseMarker(values: [Double], min: Double, range: Double,
                                w: CGFloat, h: CGFloat) -> some View {
        guard let lastDose = medicationManager.lastDoseDate else {
            return AnyView(EmptyView())
        }

        // Find the point whose date is closest to lastDoseDate
        var bestIdx = 0
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for (i, pt) in points.enumerated() {
            let delta = abs(pt.date.timeIntervalSince(lastDose))
            if delta < bestDelta {
                bestDelta = delta
                bestIdx = i
            }
        }

        // Only show if we're within a reasonable window (e.g. 3 days)
        guard bestDelta < 3 * 86400 else {
            return AnyView(EmptyView())
        }

        let px = xPos(index: bestIdx, count: values.count, w: w)
        let py = yPos(value: values[bestIdx], min: min, range: range, h: h)

        return AnyView(
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(Theme.Colors.accentSecondary.opacity(0.22))
                    .frame(width: 14, height: 14)
                    .position(x: px, y: py)

                // Inner filled dot
                Circle()
                    .fill(Theme.Colors.accentSecondary)
                    .frame(width: 5, height: 5)
                    .position(x: px, y: py)

                // Small label below
                Text("dose")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accentSecondary.opacity(0.7))
                    .position(x: px, y: py + 14)
            }
        )
    }

    // MARK: - Range word

    private func rangeWord(for level: Double) -> String? {
        guard let med = medicationManager.selectedMedication else { return nil }
        if med == "Estrogen" {
            switch level {
            case ..<50:  return "very low"
            case ..<100: return "low"
            case ..<200: return "optimal"
            case ..<500: return "high"
            default:     return "very high"
            }
        } else {
            switch level {
            case ..<50:  return "suppressed"
            case ..<200: return "low"
            case ..<800: return "in range"
            default:     return "high"
            }
        }
    }
}

#Preview {
    FlatGraphView(showingGraphDetail: .constant(false))
        .background(Color(.systemBackground))
        .environment(\.medicationManager, MedicationManager.shared)
}
