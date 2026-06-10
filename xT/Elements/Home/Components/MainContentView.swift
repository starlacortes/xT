//
//  MainContentView.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Main content area for HomeView
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Missed dose prompt (shows first if applicable)
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .padding(.horizontal, 14)
            }

            // Quick actions card
            QuickActionsCard()

            // Level and trend card
            if medicationManager.isFullyConfigured {
                LevelTrendCard(showingGraphDetail: $showingGraphDetail)
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

#Preview {
    MainContentView(showingGraphDetail: .constant(false))
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
