//
//  MainContentView.swift
//  xT
//
//  Redesigned main content area. Cards are consolidated and reordered
//  for cleaner visual hierarchy: actions → level → dose → journal → insight.
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Missed dose prompt (urgent — always first if applicable)
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .padding(.horizontal, 16)
            }

            // Quick actions — compact 3-button strip
            QuickActionsCard()
                .padding(.horizontal, 16)

            // Hormone level + sparkline
            if medicationManager.isFullyConfigured {
                LevelTrendCard(showingGraphDetail: $showingGraphDetail)
                    .padding(.horizontal, 16)
            }

            // Dose streak / next dose
            if medicationManager.isFullyConfigured {
                DoseStreakCard()
                    .padding(.horizontal, 16)
            }

            // Today's journal entry
            if let lastEntry = journalManager.lastEntry {
                JournalCardView(entry: lastEntry)
                    .padding(.horizontal, 16)
            }

            // Health insight
            if medicationManager.isFullyConfigured {
                HealthInsightCard()
                    .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    MainContentView(showingGraphDetail: .constant(false))
        .padding(.vertical)
        .background(Theme.globalBackgroundGradient)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}