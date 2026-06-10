//
//  QuickActionsCard.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Quick actions card component
//

import SwiftUI

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

#Preview {
    QuickActionsCard()
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}