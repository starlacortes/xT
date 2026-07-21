//
//  MissedDosePrompt.swift
//  xT
//
//  Missed dose prompt component for HomeView.
//

import SwiftUI

struct MissedDosePrompt: View {
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingRecordDose = false

    // Rose text that reads clearly on the cycle surface in both modes
    private static let cycleText = Color(lightHex: "#993554", darkHex: "#F4A8C0")

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.Time.cycle.surface)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.Time.cycle.border, lineWidth: 0.5)
                        )

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Self.cycleText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Missed dose?")
                        .font(Theme.Fonts.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.cycleText)

                    if let days = medicationManager.daysSinceMissedDose {
                        Text("Your dose was due \(days) day\(days == 1 ? "" : "s") ago")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                Button(action: { showingRecordDose = true }) {
                    Text("Record dose now")
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Self.cycleText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.Time.cycle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.Time.cycle.border, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: UnifiedScheduleView()) {
                    Text("Adjust schedule")
                        .font(Theme.Fonts.footnote)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Theme.Colors.Time.mind.base)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.Time.mind.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.Time.mind.border, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }



        }
        .padding(Theme.Spacing.card)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(Theme.Colors.Time.cycle.border, lineWidth: 1.0)
        )
        .sheet(isPresented: $showingRecordDose) {
            RecordDoseView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}

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
                    "When did you take your dose?",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Theme.Spacing.xl)

                Button {
                    medicationManager.recordDose(on: selectedDate)
                    showingConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

#Preview {
    MissedDosePrompt()
        .environment(\.medicationManager, MedicationManager.shared)
        .padding()
        .background(Color(.systemBackground))
}
