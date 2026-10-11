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

    // MARK: - Grouped Screenings

    /// Screenings grouped by type, sorted newest first within each group.
    private var groupedScreenings: [(type: ScreeningType, records: [ScreeningRecord])] {
        let grouped = Dictionary(grouping: medicationManager.screeningRecords) { $0.type }
        return grouped
            .map { (type: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.type.label < $1.type.label }
    }

    var body: some View {
        HistoryListView(
            title: "Screenings",
            emptyTitle: "No Screenings",
            emptyIcon: "heart.text.square",
            emptyDescription: "Log a DEXA scan, cardio check or other screening to track it on the Time tab.",
            groups: groupedScreenings.map { (title: $0.type.label, items: $0.records) },
            deleteAlertTitle: "Delete Screening?",
            deleteMessage: deleteAlertMessage(for:),
            onDelete: { medicationManager.removeScreening(withId: $0.id) },
            addLabel: "Add Screening",
            row: { ScreeningRow(record: $0) },
            composer: { mode in
                switch mode {
                case .add:         ScreeningComposerView(mode: .add)
                case .edit(let r): ScreeningComposerView(mode: .edit(r))
                }
            }
        )
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
                .font(Theme.Fonts.subheadline)
                .fontWeight(.medium)

            if let notes = record.notes, !notes.isEmpty {
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
            ScreeningHistoryView()
                .environment(\.medicationManager, MedicationManager.shared)
        }
    }
}
#endif
