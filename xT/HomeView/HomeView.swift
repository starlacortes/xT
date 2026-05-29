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
                HomeContentView(showingGraphDetail: $showingGraphDetail)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .background(Theme.globalBackgroundGradient)
        .sheet(isPresented: $showingGraphDetail) {
            GraphView()
                .environment(\.medicationManager, medicationManager)
        }
    }
}


// MARK: - Home Content View
struct HomeContentView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Phone mockup container
            VStack(spacing: 0) {
                StatusBarView()

                HeaderView(showingGraphDetail: $showingGraphDetail)

                MainContentView()
                    .padding(.top, 14)
            }
            .background(Theme.globalBackgroundGradient)
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
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Profile section
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Theme.globalBackgroundGradient
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
                CurrentLevelCard(currentLevel: currentLevel, showingGraphDetail: $showingGraphDetail)
            }
        }
        .padding(12)
        .background(Color.clear)
    }
}

// MARK: - Current Level Card
struct CurrentLevelCard: View {
    let currentLevel: Double
    @Binding var showingGraphDetail: Bool

    var body: some View {
        Button(action: {
            showingGraphDetail = true
        }) {
            HStack(spacing: 12) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(Theme.bloomCycleLightColor)
                        .frame(width: 36, height: 79)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.bloomCycleColor)
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
                            .foregroundColor(Theme.accentColor.opacity(0.8))

                        Text("pg/mL")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

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
                            .cornerRadius(Theme.smallCornerRadius)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.smallCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                    .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
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
        if level < 100 { return Theme.bloomBodyColor }
        else if level < 200 { return Theme.successColor }
        else { return Theme.bloomCycleColor }
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        VStack(spacing: 10) {
            // Missed dose prompt (shows first if applicable)
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .padding(.horizontal, 14)
            }

            // Quick actions card
            QuickActionsCard()

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
            
            // Health insight card
            if medicationManager.isFullyConfigured {
                HealthInsightCard()
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Quick Actions Card
struct QuickActionsCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingJournalComposer = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Quick actions")
                    .font(.system(size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Record dose button
                Button(action: {
                    medicationManager.recordDose(on: Date())
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.bloomSkinLightColor)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.bloomSkinColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Record dose")
                                .font(.system(size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(Theme.smallCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Theme.bloomSkinBorderColor, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                
                // New journal entry button
                Button(action: {
                    showingJournalComposer = true
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.bloomCycleLightColor)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.bloomCycleColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New entry")
                                .font(.system(size: 13))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(Theme.smallCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                            .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.mediumCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                .stroke(Theme.borderColor, lineWidth: 0.5)
        )
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }
}

// MARK: - Health Insight Card
struct HealthInsightCard: View {
    @Environment(\.medicationManager) private var medicationManager
    
    private var insightText: String {
        guard let currentLevel = medicationManager.estimatedRecentLevels().last?.value else {
            return "Keep tracking your doses to see personalized insights"
        }
        
        if currentLevel < 100 {
            return "Your levels appear low. Consider talking to your provider about adjusting your dose schedule."
        } else if currentLevel < 200 {
            return "Great! Your hormone levels are in the optimal range. Keep up with your current schedule."
        } else {
            return "Your levels are running high. Monitor for any symptoms and consult your provider if needed."
        }
    }
    
    private var insightIcon: String {
        guard let currentLevel = medicationManager.estimatedRecentLevels().last?.value else {
            return "lightbulb"
        }
        
        if currentLevel < 100 {
            return "exclamationmark.triangle"
        } else if currentLevel < 200 {
            return "checkmark.circle"
        } else {
            return "info.circle"
        }
    }
    
    private var insightColor: Color {
        guard let currentLevel = medicationManager.estimatedRecentLevels().last?.value else {
            return Theme.infoColor
        }
        
        if currentLevel < 100 {
            return Theme.warningColor
        } else if currentLevel < 200 {
            return Theme.successColor
        } else {
            return Theme.infoColor
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(insightColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: insightIcon)
                    .font(.system(size: 16))
                    .foregroundColor(insightColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Health insight")
                    .font(.system(size: 13))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(insightText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.mediumCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                .stroke(insightColor.opacity(0.3), lineWidth: 0.5)
        )
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
                        .foregroundColor(.secondary)
                }
            }

            // Mini trend graph
            MiniTrendGraph()
                .frame(height: 122)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.mediumCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                .stroke(Theme.borderColor, lineWidth: 0.5)
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
                    .foregroundColor(.secondary)

                let daysUntilNextDose = Calendar.current.dateComponents([.day], from: Date(), to: nextDose).day ?? 0
                Text("\(daysUntilNextDose) day\(daysUntilNextDose == 1 ? "" : "s")")
                    .font(.system(size: 15))
                    .fontWeight(.medium)
                    .foregroundColor(Theme.bloomMindColor)
            }

            // Calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.bloomMindLightColor)
                    .frame(width: 32, height: 40)

                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.bloomMindColor)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.mediumCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                .stroke(Theme.borderColor, lineWidth: 0.5)
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
                        .foregroundColor(Theme.accentColor)
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
                                .foregroundColor(.secondary)

                            Text("\(entry.symptoms.count) symptom\(entry.symptoms.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !entry.text.isEmpty {
                        Text(entry.previewText)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accentColor.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accentColor)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.mediumCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                    .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
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
                        Theme.accentColor.opacity(0.18),
                        Theme.accentColor.opacity(0)
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
                .stroke(Theme.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Current point marker
                if let currentPoint = points.last {
                    let x = geometry.size.width - 10
                    let y = valueRange > 0 ?
                        geometry.size.height - CGFloat((currentPoint.value - minValue) / valueRange) * geometry.size.height :
                        geometry.size.height / 2

                    Circle()
                        .fill(Theme.accentColor)
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
