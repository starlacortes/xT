//
//  UnifiedStackView.swift
//  xT
//
//  Glassmorphism card container holding the insight/mood/next-dose/action rows.
//  Uses the shared Theme glass modifier (iOS 26 Liquid Glass with fallback).
//

import SwiftUI

struct UnifiedStackView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager

    var body: some View {
        VStack(spacing: 0) {
            InsightRowView()
                .entrance(index: 0)

            divider()

            MoodRowView()
                .entrance(index: 1)

            divider()

            if medicationManager.isFullyConfigured {
                NextDoseRowView()
                    .entrance(index: 2)

                divider()
            }

            ActionBarView()
                .entrance(index: medicationManager.isFullyConfigured ? 3 : 2)
        }
        .asGlassCard(cornerRadius: Theme.Radius.lg)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Theme.Colors.border.opacity(0.35))
            .frame(height: 0.5)
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        UnifiedStackView()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.journalManager, JournalManager.shared)
            .padding()
            .background(Theme.Gradients.brand)
    }
}
#endif
