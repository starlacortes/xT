//
//  MainContentView.swift
//  xT
//
//  Streamlined card stack. HybridStatusCard replaces the separate
//  LevelTrendCard + DoseStreakCard pair. DiscoveryRow removed (placeholder
//  content). Horizontal padding lives in HomeView, not here.
//

import SwiftUI

struct MainContentView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Binding var showingGraphDetail: Bool

    var body: some View {
        VStack(spacing: 14) {
            // Missed dose prompt — urgent, always surfaces first
            if medicationManager.isFullyConfigured && medicationManager.hasMissedDose {
                MissedDosePrompt()
                    .transition(.opacity)
                    .entrance(index: 0)
            }

            // Quick actions strip
            QuickActionsCard()
                .transition(.opacity)
                .entrance(index: 1)

            // Hormone level + trend + next dose + streak — single unified card
            if medicationManager.isFullyConfigured {
                HybridStatusCard(showingGraphDetail: $showingGraphDetail)
                    .transition(.opacity)
                    .entrance(index: 2)
            }

            // Contextual health insight
            if medicationManager.isFullyConfigured {
                HealthInsightCard()
                    .transition(.opacity)
                    .entrance(index: 3)
            }

            // Today's journal snapshot
            if let lastEntry = journalManager.lastEntry {
                JournalCardView(entry: lastEntry)
                    .transition(.opacity)
                    .entrance(index: 4)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: medicationManager.hasMissedDose)
    }
}

#Preview {
    MainContentView(showingGraphDetail: .constant(false))
        .padding(.horizontal, 18)
        .padding(.vertical)
        .background(AnimatedMeshGradient().ignoresSafeArea())
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
