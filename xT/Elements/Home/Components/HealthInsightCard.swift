//
//  HealthInsightCard.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Health insight card component
//

import SwiftUI

struct HealthInsightCard: View {
    @Environment(\.medicationManager) private var medicationManager

    private var insightText: String {
        guard let currentLevel = medicationManager.currentHormoneLevel?.value else {
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
        guard let currentLevel = medicationManager.currentHormoneLevel?.value else {
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
        guard let currentLevel = medicationManager.currentHormoneLevel?.value else {
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

#Preview {
    HealthInsightCard()
        .environment(\.medicationManager, MedicationManager.shared)
}