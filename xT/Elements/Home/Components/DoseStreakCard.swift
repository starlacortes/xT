//
//  DoseStreakCard.swift
//  xT
//
//  Replaces the old NextDoseCard with a richer visual that shows
//  the weekly dot-streak alongside the next dose date.
//

import SwiftUI

struct DoseStreakCard: View {
    @Environment(\.medicationManager) private var medicationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next dose")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    if let next = medicationManager.nextDoseDate {
                        Text(nextDoseLabel(next))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if onTrack {
                    Text("On track")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.bloomMindColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.bloomMindLightColor)
                        .overlay(
                            Capsule().stroke(Theme.bloomMindBorderColor, lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                }
            }

            // Dot streak
            HStack(spacing: 5) {
                ForEach(0..<cycleDays, id: \.self) { index in
                    Circle()
                        .fill(index < completedDays ? Theme.accentColor : Color(UIColor.systemGray5))
                        .overlay(
                            Circle().stroke(
                                index < completedDays ? Theme.bloomCycleBorderColor : Color(UIColor.systemGray4),
                                lineWidth: 0.5
                            )
                        )
                        .frame(width: 10, height: 10)
                }

                Text("\(completedDays) of \(cycleDays) days")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
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

    private var cycleDays: Int {
        guard let method = medicationManager.selectedAdministrationMethod,
              let adm = MedicationManager.AdministrationMethod(rawValue: method) else { return 7 }
        return adm.frequencyDays
    }

    private var completedDays: Int {
        guard let last = medicationManager.lastDoseDate else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return min(elapsed + 1, cycleDays)
    }

    private var onTrack: Bool {
        !medicationManager.hasMissedDose
    }

    private func nextDoseLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        if days == 0 { return "Today · \(formatted)" }
        if days == 1 { return "Tomorrow · \(formatted)" }
        return "In \(days) days · \(formatted)"
    }
}

#Preview {
    DoseStreakCard()
        .padding()
        .background(Theme.globalBackgroundGradient)
        .environment(\.medicationManager, MedicationManager.shared)
}