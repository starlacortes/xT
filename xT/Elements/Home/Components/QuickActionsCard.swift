//
//  QuickActionsCard.swift
//  xT
//
//  Redesigned as a compact 3-button strip: record dose, new journal entry,
//  and a link to the schedule view.
//

import SwiftUI

struct QuickActionsCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingJournalComposer = false
    @State private var showingDoseConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            actionButton(
                icon: "checkmark.circle.fill",
                label: "Record dose",
                color: Theme.bloomSkinColor,
                background: Theme.bloomSkinLightColor,
                border: Theme.bloomSkinBorderColor
            ) {
                medicationManager.recordDose(on: Date())
                showingDoseConfirmation = true
            }

            actionButton(
                icon: "square.and.pencil",
                label: "New entry",
                color: Theme.accentColor,
                background: Theme.bloomCycleLightColor,
                border: Theme.bloomCycleBorderColor
            ) {
                showingJournalComposer = true
            }

            NavigationLink(destination: UnifiedScheduleView()) {
                actionButtonContent(
                    icon: "calendar",
                    label: "Schedule",
                    color: Theme.bloomMindColor,
                    background: Theme.bloomMindLightColor,
                    border: Theme.bloomMindBorderColor
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingJournalComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
        .alert("Dose recorded!", isPresented: $showingDoseConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your dose has been recorded for today.")
        }
    }

    // MARK: - Helpers

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        background: Color,
        border: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionButtonContent(icon: icon, label: label, color: color, background: background, border: border)
        }
        .buttonStyle(.plain)
    }

    private func actionButtonContent(
        icon: String,
        label: String,
        color: Color,
        background: Color,
        border: Color
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(Theme.smallCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallCornerRadius)
                .stroke(border, lineWidth: 0.5)
        )
    }
}

#Preview {
    QuickActionsCard()
        .padding()
        .background(Theme.globalBackgroundGradient)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}