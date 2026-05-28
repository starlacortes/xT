//
//  HomeView.swift
//  xT
//
//  Created by Starla Cortes on 8/5/25.
//  Redesigned home view with modern mobile interface
//

import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingGraphDetail = false

    var body: some View {
        
        
        NavigationStack {
            
            
            ScrollView {

                HomeContentView()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.93, green: 0.57, blue: 0.69), Color(red: 0.69, green: 0.66, blue: 0.92)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing))
    }
    
}


// MARK: - Home Content View
struct HomeContentView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        
        VStack(spacing: 0) {

            // Phone mockup container
            VStack(spacing: 0) {
                StatusBarView()

                HeaderView()

                MainContentView()
                    .padding(.top, 14)
            }
            .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.93, green: 0.57, blue: 0.69), Color(red: 0.69, green: 0.66, blue: 0.92)]),
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing))
            .cornerRadius(16)
            .padding(16)
        }
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    var body: some View {
        HStack {
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Header View
struct HeaderView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(spacing: 12) {
            // Profile section
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 0.93, green: 0.57, blue: 0.69), Color(red: 0.69, green: 0.66, blue: 0.92)]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                    .frame(width: 66, height: 66)
                    .clipShape(Circle())

                    Text(profileManager.profileDisplayName.prefix(1))
                        .font(.system(size: 18))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }

                // Profile info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi \(profileManager.profileDisplayName) ✦")
                        .font(.system(size: 22))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if medicationManager.isFullyConfigured {
                        Text(medicationManager.medicationDisplayInfo)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Notification bell
                Image(systemName: "bell")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }

            // Current level card
            if medicationManager.isFullyConfigured,
               let currentLevel = medicationManager.estimatedRecentLevels().last?.value {
                CurrentLevelCard(currentLevel: currentLevel)
            }
        }
        .padding(12)
        .background(Color.clear)
    }
}

// MARK: - Current Level Card
struct CurrentLevelCard: View {
    let currentLevel: Double

    var body: some View {
        NavigationLink(destination: GraphView()) {
            HStack(spacing: 12) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.92, blue: 0.94))
                        .frame(width: 36, height: 79)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
                }

                // Level info
                VStack(alignment: .leading, spacing: 2) {
                    Text("current level")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    HStack(spacing: 6) {
                        Text("\(Int(currentLevel))")
                            .font(.system(size: 22))
                            .fontWeight(.medium)
                            .foregroundColor(Color(red: 0.45, green: 0.14, blue: 0.24))

                        Text("pg/mL")
                            .font(.system(size: 12))
                            .foregroundColor(Color(.tertiaryLabel))

                        // Range indicator
                        let rangeText = getHormoneRangeText(level: currentLevel)
                        let rangeColor = getHormoneRangeColor(level: currentLevel)

                        Text(rangeText)
                            .font(.system(size: 11))
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(rangeColor.opacity(0.2))
                            .foregroundColor(rangeColor)
                            .cornerRadius(20)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.96, green: 0.75, blue: 0.82), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func getHormoneRangeText(level: Double) -> String {
        if level < 50 { return "Very low" }
        else if level < 100 { return "Low" }
        else if level < 200 { return "Optimal" }
        else if level < 500 { return "High" }
        else { return "Very high" }
    }

    private func getHormoneRangeColor(level: Double) -> Color {
        if level < 100 { return Color(red: 0.52, green: 0.31, blue: 0.07) }
        else if level < 200 { return Color(red: 0.23, green: 0.43, blue: 0.07) }
        else { return Color(red: 0.60, green: 0.21, blue: 0.33) }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        VStack(spacing: 10) {
            // 7-day trend card
            if medicationManager.isFullyConfigured {
                TrendCardView()
            }

            // Next dose card
            if medicationManager.isFullyConfigured,
               let nextDose = medicationManager.nextDoseDate {
                NextDoseCard(nextDose: nextDose)
            }

            // Today's journal card
            if let lastEntry = journalManager.lastEntry {
                JournalCardView(entry: lastEntry)
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Trend Card View
struct TrendCardView: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("7-day trend")
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: GraphView()) {
                    Text("View all")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            // Mini trend graph
            MiniTrendGraph()
                .frame(height: 122)
        }
        .padding(14)
        .background(Color.clear)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.tertiarySystemFill), lineWidth: 0.5)
        )
    }
}

// MARK: - Next Dose Card
struct NextDoseCard: View {
    let nextDose: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("next dose")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))

                Text(nextDose, style: .date)
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("in")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))

                let daysUntilNextDose = Calendar.current.dateComponents([.day], from: Date(), to: nextDose).day ?? 0
                Text("\(daysUntilNextDose) day\(daysUntilNextDose == 1 ? "" : "s")")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.32, green: 0.29, blue: 0.71))
            }

            // Calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(red: 0.93, green: 0.93, blue: 0.99))
                    .frame(width: 32, height: 40)

                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.32, green: 0.29, blue: 0.71))
            }
        }
        .padding(14)
        .background(Color.clear)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.tertiarySystemFill), lineWidth: 0.5)
        )
    }
}

// MARK: - Journal Card View
struct JournalCardView: View {
    let entry: JournalEntry

    var body: some View {
        NavigationLink(destination: JournalView()) {
            HStack(spacing: 10) {
                Text("🌸")
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's journal")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.45, green: 0.14, blue: 0.24))
                    HStack(spacing: 4) {
                        Text(entry.date, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        Text(entry.mood.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        if !entry.symptoms.isEmpty {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.tertiaryLabel))

                            Text("\(entry.symptoms.count) symptom\(entry.symptoms.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundColor(Color(.tertiaryLabel))
                    Text(entry.previewText)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
                        .lineLimit(1)

                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.60, green: 0.21, blue: 0.33))
            }
            .padding(14)
            .background(Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.96, green: 0.75, blue: 0.82), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// Mini trend graph component
struct MiniTrendGraph: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        GeometryReader { geometry in
            let points = medicationManager.estimatedRecentLevels(days: 7)
            let minValue = points.map { $0.value }.min() ?? 0
            let maxValue = points.map { $0.value }.max() ?? 1
            let valueRange = maxValue - minValue

            ZStack(alignment: .bottomLeading) {
                // Gradient fill
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(points.count - 1))
                        let y = valueRange > 0 ?
                            geometry.size.height - CGFloat((point.value - minValue) / valueRange) * geometry.size.height :
                            geometry.size.height / 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    // Close the path for gradient fill
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Color(red: 0.83, green: 0.32, blue: 0.49).opacity(0.18),
                        Color(red: 0.83, green: 0.32, blue: 0.49).opacity(0)
                    ]),
                                   startPoint: .top,
                                   endPoint: .bottom)
                )

                // Trend line
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(points.count - 1))
                        let y = valueRange > 0 ?
                            geometry.size.height - CGFloat((point.value - minValue) / valueRange) * geometry.size.height :
                            geometry.size.height / 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color(red: 0.83, green: 0.32, blue: 0.49), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Current point marker
                if let currentPoint = points.last {
                    let x = geometry.size.width - 10
                    let y = valueRange > 0 ?
                        geometry.size.height - CGFloat((currentPoint.value - minValue) / valueRange) * geometry.size.height :
                        geometry.size.height / 2

                    Circle()
                        .fill(Color(red: 0.83, green: 0.32, blue: 0.49))
                        .frame(width: 10, height: 10)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
