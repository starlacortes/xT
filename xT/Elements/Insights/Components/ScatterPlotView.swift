//
//  ScatterPlotView.swift
//  xT
//
//  Reusable scatter plot chart for correlation analysis.
//  Plots (x, y) points with optional regression line and R² annotation.
//

import SwiftUI

struct ScatterPlotView: View {
    let points: [CorrelationPoint]
    let varA: InsightVariable
    let varB: InsightVariable
    let r: Double
    let rSquared: Double
    let slope: Double
    let intercept: Double
    let sampleSize: Int

    private let pointRadius: CGFloat = 5
    private let padding: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            // Chart canvas
            GeometryReader { geo in
                let w = geo.size.width - padding * 2
                let h = geo.size.height - padding * 2

                let valsX = points.map(\.x)
                let valsY = points.map(\.y)
                let minX = (valsX.min() ?? 0) - (valsX.max() ?? 0 - (valsX.min() ?? 0)) * 0.05
                let maxX = (valsX.max() ?? 1) + (valsX.max() ?? 0 - (valsX.min() ?? 0)) * 0.05
                let minY = (valsY.min() ?? 0) - (valsY.max() ?? 0 - (valsY.min() ?? 0)) * 0.05
                let maxY = (valsY.max() ?? 1) + (valsY.max() ?? 0 - (valsY.min() ?? 0)) * 0.05
                let rangeX = max(maxX - minX, 0.001)
                let rangeY = max(maxY - minY, 0.001)

                ZStack {
                    // Grid lines
                    gridLines(w: w, h: h, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)

                    // Regression line
                    if sampleSize >= 3 {
                        regressionLinePath(w: w, h: h, minX: minX, maxX: maxX, rangeX: rangeX, rangeY: rangeY, minY: minY)
                            .stroke(Theme.Colors.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }

                    // Scatter points
                    ForEach(points) { pt in
                        let px = padding + (pt.x - minX) / rangeX * w
                        let py = padding + h - (pt.y - minY) / rangeY * h
                        Circle()
                            .fill(Theme.Colors.accent.opacity(0.6))
                            .frame(width: pointRadius * 2, height: pointRadius * 2)
                            .position(x: px, y: py)
                    }

                    // Axis labels
                    axisLabels(w: w, h: h, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                }
                .padding(padding)
            }
            .frame(height: 240)

            // Stats bar
            statsRow
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }

    // MARK: - Grid lines

    private func gridLines(w: CGFloat, h: CGFloat, minX: Double, maxX: Double,
                           minY: Double, maxY: Double) -> Path {
        Path { path in
            let steps = 4
            for i in 0...steps {
                let x = padding + CGFloat(i) / CGFloat(steps) * w
                path.move(to: CGPoint(x: x, y: padding))
                path.addLine(to: CGPoint(x: x, y: padding + h))
            }
            for i in 0...steps {
                let y = padding + CGFloat(i) / CGFloat(steps) * h
                path.move(to: CGPoint(x: padding, y: y))
                path.addLine(to: CGPoint(x: padding + w, y: y))
            }
        }
    }

    // MARK: - Regression line

    private func regressionLinePath(w: CGFloat, h: CGFloat, minX: Double, maxX: Double,
                                     rangeX: Double, rangeY: Double, minY: Double) -> Path {
        let y1 = intercept + slope * minX
        let y2 = intercept + slope * maxX
        let px1 = padding + (minX - minX) / rangeX * w
        let py1 = padding + h - (y1 - minY) / rangeY * h
        let px2 = padding + (maxX - minX) / rangeX * w
        let py2 = padding + h - (y2 - minY) / rangeY * h

        return Path { path in
            path.move(to: CGPoint(x: px1, y: py1))
            path.addLine(to: CGPoint(x: px2, y: py2))
        }
    }

    // MARK: - Axis labels

    private func axisLabels(w: CGFloat, h: CGFloat, minX: Double, maxX: Double,
                            minY: Double, maxY: Double) -> some View {
        ZStack {
            let minXi = String(format: "%.0f", minX)
            let maxXi = String(format: "%.0f", maxX)
            let minYi = String(format: "%.0f", minY)
            let maxYi = String(format: "%.0f", maxY)

            Text(minXi)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: padding, y: padding + h + 16)

            Text(maxXi)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: padding + w, y: padding + h + 16)

            Text(minYi)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: padding - 20, y: padding + h)

            Text(maxYi)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .position(x: padding - 20, y: padding)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 16) {
            statBadge(label: "r", value: String(format: "%.3f", r))
            statBadge(label: "R²", value: String(format: "%.3f", rSquared))
            statBadge(label: "n", value: "\(sampleSize)")
            statBadge(label: "β₁", value: String(format: "%.2f", slope))
            Spacer()
        }
    }

    private func statBadge(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ScatterPlotView(
        points: [
            CorrelationPoint(x: 1, y: 2, label: "A"),
            CorrelationPoint(x: 2, y: 4, label: "B"),
            CorrelationPoint(x: 3, y: 5, label: "C"),
            CorrelationPoint(x: 4, y: 7, label: "D"),
            CorrelationPoint(x: 5, y: 9, label: "E"),
        ],
        varA: .monthsOnHRT,
        varB: .moodValence,
        r: 0.98,
        rSquared: 0.96,
        slope: 1.7,
        intercept: 0.4,
        sampleSize: 5
    )
    .padding()
}