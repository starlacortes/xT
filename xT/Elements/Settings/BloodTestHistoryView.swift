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

    @State private var composerMode: BloodTestComposerView.Mode?

    // Delete confirmation state
    @State private var testToDelete: BloodTestRecord? = nil
    @State private var showDeleteConfirmation = false

    // MARK: - Grouped Tests

    /// Blood tests grouped by hormone type, sorted newest first within each group.
    private var groupedTests: [(hormone: String, tests: [BloodTestRecord])] {
        let grouped = Dictionary(grouping: medicationManager.bloodTestHistory) { $0.hormoneType }
        return grouped
            .map { (hormone: $0.key, tests: $0.value.sorted { $0.drawDate > $1.drawDate }) }
            .sorted { $0.hormone < $1.hormone }
    }

    var body: some View {
        List {
            if !medicationManager.bloodTestHistory.isEmpty {
                Section {
                    LabsChartView()
                        .padding(.vertical, Theme.Spacing.sm)
                }
            }

            if groupedTests.isEmpty {
                ContentUnavailableView(
                    "No Blood Tests",
                    systemImage: "drop.fill",
                    description: Text("Log a lab result to calibrate the model to your own levels.")
                )
            }

            ForEach(groupedTests, id: \.hormone) { group in
                Section(group.hormone) {
                    ForEach(group.tests) { test in
                        BloodTestRow(test: test)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    testToDelete = test
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button("Edit") {
                                    composerMode = .edit(test)
                                }
                                .tint(Theme.Colors.accentSecondary)
                            }
                    }
                }
            }
        }
        .navigationTitle("Blood Tests")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    composerMode = .add
                } label: {
                    Label("Add Blood Test", systemImage: "plus")
                }
            }
        }
        .alert("Delete Blood Test?", isPresented: $showDeleteConfirmation, presenting: testToDelete) { test in
            Button("Delete", role: .destructive) {
                medicationManager.removeBloodTest(withId: test.id)
                testToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                testToDelete = nil
            }
        } message: { test in
            Text(deleteAlertMessage(for: test))
        }
        .sheet(isPresented: Binding(
            get: { composerMode != nil },
            set: { isPresented in if !isPresented { composerMode = nil } }
        )) {
            if let composerMode {
                BloodTestComposerView(
                    mode: composerMode,
                    defaultHormone: medicationManager.selectedMedication ?? "Estrogen"
                )
            }
        }
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if test.isCalibrated {
                    Pill(text: "calibrated", style: .tinted(Theme.Colors.success))
                }
            }

            HStack(spacing: 6) {
                Text(test.drawDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let hrs = test.hoursSinceLastDose {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(AppNumberFormatters.hormoneLevel.string(hrs))h post-dose")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = test.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
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
