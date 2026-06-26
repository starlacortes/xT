//
//  HealthInsightsView.swift
//  xT
//
//  Created by Cline on 5/25/2026.
//  Health insights component for journaling
//

import SwiftUI

// MARK: - Health Insights View
struct HealthInsightsView: View {
    @Environment(\.medicationManager) private var medicationManager
    let level: Double

    private var hormoneLevelRanges: [JournalHormoneLevelRange] {
        guard let medication = medicationManager.selectedMedication else {
            return []
        }

        if medication == "Estrogen" {
            return [
                JournalHormoneLevelRange(name: "Very Low", min: 0, max: 50, description: "May experience hot flashes, mood changes"),
                JournalHormoneLevelRange(name: "Low", min: 50, max: 100, description: "Suboptimal feminization, possible mood swings"),
                JournalHormoneLevelRange(name: "Optimal", min: 100, max: 200, description: "Good feminization progress, stable mood"),
                JournalHormoneLevelRange(name: "High", min: 200, max: 500, description: "Enhanced feminization, better suppression"),
                JournalHormoneLevelRange(name: "Very High", min: 500, max: 1000, description: "Maximal effects but potential health risks")
            ]
        } else {
            return [
                JournalHormoneLevelRange(name: "Suppressed", min: 0, max: 50, description: "Full testosterone suppression"),
                JournalHormoneLevelRange(name: "Low Male", min: 50, max: 200, description: "Partial suppression"),
                JournalHormoneLevelRange(name: "Male Range", min: 200, max: 800, description: "Insufficient suppression"),
                JournalHormoneLevelRange(name: "High Male", min: 800, max: 1200, description: "Full masculinization")
            ]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Health Insights")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textSecondary)

            if let currentRange = hormoneLevelRanges.first(where: { $0.min <= level && $0.max >= level }) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Current Range:")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Text(currentRange.name)
                            .font(.headline)
                            .bold()
                            .foregroundStyle(rangeColor(for: currentRange.name))

                        Spacer()

                        Image(systemName: rangeIcon(for: currentRange.name))
                            .foregroundStyle(rangeColor(for: currentRange.name))
                    }

                    Text(currentRange.description)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)

                    Text("\(Int(currentRange.min))-\(Int(currentRange.max)) \(medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL")")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding()
                .asGlassCard()
            }
        }
    }

    private func rangeColor(for rangeName: String) -> Color {
        switch rangeName {
        case "Very Low", "Suppressed": return Theme.Colors.error
        case "Low", "Low Male": return Theme.Colors.warning
        case "Optimal": return Theme.Colors.success
        case "High", "Male Range": return .yellow
        case "Very High", "High Male": return Theme.Colors.error
        default: return Theme.Colors.info
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
}

// Helper struct for hormone level ranges
struct JournalHormoneLevelRange {
    let name: String
    let min: Double
    let max: Double
    let description: String
}

#Preview {
    HealthInsightsView(level: 150.0)
        .environment(\.medicationManager, MedicationManager.shared)
}
