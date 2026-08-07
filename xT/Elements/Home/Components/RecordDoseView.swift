//
//  RecordDoseView.swift
//  xT
//
//  The "record a dose" sheet presented from the next-dose row.
//
//  Extracted from MissedDosePrompt, which was a duplicate of the missed-dose banner
//  already rendered by UnifiedScheduleView and had no call sites of its own.
//

import SwiftUI

// MARK: - Record Dose Sheet

struct RecordDoseView: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Text("Record your dose")
                    .font(Theme.Fonts.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accent)

                DatePicker(
                    "Dose time",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Theme.Spacing.xl)

                Button {
                    medicationManager.recordDose(on: selectedDate)
                    showingConfirmation = true
                    // 0.8s so the sheet is gone before HomeView's celebration
                    // confetti fires at MedicationManager.recordDoseCelebrationDelay
                    // (1.2s) — leaves a buffer for the dismiss animation itself.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        dismiss()
                    }
                } label: {
                    Text("Record dose")
                        .font(Theme.Fonts.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Theme.Spacing.xl)

                if showingConfirmation {
                    Text("✓ Dose recorded successfully!")
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.success)
                        .transition(.opacity)
                }
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        RecordDoseView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
