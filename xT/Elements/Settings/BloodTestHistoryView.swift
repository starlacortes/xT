//
//  BloodTestHistoryView.swift
//  xT
//
//  Blood test history list with a labs chart, swipe-to-edit and
//  swipe-to-delete actions, grouped by hormone type.
//

import SwiftUI

struct BloodTestHistoryView: View {
    @Environment(\.medicationManager) private var medicationManager

    // MARK: - Grouped Tests

    /// Blood tests grouped by hormone type, sorted newest first within each group.
    private var groupedTests: [(hormone: String, tests: [BloodTestRecord])] {
        let grouped = Dictionary(grouping: medicationManager.bloodTestHistory) { $0.hormoneType }
        return grouped
            .map { (hormone: $0.key, tests: $0.value.sorted { $0.drawDate > $1.drawDate }) }
            .sorted { $0.hormone < $1.hormone }
    }

    var body: some View {
        HistoryListView(
            title: "Blood Tests",
            emptyTitle: "No Blood Tests",
            emptyIcon: "drop.fill",
            emptyDescription: "Log a lab result to calibrate the model to your own levels.",
            groups: groupedTests.map { (title: $0.hormone, items: $0.tests) },
            deleteAlertTitle: "Delete Blood Test?",
            deleteMessage: deleteAlertMessage(for:),
            onDelete: { medicationManager.removeBloodTest(withId: $0.id) },
            topContent: medicationManager.bloodTestHistory.isEmpty ? nil : AnyView(
                Section {
                    LabsChartView()
                        .padding(.vertical, Theme.Spacing.sm)
                }
            ),
            addLabel: "Add Blood Test",
            row: { BloodTestRow(test: $0) },
            composer: { mode in
                switch mode {
                case .add:
                    BloodTestComposerView(mode: .add,
                                          defaultHormone: medicationManager.selectedMedication ?? "Estrogen")
                case .edit(let test):
                    BloodTestComposerView(mode: .edit(test),
                                          defaultHormone: medicationManager.selectedMedication ?? "Estrogen")
                }
            }
        )
    }

    // MARK: - Delete alert message

    private func deleteAlertMessage(for test: BloodTestRecord) -> String {
        """
        This will permanently remove the \(test.hormoneType) result logged on \
        \(test.drawDate.formatted(date: .abbreviated, time: .shortened)).
        """
    }
}

// MARK: - Blood Test Row

struct BloodTestRow: View {
    let test: BloodTestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(AppNumberFormatters.hormoneLevel.string(test.measuredLevel)) \(BloodTestRecord.unit(for: test.hormoneType))")
                    .font(Theme.Fonts.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if test.isCalibrated {
                    Pill(text: "calibrated", style: .tinted(Theme.Colors.success))
                }
            }

            HStack(spacing: 6) {
                Text(test.drawDate.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(.secondary)

                if let hrs = test.hoursSinceLastDose {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(AppNumberFormatters.hormoneLevel.string(hrs))h post-dose")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = test.notes, !notes.isEmpty {
                Text(notes)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        NavigationStack {
            BloodTestHistoryView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
