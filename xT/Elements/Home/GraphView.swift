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
    var isFullScreen: Bool = false
    @State private var selectedDay: Int = 2
    @State private var showingTooltip = false
    @State private var tooltipPosition: CGPoint = .zero
    @State private var tooltipValue: Double = 0

    private var levels: [Double] {
        return medicationManager.recentLevels.map { $0.value }
    }

    private var labels: [String] {
        let calendar = Calendar.current
        return medicationManager.recentLevels.enumerated().map { index, point in
            if index == 0 {
                return "Dose"
            } else {
                let day = calendar.dateComponents([.day], from: point.date, to: Date()).day ?? index
                return "Day \(day)"
            }
        }
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
                    labels: labels,
                    medicationName: medicationManager.medicationName,
                    administrationMethod: medicationManager.selectedAdministrationMethod,
                    isFullScreen: isFullScreen
                )
                .padding(.horizontal, isFullScreen ? 0 : 16)
                .padding(.top, isFullScreen ? 0 : 16)
            }
        }
        .navigationTitle("Graph")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.Gradients.brand)
        .onAppear {
            updateTooltip()
        }
    }

    private func updateTooltip() {
        tooltipValue = levels[selectedDay]
        showingTooltip = true

        // Calculate tooltip position using GeometryReader-safe sizing
        let widthPerDay = 1000.0 / CGFloat(levels.count - 1)
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
    let medicationName: String
    let administrationMethod: String?
    var isFullScreen: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            GraphHeaderView(medicationName: medicationName, administrationMethod: administrationMethod)
            RangeIndicatorsView()

            ChartAreaView(
                selectedDay: $selectedDay,
                showingTooltip: $showingTooltip,
                tooltipPosition: $tooltipPosition,
                tooltipValue: $tooltipValue,
                levels: levels
            )

            GraphSliderView(selectedDay: $selectedDay, labels: labels)
            StatsRowView(selectedDay: selectedDay, levels: levels)
        }
        .padding(16)
        .background(isFullScreen ? Color.clear : Color(UIColor.systemBackground).opacity(0.8))
        .cornerRadius(isFullScreen ? 0 : Theme.Radius.lg)
        .overlay(
            Group {
                if !isFullScreen {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                }
            }
        )
    }
}

// MARK: - Graph Header View
struct GraphHeaderView: View {
    let medicationName: String
    let administrationMethod: String?

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Hormone level curve")
                .font(.system(size: 15))
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Subtitle
            Text("\(medicationName) · \(administrationMethod ?? "Unknown") · \(administrationMethod == "Injectable" ? "7-day" : "Daily") cycle")
                .font(.system(size: 12))
                .foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

// MARK: - Graph Slider View
struct GraphSliderView: View {
    @Binding var selectedDay: Int
    let labels: [String]

    var body: some View {
        VStack(spacing: 8) {
            // Slider label
            Text("Scrub to a day")
                .font(.system(size: 12))
                .foregroundStyle(Color(.tertiaryLabel))

            // Day slider
            Slider(value: Binding(
                get: { Double(selectedDay) },
                set: { newValue in
                    selectedDay = Int(newValue)
                }
            ), in: 0...Double(labels.count - 1), step: 1)
            .tint(Theme.Colors.accent)

            // Day labels
            HStack {
                ForEach(0..<labels.count, id: \.self) { day in
                    Text(labels[day])
                        .font(.system(size: 10))
                        .foregroundStyle(day == selectedDay ? .primary : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }
        }
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
                .background(Theme.Colors.success.opacity(0.2))
                .foregroundStyle(Theme.Colors.success)
                .cornerRadius(Theme.Radius.sm)

            // Low range
            Text("Low <100")
                .font(.system(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.Bloom.body.surface)
                .foregroundStyle(Theme.Colors.Bloom.body.base)
                .cornerRadius(Theme.Radius.sm)

            // High range
            Text("High >200")
                .font(.system(size: 11))
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.Bloom.cycle.surface)
                .foregroundStyle(Theme.Colors.Bloom.cycle.base)
                .cornerRadius(Theme.Radius.sm)
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
                    .fill(Theme.Colors.success.opacity(0.1))
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
                .stroke(Theme.Colors.success.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

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
                        Theme.Colors.accent.opacity(0.12),
                        Theme.Colors.accent.opacity(0.05)
                    ]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                // Curve line
                curvePath
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Data points
                ForEach(0..<levels.count, id: \.self) { index in
                    let level = levels[index]
                    let x = CGFloat(index) * (geometry.size.width / CGFloat(levels.count - 1))
                    let y = getYPosition(for: level, in: chartHeight)

                    Circle()
                        .fill(Theme.Colors.accent)
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }

                // Selected day marker
                let selectedX = CGFloat(selectedDay) * (geometry.size.width / CGFloat(levels.count - 1))
                let selectedY = getYPosition(for: levels[selectedDay], in: chartHeight)

                // Vertical guide line
                Rectangle()
                    .fill(Theme.Colors.accent.opacity(0.2))
                    .frame(width: 1, height: chartHeight)
                    .position(x: selectedX, y: chartHeight / 2)
                    .animation(.easeInOut(duration: 0.2), value: selectedDay)

                // Selected point marker
                Circle()
                    .fill(Theme.Colors.accent)
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
        // Using widthPerDay consistent with updateTooltip
        let widthPerDay = 1000.0 / CGFloat(levels.count - 1)
        let tappedDay = Int(location.x / widthPerDay)
        selectedDay = max(0, min(levels.count - 1, tappedDay))
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
        if value < 100 { return Theme.Colors.Bloom.body.base }
        else if value < 200 { return Theme.Colors.success }
        else { return Theme.Colors.Bloom.cycle.base }
    }

    var body: some View {
        VStack(alignment: .center) {
            Text("\(Int(value)) pg/mL")
                .font(.system(size: 12))
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text(getRangeText(for: value))
                .font(.system(size: 10))
                .foregroundStyle(getRangeColor(for: value))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.border, lineWidth: 0.5)
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
        if value < 100 { return Theme.Colors.Bloom.body.base }
        else if value < 200 { return Theme.Colors.success }
        else { return Theme.Colors.Bloom.cycle.base }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Current value
            VStack(spacing: 2) {
                Text(selectedDay == 0 ? "—" : "\(Int(levels[selectedDay]))")
                    .font(.system(size: 18))
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("pg/mL")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
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
                    .foregroundStyle(getRangeColor(for: levels[selectedDay]))

                Text("range")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
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
                    .foregroundStyle(.primary)

                Text("of cycle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(.tertiaryLabel))
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
