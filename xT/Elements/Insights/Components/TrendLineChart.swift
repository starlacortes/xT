//
//  TrendLineChart.swift
//  xT
//
//  Reusable multi-series line chart for longitudinal trend analysis.
//  Plots one or more TrendSeries with milestone annotations and legend.
//

import SwiftUI

struct TrendLineChart: View {
    let series: [TrendSeries]
    let xAxisLabel: String  // e.g., "Months on HRT"
    let showMilestones: Bool
    let milestones: [(label: String, months: Double)]  // milestone name → months

    private let padding: CGFloat = 40

    init(
        series: [TrendSeries],
        xAxisLabel: String = "Months on HRT",
        showMilestones: Bool = false,
        milestones: [(label: String, months: Double)] = []
    ) {
        self.series = series
        self.xAxisLabel = xAxisLabel
        self.showMilestones = showMilestones
        self.milestones = milestones
    }

    var body: some View {
        VStack(spacing: 0) {
            // Legend
            if series.count > 1 {
                legendRow
                    .padding(.bottom, 8)
            }

            // Chart
            GeometryReader { geo in
                let w = geo.size.width - padding * 2
                let h = geo.size.height - padding * 2

                let allPoints = series.flatMap(\.points)

                if allPoints.isEmpty {
                    Rectangle()
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            Text("No trend data available")
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        )
                } else {
                    let monthsValues = allPoints.map(\.monthsOnHRT)
                    let dataValues = allPoints.map(\.value)
                    let minMonth = (monthsValues.min() ?? 0)
                    let maxMonth = max((monthsValues.max() ?? 1), 1)
                    let monthRange = max(maxMonth - minMonth, 0.001)

                    let minVal = (dataValues.min() ?? 0) * 0.9
                    let maxVal = (dataValues.max() ?? 1) * 1.1
                    let valRange = max(maxVal - minVal, 0.001)

                    ZStack {
                        // Grid lines
                        gridLines(w: w, h: h)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)

                        // Milestone lines
                        if showMilestones {
                            milestoneLines(w: w, h: h, minMonth: minMonth, monthRange: monthRange)
                        }

                        // Series lines
                        ForEach(series) { s in
                            linePath(series: s, w: w, h: h, minMonth: minMonth,
                                     monthRange: monthRange, minVal: minVal, valRange: valRange)
                                .stroke(s.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }

                        // Dot markers on each point
                        ForEach(series) { s in
                            ForEach(s.points) { pt in
                                let px = padding + (pt.monthsOnHRT - minMonth) / monthRange * w
                                let py = padding + h - (pt.value - minVal) / valRange * h
                                Circle()
                                    .fill(s.color)
                                    .frame(width: 5, height: 5)
                                    .position(x: px, y: py)
                            }
                        }

                        // Axis labels
                        axisLabels(w: w, h: h, minMonth: minMonth, maxMonth: maxMonth,
                                   minVal: minVal, maxVal: maxVal, valRange: valRange)
                    }
                    .padding(padding)
                }
            }
            .frame(height: 220)

            // X-axis label
            Text(xAxisLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            ForEach(series) { s in
                HStack(spacing: 5) {
                    Circle()
                        .fill(s.color)
                        .frame(width: 8, height: 8)
                    Text(s.name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, padding)
    }

    // MARK: - Grid

    private func gridLines(w: CGFloat, h: CGFloat) -> Path {
        Path { path in
            let steps = 4
            for i in 0...steps {
                let x = CGFloat(i) / CGFloat(steps) * w
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: h))
            }
            for i in 0...steps {
                let y = CGFloat(i) / CGFloat(steps) * h
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: w, y: y))
            }
        }
    }

    // MARK: - Milestone lines

    private func milestoneLines(w: CGFloat, h: CGFloat, minMonth: Double, monthRange: Double) -> some View {
        ForEach(milestones, id: \.label) { m in
            let px = (m.months - minMonth) / monthRange * w
            if px >= 0, px <= w {
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.3))
                    .frame(width: 1)
                    .overlay(alignment: .top) {
                        Text(m.label)
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.Colors.accent.opacity(0.6))
                            .fixedSize()
                            .offset(y: -14)
                    }
                    .position(x: px, y: h / 2)
            }
        }
    }

    // MARK: - Line path

    private func linePath(series: TrendSeries, w: CGFloat, h: CGFloat,
                          minMonth: Double, monthRange: Double,
                          minVal: Double, valRange: Double) -> Path {
        Path { path in
            let sorted = series.points.sorted { $0.monthsOnHRT < $1.monthsOnHRT }
            for (i, pt) in sorted.enumerated() {
                let x = (pt.monthsOnHRT - minMonth) / monthRange * w
                let y = h - (pt.value - minVal) / valRange * h
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    let prev = sorted[i - 1]
                    let px = (prev.monthsOnHRT - minMonth) / monthRange * w
                    let py = h - (prev.value - minVal) / valRange * h
                    let ctrl1 = CGPoint(x: px + (x - px) * 0.5, y: py)
                    let ctrl2 = CGPoint(x: px + (x - px) * 0.5, y: y)
                    path.addCurve(to: CGPoint(x: x, y: y), control1: ctrl1, control2: ctrl2)
                }
            }
        }
    }

    // MARK: - Axis labels

    private func axisLabels(w: CGFloat, h: CGFloat, minMonth: Double, maxMonth: Double,
                            minVal: Double, maxVal: Double, valRange: Double) -> some View {
        ZStack {
            // X-axis
            Text(String(format: "%.0f", minMonth))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: 0, y: h + 16)

            Text(String(format: "%.0f", maxMonth))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: w, y: h + 16)

            // Y-axis
            Text(String(format: "%.0f", minVal))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: -20, y: h)

            Text(String(format: "%.0f", maxVal))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: -20, y: 0)
        }
    }
}

#Preview {
    TrendLineChart(
        series: [
            TrendSeries(
                name: "Skin & Hair",
                points: [
                    TrendPoint(date: Date(), value: 2, label: nil, monthsOnHRT: 1),
                    TrendPoint(date: Date(), value: 4, label: nil, monthsOnHRT: 3),
                    TrendPoint(date: Date(), value: 6, label: nil, monthsOnHRT: 6),
                    TrendPoint(date: Date(), value: 8, label: nil, monthsOnHRT: 9),
                ],
                color: Theme.Colors.Time.skin.base,
                unit: "/10"
            ),
            TrendSeries(
                name: "Body Shape",
                points: [
                    TrendPoint(date: Date(), value: 1, label: nil, monthsOnHRT: 1),
                    TrendPoint(date: Date(), value: 2, label: nil, monthsOnHRT: 3),
                    TrendPoint(date: Date(), value: 5, label: nil, monthsOnHRT: 6),
                    TrendPoint(date: Date(), value: 7, label: nil, monthsOnHRT: 9),
                ],
                color: Theme.Colors.Time.body.base,
                unit: "/10"
            ),
        ],
        showMilestones: true,
        milestones: [
            ("Breast growth", 3),
            ("Fat redistribution", 6),
        ]
    )
    .padding()
}
