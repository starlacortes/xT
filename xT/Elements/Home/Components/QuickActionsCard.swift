//
//  QuickActionsCard.swift
//  xT
//
//  Three fixed-position action buttons: Dose (left), Journal (center),
//  Schedule (right). Positions never swap — predictable muscle memory.
//  The dose button shifts to an urgent rose palette when a dose is missed.
//

import SwiftUI

struct QuickActionsCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @State private var showingJournalComposer = false
    @State private var showingDoseConfirmation = false
    @State private var triggerBloomEffect = false
    @State private var bloomPosition: CGPoint = .zero

    private var doseMissed: Bool {
        medicationManager.isFullyConfigured && medicationManager.hasMissedDose
    }

    var body: some View {
        HStack(spacing: 10) {
            // Dose — always left
            actionButton(
                icon: "checkmark.circle.fill",
                label: "Record dose",
                color: doseMissed ? missedRose : Theme.Colors.Bloom.skin.base,
                background: doseMissed ? Theme.Colors.Bloom.cycle.surface : Theme.Colors.Bloom.skin.surface,
                border: doseMissed ? Theme.Colors.Bloom.cycle.border : Theme.Colors.Bloom.skin.border,
                urgent: doseMissed
            ) {
                medicationManager.recordDose(on: Date())
                showingDoseConfirmation = true
            }

            // Journal — always center
            actionButton(
                icon: "square.and.pencil",
                label: "New entry",
                color: Theme.Colors.accent,
                background: Theme.Colors.Bloom.cycle.surface,
                border: Theme.Colors.Bloom.cycle.border,
                urgent: false
            ) {
                showingJournalComposer = true
            }

            // Schedule — always right
            NavigationLink(destination: UnifiedScheduleView()) {
                buttonContent(
                    icon: "calendar",
                    label: "Schedule",
                    color: Theme.Colors.Bloom.mind.base,
                    background: Theme.Colors.Bloom.mind.surface,
                    border: Theme.Colors.Bloom.mind.border,
                    urgent: false
                )
            }
            .buttonStyle(.pressable)
        }
        .overlay(
            GeometryReader { geo in
                Color.clear.onAppear {
                    bloomPosition = CGPoint(x: geo.size.width / 6, y: geo.size.height / 2)
                }
            }
        )
        .overlay(BloomEffect(trigger: $triggerBloomEffect, position: bloomPosition))
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
        .onChange(of: showingDoseConfirmation) {
            if showingDoseConfirmation {
                triggerBloomEffect = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    triggerBloomEffect = false
                }
            }
        }
    }

    // MARK: - Helpers

    private let missedRose = Color(lightHex: "#993554", darkHex: "#F4A8C0")

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        background: Color,
        border: Color,
        urgent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            buttonContent(icon: icon, label: label, color: color, background: background, border: border, urgent: urgent)
        }
        .buttonStyle(.pressable)
    }

    private func buttonContent(
        icon: String,
        label: String,
        color: Color,
        background: Color,
        border: Color,
        urgent: Bool
    ) -> some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(background)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(border, lineWidth: urgent ? 1.5 : 0.5))

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(Theme.Fonts.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(urgent ? border : Theme.Colors.border, lineWidth: urgent ? 1.5 : 0.5)
        )
    }
}

#Preview {
    QuickActionsCard()
        .padding()
        .background(Theme.Gradients.brand)
        .environment(\.medicationManager, MedicationManager.shared)
        .environment(\.journalManager, JournalManager.shared)
}
