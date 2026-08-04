//
//  LabsChartView.swift
//  xT
//
//  Static chart comparing measured lab draws against the model's uncalibrated
//  prediction at each draw date. Reuses CurveLayout's index-based positioning
//  primitives (the same ones FlatGraphView uses) rather than a date-proportional
//  axis, since the rest of the app's charts are built the same way.
//

import SwiftUI

struct LabsChartView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var selectedHormone: String?

    private var availableHormones: [String] {
        Array(Set(medicationManager.bloodTestHistory.map(\.hormoneType))).sorted()
    }

    private var hormone: String {
        selectedHormone ?? availableHormones.first ?? medicationManager.selectedMedication ?? "Estrogen"
    }

    private var points: [LabsSeriesPoint] {
        medicationManager.labsSeriesPoints(for: hormone)
    }

    private var bounds: (min: Double, max: Double) {
        LabsChartSeries.range(for: points)
    }

    // Reserves space at the leading edge for Y-axis tick labels.
    private let axisGutter: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if availableHormones.count > 1 {
                Picker("Hormone", selection: Binding(
                    get: { hormone },
                    set: { selectedHormone = $0 }
                )) {
                    ForEach(availableHormones, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "No Lab Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log a blood test to see measured vs. modeled levels here.")
                )
                .frame(height: 200)
            } else {
                chart
                    .frame(height: 200)

                legend
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        GeometryReader { geo in
            let width = max(geo.size.width - axisGutter, 1)
            let height = geo.size.height
            let (lo, hi) = bounds
            let range = max(hi - lo, 0.0001)
            let ticks = CurveLayout.niceTicks(min: lo, max: hi)

            ZStack(alignment: .topLeading) {
                ForEach(ticks, id: \.self) { tick in
                    let y = CurveLayout.yPos(value: tick, min: lo, range: range, height: height)
                    Rectangle()
                        .fill(Theme.Colors.Graph.gridLine)
                        .frame(width: width, height: 0.5)
                        .position(x: axisGutter + width / 2, y: y)
                    Text(AppNumberFormatters.hormoneLevel.string(tick))
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Theme.Colors.Graph.yAxisLabel)
                        .frame(width: axisGutter - 6, alignment: .trailing)
                        .position(x: (axisGutter - 6) / 2, y: y)
                }

                modeledPath(width: width, height: height, lo: lo, range: range)
                    .stroke(Theme.Colors.Time.skin.base,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 4]))
                    .offset(x: axisGutter)

                if points.count > 1 {
                    measuredPath(width: width, height: height, lo: lo, range: range)
                        .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .offset(x: axisGutter)
                }

                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let x = CurveLayout.xPos(index: index, count: points.count, width: width) + axisGutter
                    let y = CurveLayout.yPos(value: point.measured, min: lo, range: range, height: height)
                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)
                }
            }
        }
    }

    /// Straight-line trace through the measured levels, one point per draw.
    private func measuredPath(width: CGFloat, height: CGFloat, lo: Double, range: Double) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = CurveLayout.xPos(index: index, count: points.count, width: width)
                let y = CurveLayout.yPos(value: point.measured, min: lo, range: range, height: height)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    /// Straight-line trace through the modeled predictions, breaking the line at
    /// any draw where `predicted` is nil rather than interpolating across it.
    private func modeledPath(width: CGFloat, height: CGFloat, lo: Double, range: Double) -> Path {
        Path { path in
            var isDrawing = false
            for (index, point) in points.enumerated() {
                guard let predicted = point.predicted else {
                    isDrawing = false
                    continue
                }
                let x = CurveLayout.xPos(index: index, count: points.count, width: width)
                let y = CurveLayout.yPos(value: predicted, min: lo, range: range, height: height)
                if isDrawing {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.move(to: CGPoint(x: x, y: y))
                    isDrawing = true
                }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: 6) {
                Circle().fill(Theme.Colors.accent).frame(width: 7, height: 7)
                Text("Measured").font(Theme.Fonts.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Rectangle().fill(Theme.Colors.Time.skin.base).frame(width: 14, height: 1.5)
                Text("Modeled").font(Theme.Fonts.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        LabsChartView()
            .environment(\.medicationManager, MedicationManager.shared)
            .padding(Theme.Spacing.Gutter.screen)
    }
}
#endif
