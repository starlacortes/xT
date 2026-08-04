//
//  ScreeningComposerView.swift
//  xT
//
//  Add/edit sheet for a single health screening record (DEXA, breast
//  screening, cardio check, liver panel, CBC, etc.).
//

import SwiftUI

struct ScreeningComposerView: View {
    enum Mode {
        case add
        case edit(ScreeningRecord)
    }

    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var type: ScreeningType
    @State private var date: Date
    @State private var notes: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _type = State(initialValue: .bloodPanel)
            _date = State(initialValue: Date())
            _notes = State(initialValue: "")
        case .edit(let record):
            _type = State(initialValue: record.type)
            _date = State(initialValue: record.date)
            _notes = State(initialValue: record.notes ?? "")
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(ScreeningType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }

                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                }

                Section("Notes") {
                    TextField("e.g. Provider, location, results summary", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Screening" : "Add Screening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Editing has no update API of its own — mirrors BloodTestComposerView's
        // delete + re-add pattern for the same reason: keep a single insertion path.
        if case .edit(let record) = mode {
            medicationManager.removeScreening(withId: record.id)
        }

        medicationManager.addScreening(
            date: date,
            type: type,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        dismiss()
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        ScreeningComposerView(mode: .add)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
