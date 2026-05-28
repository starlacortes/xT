//
//  HomeView.swift
//  xT
//
//  Created by Starla Cortes on 8/5/25.
//
import SwiftUI

struct HomeView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Unified header with profile and medication info
                    DashboardHeaderView()

                    // Main content with better spacing and hierarchy
                    VStack(alignment: .leading, spacing: 20) {
                        // Medication status section
                        if medicationManager.selectedMedication == nil || medicationManager.selectedAdministrationMethod == nil {
                            SetupMedicationSection()
                        } else {
                            MedicationInfoSection()                                                                                                                                                                                                                                                                                              
                        }

                        // Compact progress preview
                        ProgressPreviewSection()

                        // Journal Preview Section
                        if medicationManager.selectedMedication != nil {
                            JournalPreviewSection()
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemBackground))
        }
    }
}

// Unified Dashboard Header
struct DashboardHeaderView: View {
    @Environment(\.profileManager) private var profileManager
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(spacing: 12) {
            // Profile section
            HStack(spacing: 12) {
                Image(uiImage: profileManager.getCurrentProfileImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.purple, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi \(profileManager.profileDisplayName)!")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.purple)

                    if medicationManager.isFullyConfigured {
                        Text(medicationManager.medicationDisplayInfo)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Quick access to settings
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Current hormone level indicator
            if medicationManager.isFullyConfigured,
               let currentLevel = medicationManager.estimatedRecentLevels().last?.value {
                HormoneLevelIndicator(currentLevel: currentLevel)
                    .padding(.horizontal)
            }
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.05), Color.clear]),
                          startPoint: .top,
                          endPoint: .bottom)
        )
        .padding(.bottom, 12)
    }
}

// Hormone Level Indicator
struct HormoneLevelIndicator: View {
    @Environment(\.medicationManager) private var medicationManager
    let currentLevel: Double

    private var hormoneRange: (name: String, color: Color, icon: String)? {
        guard let medication = medicationManager.selectedMedication else { return nil }

        if medication == "Estrogen" {
            if currentLevel < 50 { return ("Very Low", .red, "exclamationmark.triangle.fill") }
            else if currentLevel < 100 { return ("Low", .orange, "exclamationmark.circle.fill") }
            else if currentLevel < 200 { return ("Optimal", .green, "checkmark.circle.fill") }
            else if currentLevel < 500 { return ("High", .yellow, "arrow.up.circle.fill") }
            else { return ("Very High", .red, "arrow.up.right.circle.fill") }
        } else {
            if currentLevel < 50 { return ("Suppressed", .green, "checkmark.circle.fill") }
            else if currentLevel < 200 { return ("Low Male", .orange, "exclamationmark.circle.fill") }
            else if currentLevel < 800 { return ("Male Range", .yellow, "arrow.up.circle.fill") }
            else { return ("High Male", .red, "arrow.up.right.circle.fill") }
        }
    }

    var body: some View {
        if let range = hormoneRange {
            HStack(spacing: 12) {
                Image(systemName: range.icon)
                    .font(.title3)
                    .foregroundColor(range.color)
                    .frame(width: 40, height: 40)
                    .background(range.color.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level: \(range.name)")
                        .font(.subheadline)
                        .bold()

                    Text("\(Int(currentLevel)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                NavigationLink(destination: GraphView()) {
                    Text("View Graph")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(range.color.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// Compact Progress Preview
struct ProgressPreviewSection: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Progress")
                .font(.headline)
                .foregroundColor(.purple)

            if medicationManager.isFullyConfigured {
                // Simple 7-day trend line
                ProgressTrendView()
                    .frame(height: 120)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                // Next dose reminder
                if let nextDose = medicationManager.nextDoseDate {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)

                        Text("Next dose: \(nextDose, style: .date)")
                            .font(.subheadline)

                        Spacer()

                        NavigationLink(destination: UnifiedScheduleView()) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                Text("Set up your medication to track progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }
}

// Simple Trend View
struct ProgressTrendView: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        GeometryReader { geometry in
            let points = medicationManager.estimatedRecentLevels(days: 7)
            let minValue = points.map { $0.value }.min() ?? 0
            let maxValue = points.map { $0.value }.max() ?? 1
            let valueRange = maxValue - minValue

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
            .stroke(Color.purple, lineWidth: 2)

            // Current level marker
            if let currentPoint = points.last {
                let x = geometry.size.width - 10
                let y = valueRange > 0 ?
                    geometry.size.height - CGFloat((currentPoint.value - minValue) / valueRange) * geometry.size.height :
                    geometry.size.height / 2

                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                    .position(x: x, y: y)
            }
        }
        .padding(.horizontal, 16)
    }
}

struct SetupMedicationSection: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "pills.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.purple)
                .padding(.bottom, 8)

            Text("Set Up Your Medication")
                .font(.headline)
                .foregroundColor(.purple)

            Text("Tap the button below to select your medication and administration method.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            NavigationLink(destination: SettingsView()) {
                Text("Set Up Medication")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MedicationInfoSection: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.profileManager) private var profileManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Medication")
                .font(.headline)
                .foregroundColor(.purple)

            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(.purple)
                Text(medicationManager.medicationName)
                    .font(.subheadline)

                Spacer()

                Text(medicationManager.selectedAdministrationMethod ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)

            if let nextDose = medicationManager.nextDoseDate {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.purple)
                    Text("Next dose: \(nextDose, style: .date)")
                        .font(.subheadline)
                }
                .padding(8)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

// Journal Preview Section
struct JournalPreviewSection: View {
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        NavigationLink(destination: JournalView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Today's Journal")
                        .font(.headline)
                        .foregroundColor(.purple)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.purple)
                }

                if let lastEntry = journalManager.lastEntry {
                    VStack(alignment: .leading, spacing: 8) {
                        // Mood and symptoms summary
                        HStack(spacing: 8) {
                            Image(systemName: lastEntry.mood.icon)
                                .foregroundColor(getRangeColor(for: lastEntry.mood.rawValue))
                            Text(lastEntry.mood.rawValue)
                                .font(.caption)
                                .foregroundColor(getRangeColor(for: lastEntry.mood.rawValue))

                            if !lastEntry.symptoms.isEmpty {
                                Text("•")
                                    .foregroundColor(.gray)
                                HStack(spacing: 4) {
                                    ForEach(Array(lastEntry.symptoms.prefix(2)), id: \.id) { symptom in
                                        Image(systemName: symptom.icon)
                                            .font(.caption)
                                    }
                                    if lastEntry.symptoms.count > 2 {
                                        Text("+\(lastEntry.symptoms.count - 2)")
                                            .font(.caption)
                                    }
                                }
                            }
                        }

                        // Journal entry preview
                        Text(lastEntry.previewText)
                            .font(.body)
                            .lineLimit(2)
                            .foregroundColor(.secondary)

                        // Entry date
                        Text(lastEntry.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No journal entries yet")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Tap to add your first entry and track your wellness journey")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func getRangeColor(for mood: String) -> Color {
        switch mood {
        case "Happy", "Excited": return .green
        case "Neutral", "Calm": return .blue
        case "Sad", "Anxious": return .orange
        case "Angry", "Frustrated": return .red
        default: return .purple
        }
    }
}

#Preview {
    HomeView()
        .environment(\.profileManager, ProfileManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
