//
//  BloodTestComposerView.swift
//  xT
//
//  Add/edit sheet for a single blood test result.
//

import SwiftUI

struct BloodTestComposerView: View {
    enum Mode {
        case add
        case edit(BloodTestRecord)
    }

    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var hormoneType: String
    @State private var drawDate: Date
    @State private var measuredLevelText: String
    @State private var notes: String

    @FocusState private var levelFieldFocused: Bool

    init(mode: Mode, defaultHormone: String = "Estrogen") {
        self.mode = mode
        switch mode {
        case .add:
            _hormoneType = State(initialValue: defaultHormone)
            _drawDate = State(initialValue: Date())
            _measuredLevelText = State(initialValue: "")
            _notes = State(initialValue: "")
        case .edit(let record):
            _hormoneType = State(initialValue: record.hormoneType)
            _drawDate = State(initialValue: record.drawDate)
            _measuredLevelText = State(initialValue: AppNumberFormatters.hormoneLevel.string(record.measuredLevel))
            _notes = State(initialValue: record.notes ?? "")
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var measuredLevel: Double? {
        Double(measuredLevelText.replacingOccurrences(of: ",", with: "."))
    }

    private var unit: String {
        BloodTestRecord.unit(for: hormoneType)
    }

    private var canSave: Bool {
        guard let level = measuredLevel else { return false }
        return level > 0
    }

    /// Non-blocking sanity check — real lab draws sometimes land outside the
    /// modeled clinical band, so this warns rather than blocks saving.
    private var plausibilityWarning: String? {
        guard let level = measuredLevel, level > 0 else { return nil }
        let ceiling = hormoneType == "Testosterone"
            ? MedicationManager.TherapeuticTarget.defaultTestosterone.peakCeiling
            : MedicationManager.TherapeuticTarget.default.peakCeiling
        guard level > ceiling * 2 else { return nil }
        return "This is well above the typical clinical range for \(hormoneType.lowercased()) — double-check the value and unit before saving."
    }

    var body: some View {
        RecordComposerShell(
            title: isEditing ? "Edit Blood Test" : "Add Blood Test",
            canSave: canSave,
            onSave: save
        ) {
            Section {
                Picker("Hormone", selection: $hormoneType) {
                    Text("Estrogen").tag("Estrogen")
                    Text("Testosterone").tag("Testosterone")
                }
                .pickerStyle(.segmented)

                DatePicker(
                    "Draw date",
                    selection: $drawDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )

                HStack {
                    Text("Level")
                        .foregroundStyle(.primary)
                    Spacer()
                    TextField("0", text: $measuredLevelText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($levelFieldFocused)
                        .frame(width: 80)
                    Text(unit)
                        .foregroundStyle(.secondary)
                }
            }

            if let warning = plausibilityWarning {
                Section {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }

            Section("Notes") {
                TextField("e.g. Quest Diagnostics, trough draw", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .keyboardDoneToolbar { levelFieldFocused = false }
    }

    // MARK: - Save

    private func save() {
        guard let level = measuredLevel else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Editing has no update API of its own: the manager recomputes hours-since-dose
        // and the calibration factor from scratch inside `addBloodTest`, so a delete +
        // re-add gets the edited fields the same treatment a brand-new entry would.
        if case .edit(let record) = mode {
            medicationManager.removeBloodTest(withId: record.id)
        }

        medicationManager.addBloodTest(
            drawDate: drawDate,
            measuredLevel: level,
            hormoneType: hormoneType,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        dismiss()
    }
}

#if DEBUG
#Preview {
    SpoofPreview {
        BloodTestComposerView(mode: .add)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
