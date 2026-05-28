//
//  GraphView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//  Enhanced interactive graph view with detailed hormone level visualization
//

import SwiftUI
import Charts

struct GraphView: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var selectedDay: Int = 2
    @State private var showingTooltip = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipValue: Double = 0

    private var days: [Int] {
        return Array(0...6)
    }

    private var levels: [Double] {
        return days.map { day in
            let peak = 280.0, base = 90.0, halfLife = 3.5
            if day == 0 {
                return 160.0
            }
            let spike = (peak - base) * exp(-Double(day) / halfLife)
            return base + spike + 20 * sin(Double(day) * 0.8)
        }
    }

    private var labels: [String] {
        return ["Dose", "Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6"]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GraphCardView(
                    selectedDay: $selectedDay,
                    showingTooltip: $showingTooltip,
                    tooltipPosition: $tooltipPosition,
                    tooltipValue: $tooltipValue,
                    levels: levels,
                    labels: labels
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Graph")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.secondarySystemBackground))
        .onAppear {
            updateTooltip()
        }
    }

    private func updateTooltip() {
        tooltipValue = levels[selectedDay]
        showingTooltip = true

        // Calculate tooltip position
        let widthPerDay = UIScreen.main.bounds.width / CGFloat(levels.count - 1)
        tooltipPosition = CGPoint(
            x: CGFloat(selectedDay) * widthPerDay,
            y: getYPosition(for: tooltipValue, in: 180) - 30
        )

        // Hide tooltip after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingTooltip = false
        }
    }

    private func getYPosition(for value: Double, in height: CGFloat) -> CGFloat {
        let minValue: Double = 40
        let maxValue: Double = 320
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        return height - CGFloat(normalizedValue) * height
    }

    private func getRangeText(for value: Double) -> String {
        if value < 50 { return "Very low" }
        else if value < 100 { return "Low" }
        else if value < 200 { return "Optimal" }
        else if value < 500 { return "High" }
        else { return "Very high" }
    }

    private func getRangeColor(for value: Double) -> Color {
        if value < 100 { return Color(red: 0.52, green: 0.31, blue: 0.07) }
        else if value < 200 { return Color(red: 0.23, green: 0.43, blue: 0.07) }
        else { return Color(red: 0.60, green: 0.21, blue: 0.33) }
    }
}

// MARK: - Graph Card View
struct GraphCardView: View {
    @Binding var selectedDay: Int
    @Binding var showingTooltip: Bool
    @Binding var tooltipPosition: CGPoint
    @Binding var tooltipValue: Double
    let levels: [Double]
    let labels: [String]

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Hormone level curve")
                .font(.system(size: 15))
                .fontWeight(.medium)
                .foregroundColor(.primary)

            // Subtitle
            Text("Estrogen · Injectable · 7-day cycle")
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))

            // Range indicators
            RangeIndicatorsView()

            // Chart area with tap gesture
            ChartAreaView(
                selectedDay: $selectedDay,
                showingTooltip: $showingTooltip,
                tooltipPosition: $tooltipPosition,
                tooltipValue: $tooltipValue,
                levels: levels
            )

            // Slider label
            Text("Scrub to a day")
                .font(.system(size: 12))
                .foregroundColor(Color(.tertiaryLabel))

            // Day slider
            Slider(value: Binding(
                get: { Double(selectedDay) },
                set: { newValue in
                    selectedDay = Int(newValue)
                }
            ), in: 0...6, step: 1)
            .tint(Color(red: 0.83, green: 0.32, blue: 0.49))

            // Day labels
            HStack {
                ForEach(0..<7) { day in
                    Text(labels[day])
                        .font(.system(size: 10))
                        .foregroundColor(day == selectedDay ? .primary : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }

            // Stats row
            StatsRowView(selectedDay: selectedDay, levels: levels)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.tertiarySystemFill), lineWidth: 0.5)
        )
    }
}

// MARK: - Range Indicators
struct RangeIndicatorsView: View {
    var body: some View {
        HStack(spacing: 6) {
            // Optimal range
            Text("Optimal 100–200")
                .font(.system(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.91, green: 0.95, blue: 0.87))
                .foregroundColor(Color(red: 0.23, green: 0.43, blue: 0.07))
                .cornerRadius(20)

            // Low range
            Text("Low <100")
                .font(.system(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.98, green: 0.93, blue: 0.85))
                .foregroundColor(Color(red: 0.52, green: 0.31, blue: 0.07))
                .cornerRadius(20)

            // High range
            Text("High >200")
                .font(.system(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.98, green: 0.92, blue: 0.94))
                .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
                .cornerRadius(20)
        }
    }
}

// MARK: - Chart Area
struct ChartAreaView: View {
    @Binding var selectedDay: Int
    @Binding var showingTooltip: Bool
    @Binding var tooltipPosition: CGPoint
    @Binding var tooltipValue: Double
    let levels: [Double]

    var body: some View {
        ZStack {
            // Chart
            GeometryReader { geometry in
                let chartHeight = geometry.size.height

                // Optimal range background
                let optimalMinY = getYPosition(for: 100, in: chartHeight)
                let optimalMaxY = getYPosition(for: 200, in: chartHeight)

                Rectangle()
                    .fill(Color(red: 0.91, green: 0.95, blue: 0.87).opacity(0.3))
                    .frame(height: optimalMaxY - optimalMinY)
                    .position(x: geometry.size.width / 2,
                             y: optimalMinY + (optimalMaxY - optimalMinY) / 2)

                // Grid lines for optimal range
                Path { path in
                    path.move(to: CGPoint(x: 0, y: optimalMinY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: optimalMinY))
                    path.move(to: CGPoint(x: 0, y: optimalMaxY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: optimalMaxY))
                }
                .stroke(Color(red: 0.23, green: 0.43, blue: 0.07).opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

                // Hormone curve with gradient fill
                let curvePath = createCurvePath(in: geometry.size)

                // Gradient fill
                Path { path in
                    path.addPath(curvePath)
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Color(red: 0.83, green: 0.32, blue: 0.49).opacity(0.12),
                        Color(red: 0.83, green: 0.32, blue: 0.49).opacity(0.05)
                    ]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                // Curve line
                curvePath
                    .stroke(Color(red: 0.83, green: 0.32, blue: 0.49), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Data points
                ForEach(0..<levels.count, id: \.self) { index in
                    let level = levels[index]
                    let x = CGFloat(index) * (geometry.size.width / CGFloat(levels.count - 1))
                    let y = getYPosition(for: level, in: chartHeight)

                    Circle()
                        .fill(Color(red: 0.83, green: 0.32, blue: 0.49))
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }

                // Selected day marker
                let selectedX = CGFloat(selectedDay) * (geometry.size.width / CGFloat(levels.count - 1))
                let selectedY = getYPosition(for: levels[selectedDay], in: chartHeight)

                // Vertical guide line
                Rectangle()
                    .fill(Color(red: 0.83, green: 0.32, blue: 0.49).opacity(0.2))
                    .frame(width: 1, height: chartHeight)
                    .position(x: selectedX, y: chartHeight / 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedDay)

                // Selected point marker
                Circle()
                    .fill(Color(red: 0.83, green: 0.32, blue: 0.49))
                    .frame(width: 14, height: 14)
                    .position(x: selectedX, y: selectedY)
                    .animation(.easeInOut(duration: 0.2), value: selectedDay)

                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .position(x: selectedX, y: selectedY)
                    .animation(.easeInOut(duration: 0.2), value: selectedDay)
            }
            .frame(height: 180)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleChartTap(location: location)
            }

            // Tooltip
            if showingTooltip {
                TooltipView(value: tooltipValue)
                    .position(x: tooltipPosition.x, y: tooltipPosition.y)
                    .transition(.opacity)
            }
        }
    }

    private func createCurvePath(in size: CGSize) -> Path {
        var path = Path()
        let width = size.width
        let height = size.height

        for (index, level) in levels.enumerated() {
            let x = CGFloat(index) * (width / CGFloat(levels.count - 1))
            let y = getYPosition(for: level, in: height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                // Create smooth curve using quadratic Bézier
                let prevX = CGFloat(index - 1) * (width / CGFloat(levels.count - 1))
                let prevY = getYPosition(for: levels[index - 1], in: height)

                let controlX = prevX + (x - prevX) / 2
                let controlY = prevY

                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: controlX, y: controlY))
            }
        }

        return path
    }

    private func getYPosition(for value: Double, in height: CGFloat) -> CGFloat {
        let minValue: Double = 40
        let maxValue: Double = 320
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        return height - CGFloat(normalizedValue) * height
    }

    private func handleChartTap(location: CGPoint) {
        // Convert tap location to day index
        let widthPerDay = UIScreen.main.bounds.width / CGFloat(levels.count - 1)
        let tappedDay = Int(location.x / widthPerDay)
        selectedDay = max(0, min(6, tappedDay))
    }
}

// MARK: - Tooltip View
struct TooltipView: View {
    let value: Double

    private func getRangeText(for value: Double) -> String {
        if value < 50 { return "Very low" }
        else if value < 100 { return "Low" }
        else if value < 200 { return "Optimal" }
        else if value < 500 { return "High" }
        else { return "Very high" }
    }

    private func getRangeColor(for value: Double) -> Color {
        if value < 100 { return Color(red: 0.52, green: 0.31, blue: 0.07) }
        else if value < 200 { return Color(red: 0.23, green: 0.43, blue: 0.07) }
        else { return Color(red: 0.60, green: 0.21, blue: 0.33) }
    }

    var body: some View {
        VStack(alignment: .center) {
            Text("\(Int(value)) pg/mL")
                .font(.system(size: 12))
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text(getRangeText(for: value))
                .font(.system(size: 10))
                .foregroundColor(getRangeColor(for: value))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.tertiarySystemFill), lineWidth: 0.5)
        )
    }
}

// MARK: - Stats Row
struct StatsRowView: View {
    let selectedDay: Int
    let levels: [Double]

    private func getRangeText(for value: Double) -> String {
        if value < 50 { return "Very low" }
        else if value < 100 { return "Low" }
        else if value < 200 { return "Optimal" }
        else if value < 500 { return "High" }
        else { return "Very high" }
    }

    private func getRangeColor(for value: Double) -> Color {
        if value < 100 { return Color(red: 0.52, green: 0.31, blue: 0.07) }
        else if value < 200 { return Color(red: 0.23, green: 0.43, blue: 0.07) }
        else { return Color(red: 0.60, green: 0.21, blue: 0.33) }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Current value
            VStack(spacing: 2) {
                Text(selectedDay == 0 ? "—" : "\(Int(levels[selectedDay]))")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("pg/mL")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            // Range
            VStack(spacing: 2) {
                Text(getRangeText(for: levels[selectedDay]))
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .foregroundColor(getRangeColor(for: levels[selectedDay]))

                Text("range")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)

            // Day of cycle
            VStack(spacing: 2) {
                Text(selectedDay == 0 ? "Dose" : "Day \(selectedDay)")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("of cycle")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

#Preview {
    NavigationStack {
        GraphView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}