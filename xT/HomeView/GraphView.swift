//
//  GraphView.swift
//  xT
//
//  Created by starrrr on 8/5/25.
//

import SwiftUI
import Charts

struct GraphView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var scrollPosition: Double = 0
    @State private var selectedPoint: MedicationManager.EstimatedPoint? = nil

    private var series: [MedicationManager.EstimatedPoint] {
        // Generate data for 7 days to show the parabolic curve
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        return medicationManager.estimatedLevels(from: start, to: end, stepDays: 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Simplified header
                Text("Hormone Level Trends")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.purple)
                    .padding(.bottom, 8)

                if medicationManager.selectedMedication == nil || medicationManager.selectedAdministrationMethod == nil {
                    NoSelectionView()
                } else {
                    // Simplified medication info
                    SimplifiedMedicationInfoView()

                    // Enhanced Chart with better visual hierarchy
                    VStack(alignment: .leading, spacing: 12) {
                        // Improved time navigation
                        TimeNavigationControl(scrollPosition: $scrollPosition)

                        // Simplified parabolic chart
                        SimplifiedHormoneChart(series: series, scrollPosition: $scrollPosition)
                            .frame(height: 300)

                        // Current range information
                        if !series.isEmpty, let currentLevel = series.last?.value {
                            CurrentRangeInfoBox(currentLevel: currentLevel)
                        }
                    }

                    // Enhanced experience section
                    ExperienceSectionWithoutTimeline(series: series)
                }
            }
            .padding()
        }
        .navigationTitle("Graph")
        .background(Color(UIColor.systemBackground))
    }
}

// Simplified Medication Info
struct SimplifiedMedicationInfoView: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(medicationManager.medicationName)
                    .font(.headline)

                Text(medicationManager.selectedAdministrationMethod ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(medicationManager.dosageInfo)
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Improved Time Navigation
struct TimeNavigationControl: View {
    @Binding var scrollPosition: Double

    private let dayLabels = ["Today", "Day 1", "Day 2", "Day 3", "Day 4", "Day 5", "Day 6", "Day 7"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-Day Cycle")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Visual time indicator
            HStack(spacing: 0) {
                ForEach(0..<8) { index in
                    VStack(spacing: 4) {
                        Text(dayLabels[index])
                            .font(.caption)
                            .foregroundColor(index == Int(scrollPosition) ? .purple : .secondary)

                        Rectangle()
                            .fill(index <= Int(scrollPosition) ? Color.purple : Color.gray.opacity(0.2))
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        scrollPosition = Double(index)
                    }
                }
            }

            Slider(value: $scrollPosition, in: 0...7, step: 1)
                .padding(.horizontal, 8)
        }
    }
}

// Simplified Hormone Chart
struct SimplifiedHormoneChart: View {
    let series: [MedicationManager.EstimatedPoint]
    @Binding var scrollPosition: Double
    @Environment(\.medicationManager) private var medicationManager

    private var parabolicPoints: [ParabolicPoint] {
        guard !series.isEmpty else { return [] }

        let baseline = series.first?.value ?? 100
        let peak = baseline * 1.8 // 80% increase at peak
        let halfLifeDays = 7.0

        var points: [ParabolicPoint] = []

        // Add points for 7 days
        for i in 0..<100 { // 100 points for smooth curve
            let day = Double(i) * 0.07 // 7 days total
            let x = day

            // Parabolic curve formula: y = baseline + peak * (1 - (x/halfLife)^2)
            let normalizedX = min(abs(x) / (halfLifeDays / 2), 1.0)
            let y = baseline + (peak - baseline) * (1 - pow(normalizedX, 2))

            points.append(ParabolicPoint(x: x, y: y))
        }

        return points
    }

    private var currentPoint: ParabolicPoint? {
        let index = Int(scrollPosition * 14.28) // 100 points / 7 days
        guard index >= 0 && index < parabolicPoints.count else { return nil }
        return parabolicPoints[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Optimal range indicator
            OptimalRangeIndicator()

            // Chart area
            GeometryReader { geometry in
                ZStack {
                    // Optimal range background
                    let optimalRange = getOptimalRange()
                    let minY = optimalRange.min
                    let maxY = optimalRange.max
                    let totalRange = parabolicPoints.map { $0.y }.max() ?? 1

                    Rectangle()
                        .fill(Color.green.opacity(0.1))
                        .frame(height: CGFloat((maxY - minY) / totalRange) * geometry.size.height)
                        .position(x: geometry.size.width / 2,
                                 y: geometry.size.height - CGFloat(minY / totalRange) * geometry.size.height - (CGFloat((maxY - minY) / totalRange) * geometry.size.height) / 2)

                    // Parabolic curve
                    Path { path in
                        for (index, point) in parabolicPoints.enumerated() {
                            let x = CGFloat(index) * (geometry.size.width / CGFloat(parabolicPoints.count - 1))
                            let y = geometry.size.height - CGFloat(point.y / totalRange) * geometry.size.height

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.purple, lineWidth: 3)
                    .shadow(color: Color.purple.opacity(0.3), radius: 3)

                    // Current position marker
                    if let currentPoint = currentPoint {
                        let x = CGFloat(Int(scrollPosition) * 14) * (geometry.size.width / CGFloat(parabolicPoints.count - 1))
                        let y = geometry.size.height - CGFloat(currentPoint.y / totalRange) * geometry.size.height

                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .position(x: x, y: y)

                        // Vertical guide line
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 1, height: geometry.size.height)
                            .position(x: x, y: geometry.size.height / 2)
                    }
                }
            }
            .frame(height: 250)

            // Current level annotation
            if let currentPoint = currentPoint {
                HStack {
                    Text("Current: \(Int(currentPoint.y)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.red)

                    Spacer()

                    Text("Day \(Int(scrollPosition)) of 7")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func getOptimalRange() -> (min: Double, max: Double) {
        guard let medication = medicationManager.selectedMedication else {
            return (100, 200) // Default estrogen optimal range
        }

        if medication == "Estrogen" {
            return (100, 200)
        } else {
            return (0, 50) // Testosterone suppression range
        }
    }
}

// Optimal Range Indicator
struct OptimalRangeIndicator: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        if let medication = medicationManager.selectedMedication {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Optimal Range")
                        .font(.caption)
                        .bold()

                    if medication == "Estrogen" {
                        Text("100-200 pg/mL for feminization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("0-50 ng/dL for suppression")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("Target")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(4)
            }
            .padding(8)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct NoSelectionView: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Selection")
                .font(.headline)
            Text("Select a medication type and method to view estimated levels.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct MedicationInfoView: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Medication")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Text(medicationManager.medicationName)
                    .font(.headline)
                Text("•")
                    .foregroundColor(.gray)
                Text(medicationManager.selectedAdministrationMethod ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Dosage: \(medicationManager.dosageInfo)")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// Current Range Info Box for the top section
struct CurrentRangeInfoBox: View {
    let currentLevel: Double
    @Environment(\.medicationManager) private var medicationManager

    private var hormoneLevelRanges: [HormoneLevelRange] {
        guard let medication = medicationManager.selectedMedication else {
            return []
        }

        if medication == "Estrogen" {
            return [
                HormoneLevelRange(name: "Very Low", min: 0, max: 50, description: ""),
                HormoneLevelRange(name: "Low", min: 50, max: 100, description: ""),
                HormoneLevelRange(name: "Optimal", min: 100, max: 200, description: ""),
                HormoneLevelRange(name: "High", min: 200, max: 500, description: ""),
                HormoneLevelRange(name: "Very High", min: 500, max: 1000, description: "")
            ]
        } else {
            return [
                HormoneLevelRange(name: "Suppressed", min: 0, max: 50, description: ""),
                HormoneLevelRange(name: "Low Male", min: 50, max: 200, description: ""),
                HormoneLevelRange(name: "Male Range", min: 200, max: 800, description: ""),
                HormoneLevelRange(name: "High Male", min: 800, max: 1200, description: "")
            ]
        }
    }

    var body: some View {
        if let currentRange = hormoneLevelRanges.first(where: { $0.min <= currentLevel && $0.max >= currentLevel }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentRange.name)
                            .font(.headline)
                            .bold()
                            .foregroundColor(rangeColor(for: currentRange.name))

                        Text("\(Int(currentRange.min))-\(Int(currentRange.max)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: rangeIcon(for: currentRange.name))
                        .font(.system(size: 32))
                        .foregroundColor(rangeColor(for: currentRange.name))
                        .padding(4)
                        .background(rangeColor(for: currentRange.name).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .frame(minWidth: 0, maxWidth: .infinity)
        }
    }
}

struct ParabolicHormoneChart: View {
    let series: [MedicationManager.EstimatedPoint]
    @Binding var scrollPosition: Double
    @Environment(\.medicationManager) private var medicationManager

    // Generate smooth parabolic curve points with extension before current day
    private var parabolicPoints: [ParabolicPoint] {
        guard !series.isEmpty else { return [] }

        let baseline = series.first?.value ?? 100
        let peak = baseline * 1.8 // 80% increase at peak
        let halfLifeDays = 7.0

        var points: [ParabolicPoint] = []

        // Add points before current day for visual continuity (negative x values)
        for i in -30..<100 { // 30 points before + 100 points for 7 days
            let day = Double(i) * 0.07 // 7 days total, negative for before current day
            let x = day

            // Parabolic curve formula: y = baseline + peak * (1 - (x/halfLife)^2)
            let normalizedX = min(abs(x) / (halfLifeDays / 2), 1.0)
            let y = baseline + (peak - baseline) * (1 - pow(normalizedX, 2))

            points.append(ParabolicPoint(x: x, y: y))
        }

        return points
    }

    // Get current point based on scroll position (only allow scrolling from day 0 onwards)
    private var currentPoint: ParabolicPoint? {
        let index = Int(scrollPosition * 14.28) + 30 // 100 points / 7 days, offset by 30 for pre-current points
        guard index >= 30 && index < parabolicPoints.count else { return nil } // Prevent scrolling before day 0
        return parabolicPoints[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hormone Level Trends")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Chart {
                // Parabolic curve
                ForEach(parabolicPoints) { point in
                    LineMark(
                        x: .value("Day", point.x),
                        y: .value("Level", point.y)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }

                // Current level dot
                if let currentPoint = currentPoint {
                    PointMark(
                        x: .value("Current Day", currentPoint.x),
                        y: .value("Current Level", currentPoint.y)
                    )
                    .symbolSize(150)
                    .foregroundStyle(.red)

                    // Annotation for current level
                    PointMark(
                        x: .value("Current Day", currentPoint.x),
                        y: .value("Current Level", currentPoint.y)
                    )
                    .annotation(position: .top) {
                        Text("Current: \(Int(currentPoint.y)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let day = value.as(Double.self) {
                            Text(String(format: "%.1f", day))
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

// Helper struct for parabolic points
struct ParabolicPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
}
struct HormoneLevelChart: View {
    let series: [MedicationManager.EstimatedPoint]
    let rangeInDays: Int
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hormone Level Trends")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Chart {
                // Main hormone level line
                ForEach(series) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Level", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Level", point.value)
                    )
                    .symbolSize(80)
                    .foregroundStyle(.blue)
                }

                // Current level indicator
                if let lastPoint = series.last {
                    RuleMark(
                        y: .value("Current", lastPoint.value)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .annotation(position: .top) {
                        Text("Current: \(Int(lastPoint.value)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, style: .date)
                                .font(.caption)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 300)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

struct ExperienceSection: View {
    let series: [MedicationManager.EstimatedPoint]
    @Environment(\.medicationManager) private var medicationManager

    private var hormoneLevelRanges: [HormoneLevelRange] {
        guard let medication = medicationManager.selectedMedication else {
            return []
        }

        // Define hormone level ranges based on research data
        if medication == "Estrogen" {
            return [
                HormoneLevelRange(name: "Very Low", min: 0, max: 50, description: "May experience hot flashes, mood changes, and defeminization effects"),
                HormoneLevelRange(name: "Low", min: 50, max: 100, description: "Suboptimal feminization, possible mood swings"),
                HormoneLevelRange(name: "Optimal", min: 100, max: 200, description: "Good feminization progress, stable mood"),
                HormoneLevelRange(name: "High", min: 200, max: 500, description: "Enhanced feminization, better testosterone suppression"),
                HormoneLevelRange(name: "Very High", min: 500, max: 1000, description: "Maximal effects but potential health risks")
            ]
        } else { // Testosterone
            return [
                HormoneLevelRange(name: "Suppressed", min: 0, max: 50, description: "Full testosterone suppression, optimal for feminization"),
                HormoneLevelRange(name: "Low Male", min: 50, max: 200, description: "Partial suppression, may need antiandrogen"),
                HormoneLevelRange(name: "Male Range", min: 200, max: 800, description: "Insufficient suppression, masculinization effects"),
                HormoneLevelRange(name: "High Male", min: 800, max: 1200, description: "Full masculinization, no feminization")
            ]
        }
    }

    var body: some View {
        if !hormoneLevelRanges.isEmpty, let currentLevel = series.last?.value {
            VStack(alignment: .leading, spacing: 12) {
                Text("What You May Be Experiencing")
                    .font(.headline)

                // Find the current range
                if let currentRange = hormoneLevelRanges.first(where: { $0.min <= currentLevel && $0.max >= currentLevel }) {
                    RangeInfoView(currentRange: currentRange)

                    Text("Expected Effects:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    Text(currentRange.description)
                        .font(.body)
                        .padding(.vertical, 4)

                    // Additional effects based on research
                    if medicationManager.selectedMedication == "Estrogen" {
                        EstrogenEffectsView(rangeName: currentRange.name)
                    } else {
                        TestosteroneEffectsView(rangeName: currentRange.name)
                    }

                    // Timeline of effects
                    if medicationManager.selectedMedication == "Estrogen" {
                        FeminizationTimelineView()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

// Experience section without timeline for GraphView
struct ExperienceSectionWithoutTimeline: View {
    let series: [MedicationManager.EstimatedPoint]
    @Environment(\.medicationManager) private var medicationManager

    private var hormoneLevelRanges: [HormoneLevelRange] {
        guard let medication = medicationManager.selectedMedication else {
            return []
        }

        if medication == "Estrogen" {
            return [
                HormoneLevelRange(name: "Very Low", min: 0, max: 50, description: "May experience hot flashes, mood changes, and defeminization effects"),
                HormoneLevelRange(name: "Low", min: 50, max: 100, description: "Suboptimal feminization, possible mood swings"),
                HormoneLevelRange(name: "Optimal", min: 100, max: 200, description: "Good feminization progress, stable mood"),
                HormoneLevelRange(name: "High", min: 200, max: 500, description: "Enhanced feminization, better testosterone suppression"),
                HormoneLevelRange(name: "Very High", min: 500, max: 1000, description: "Maximal effects but potential health risks")
            ]
        } else {
            return [
                HormoneLevelRange(name: "Suppressed", min: 0, max: 50, description: "Full testosterone suppression, optimal for feminization"),
                HormoneLevelRange(name: "Low Male", min: 50, max: 200, description: "Partial suppression, may need antiandrogen"),
                HormoneLevelRange(name: "Male Range", min: 200, max: 800, description: "Insufficient suppression, masculinization effects"),
                HormoneLevelRange(name: "High Male", min: 800, max: 1200, description: "Full masculinization, no feminization")
            ]
        }
    }

    var body: some View {
        if !hormoneLevelRanges.isEmpty, let currentLevel = series.last?.value {
            VStack(alignment: .leading, spacing: 12) {
                Text("What You May Be Experiencing")
                    .font(.headline)

                // Find the current range
                if let currentRange = hormoneLevelRanges.first(where: { $0.min <= currentLevel && $0.max >= currentLevel }) {
                    Text("Expected Effects:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    Text(currentRange.description)
                        .font(.body)
                        .padding(.vertical, 4)

                    // Additional effects based on research
                    if medicationManager.selectedMedication == "Estrogen" {
                        EstrogenEffectsView(rangeName: currentRange.name)
                    } else {
                        TestosteroneEffectsView(rangeName: currentRange.name)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

struct RangeInfoView: View {
    let currentRange: HormoneLevelRange
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Range:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(currentRange.name)
                    .font(.title3)
                    .bold()
                    .foregroundColor(rangeColor(for: currentRange.name))

                Text("\(Int(currentRange.min))-\(Int(currentRange.max)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: rangeIcon(for: currentRange.name))
                .font(.system(size: 48))
                .foregroundColor(rangeColor(for: currentRange.name))
                .padding(8)
                .background(rangeColor(for: currentRange.name).opacity(0.1))
                .cornerRadius(12)
        }
    }
}

struct EstrogenEffectsView: View {
    let rangeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if rangeName == "Optimal" || rangeName == "High" {
                Text("• Breast development progress")
                Text("• Feminine fat redistribution")
                Text("• Skin softening and reduced oiliness")
                Text("• Emotional changes and mood stabilization")
            } else if rangeName == "Very High" {
                Text("• Maximal feminization effects")
                Text("• Potential increased health risks (blood clots, etc.)")
                Text("• Regular monitoring recommended")
            } else {
                Text("• Suboptimal feminization progress")
                Text("• Possible mood swings and hot flashes")
                Text("• Consider dosage adjustment")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }
}

struct TestosteroneEffectsView: View {
    let rangeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if rangeName == "Suppressed" {
                Text("• Optimal conditions for feminization")
                Text("• Reduced masculinization effects")
                Text("• Emotional changes possible")
            } else if rangeName == "Low Male" {
                Text("• Partial suppression achieved")
                Text("• May need additional antiandrogen")
                Text("• Some masculinization effects may persist")
            } else {
                Text("• Insufficient testosterone suppression")
                Text("• Masculinization effects continue")
                Text("• Feminization progress limited")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }
}

struct FeminizationTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feminization Timeline")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                TimelineItem(effect: "Breast development", onset: "2-6 months", completion: "2-3 years")
                TimelineItem(effect: "Skin softening", onset: "3-6 months", completion: "Unknown")
                TimelineItem(effect: "Body fat redistribution", onset: "3-6 months", completion: "2-5 years")
                TimelineItem(effect: "Decreased muscle mass", onset: "3-6 months", completion: "1-2 years")
                TimelineItem(effect: "Emotional changes", onset: "Immediate", completion: "Unknown")
            }
        }
        .padding(.top, 8)
    }
}

// Helper functions
private func rangeColor(for rangeName: String) -> Color {
    switch rangeName {
    case "Very Low", "Suppressed": return .red
    case "Low", "Low Male": return .orange
    case "Optimal": return .green
    case "High", "Male Range": return .yellow
    case "Very High", "High Male": return .red
    default: return .blue
    }
}

private func rangeIcon(for rangeName: String) -> String {
    switch rangeName {
    case "Very Low", "Suppressed": return "exclamationmark.triangle.fill"
    case "Low", "Low Male": return "exclamationmark.circle.fill"
    case "Optimal": return "checkmark.circle.fill"
    case "High", "Male Range": return "arrow.up.circle.fill"
    case "Very High", "High Male": return "arrow.up.right.circle.fill"
    default: return "questionmark.circle.fill"
    }
}

struct HormoneLevelRange: Identifiable {
    let id = UUID()
    let name: String
    let min: Double
    let max: Double
    let description: String
}

struct TimelineItem: View {
    let effect: String
    let onset: String
    let completion: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("• \(effect):")
                .font(.caption)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Onset: \(onset)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Completion: \(completion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        GraphView()
    }
}
