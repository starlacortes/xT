//
//  ScreeningHistoryView.swift
//  xT
//
//  Health screening history list, grouped by type, with swipe-to-edit and
//  swipe-to-delete actions. Feeds TimeContentEngine's long-term milestone
//  badges (DEXA, cardio, liver, breast, CBC) via MedicationManager.screeningLog.
//

import SwiftUI

struct ScreeningHistoryView: View {
    @Environment(\.medicationManager) private var medicationManager

    @State private var composerMode: ScreeningComposerView.Mode?

    // Delete confirmation state
    @State private var screeningToDelete: ScreeningRecord? = nil
    @State private var showDeleteConfirmation = false

    // MARK: - Grouped Screenings

    /// Screenings grouped by type, sorted newest first within each group.
    private var groupedScreenings: [(type: ScreeningType, records: [ScreeningRecord])] {
        let grouped = Dictionary(grouping: medicationManager.screeningRecords) { $0.type }
        return grouped
            .map { (type: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.type.label < $1.type.label }
    }

    var body: some View {
        List {
            if groupedScreenings.isEmpty {
                ContentUnavailableView(
                    "No Screenings",
                    systemImage: "heart.text.square",
                    description: Text("Log a DEXA scan, cardio check or other screening to track it on the Time tab.")
                )
            }

            ForEach(groupedScreenings, id: \.type) { group in
                Section(group.type.label) {
                    ForEach(group.records) { record in
                        ScreeningRow(record: record)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    screeningToDelete = record
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button("Edit") {
                                    composerMode = .edit(record)
                                }
                                .tint(Theme.Colors.accentSecondary)
                            }
                    }
                }
            }
        }
        .navigationTitle("Screenings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    composerMode = .add
                } label: {
                    Label("Add Screening", systemImage: "plus")
                }
            }
        }
        .alert("Delete Screening?", isPresented: $showDeleteConfirmation, presenting: screeningToDelete) { record in
            Button("Delete", role: .destructive) {
                medicationManager.removeScreening(withId: record.id)
                screeningToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                screeningToDelete = nil
            }
        } message: { record in
            Text(deleteAlertMessage(for: record))
        }
        .sheet(isPresented: Binding(
            get: { composerMode != nil },
            set: { isPresented in if !isPresented { composerMode = nil } }
        )) {
            if let composerMode {
                ScreeningComposerView(mode: composerMode)
            }
        }
    }

    // MARK: - Delete alert message

    private func deleteAlertMessage(for record: ScreeningRecord) -> String {
        """
        This will permanently remove the \(record.type.label) logged on \
        \(record.date.formatted(date: .abbreviated, time: .omitted)).
        """
    }
}

// MARK: - Screening Row

struct ScreeningRow: View {
    let record: ScreeningRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .fontWeight(.medium)

            if let notes = record.notes, !notes.isEmpty {
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
            ScreeningHistoryView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
