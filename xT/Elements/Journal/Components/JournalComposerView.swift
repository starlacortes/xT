//
//  JournalComposerView.swift
//  xT
//
//  The journal composer on sheet glass (elements J7, J9, J10). It writes a new entry or
//  edits an existing one. The sheet's own glass is the surface — no opaque ground, no
//  material bar; Cancel and Save are toolbar items. The text area is a ghost-card outline
//  in Atkinson ink; mood and symptoms are Isocline `Pill`s with no valence color.
//

import SwiftUI

struct JournalComposerView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    /// The entry being edited, or nil for a new one (J10).
    private let entry: JournalEntry?

    @State private var text: String
    @State private var selectedMood: Mood
    @State private var selectedSymptoms: [Symptom]
    @State private var showingDiscardDialog = false
    @FocusState private var textFocused: Bool

    init(entry: JournalEntry? = nil) {
        self.entry = entry
        _text = State(initialValue: entry?.text ?? "")
        _selectedMood = State(initialValue: entry?.mood ?? .neutral)
        // Resolve stored symptoms back to the common palette by name — their UUIDs
        // regenerate each launch, so matching by id would drop the selection (J10).
        _selectedSymptoms = State(initialValue: entry?.symptoms.map {
            Symptom.matching(name: $0.name) ?? $0
        } ?? [])
    }

    private var isEditing: Bool { entry != nil }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        if isEditing {
            return text != (entry?.text ?? "")
                || selectedMood != entry?.mood
                || selectedSymptoms.map(\.name) != (entry?.symptoms.map(\.name) ?? [])
        }
        return canSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(isEditing ? "Edit entry" : "New entry")
                        .font(Theme.Fonts.serifTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    entryField
                    levelRow
                    symptomsField
                    moodField

                    Spacer(minLength: Theme.Spacing.xl)
                }
                .padding(Theme.Spacing.card)
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showingDiscardDialog = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { textFocused = true }
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showingDiscardDialog,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Your changes will not be saved.")
            }
            .interactiveDismissDisabled(hasChanges)
            .background(SheetDismissAttemptObserver { showingDiscardDialog = true })
        }
    }

    // MARK: - Fields

    private var entryField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Your entry").eyebrow()

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Write how you're feeling\u{2026}")
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .padding(.top, Theme.Spacing.sm + 2)
                        .padding(.leading, Theme.Spacing.sm)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .focused($textFocused)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
            }
            .ghostCard(padding: Theme.Spacing.sm, radius: Theme.Radius.md)
        }
    }

    @ViewBuilder
    private var levelRow: some View {
        if medicationManager.isFullyConfigured,
           let level = medicationManager.currentHormoneLevel?.value {
            let unit = medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Current level").eyebrow()
                HStack(spacing: Theme.Spacing.sm) {
                    Text("\(AppNumberFormatters.hormoneLevel.string(level)) \(unit)")
                        .font(Theme.Fonts.statValue)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Pill(text: levelBandLabel(for: level, medication: medicationManager.selectedMedication))
                    Spacer()
                }
            }
        }
    }

    private var symptomsField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Symptoms").eyebrow()
            FlowLayout(spacing: Theme.Spacing.tiny) {
                ForEach(Symptom.commonSymptoms) { symptom in
                    let isSelected = selectedSymptoms.contains { $0.name == symptom.name }
                    Button {
                        withAnimation(.easeInOut(duration: 0.12)) { toggle(symptom) }
                    } label: {
                        Pill(text: symptom.name, style: isSelected ? .active : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moodField: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("How are you feeling?").eyebrow()
            FlowLayout(spacing: Theme.Spacing.tiny) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedMood = mood }
                    } label: {
                        Pill(text: mood.displayName, style: selectedMood == mood ? .active : .neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggle(_ symptom: Symptom) {
        if let idx = selectedSymptoms.firstIndex(where: { $0.name == symptom.name }) {
            selectedSymptoms.remove(at: idx)
        } else {
            selectedSymptoms.append(symptom)
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.text = trimmed
            entry.mood = selectedMood
            entry.symptoms = selectedSymptoms
            journalManager.update(entry)
        } else {
            let new = JournalEntry(
                date: Date(),
                mood: selectedMood,
                text: trimmed,
                symptoms: selectedSymptoms,
                hormoneLevel: medicationManager.currentHormoneLevel?.value
            )
            journalManager.addEntry(new)
        }
        dismiss()
    }
}

// MARK: - Sheet Dismiss Attempt Observer

/// Bridges UIKit's "swipe attempt on a non-dismissable sheet" into SwiftUI.
///
/// SwiftUI's `interactiveDismissDisabled(_:)` has no attempt callback. When it
/// blocks a swipe, UIKit instead calls `presentationControllerDidAttemptToDismiss`
/// on the sheet's presentation delegate. This invisible controller view takes
/// over as delegate to catch that call, forwarding every other delegate method
/// to SwiftUI's original delegate so the sheet machinery is unaffected.
private struct SheetDismissAttemptObserver: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> ObserverViewController {
        ObserverViewController()
    }

    func updateUIViewController(_ viewController: ObserverViewController, context: Context) {
        viewController.onAttempt = onAttempt
    }

    final class ObserverViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
        var onAttempt: (() -> Void)?
        private weak var originalDelegate: NSObject?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let presentationController else { return }
            originalDelegate = presentationController.delegate as? NSObject
            presentationController.delegate = self
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt?()
        }

        // MARK: Forwarding to SwiftUI's original delegate

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector)
                || originalDelegate?.responds(to: aSelector) == true
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if let originalDelegate, originalDelegate.responds(to: aSelector) {
                return originalDelegate
            }
            return super.forwardingTarget(for: aSelector)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    JournalComposerView()
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}
#endif

// MARK: - Level band labelling

/// Names the band a level falls in, by its numbers.
///
/// This used to return "Optimal" / "High" and tint "Optimal" green. That reads as
/// a verdict on a reading the journal is only recording alongside an entry — and
/// the thresholds are population defaults, not anything the user chose. The label
/// now states the band; the colour is uniform.
func levelBandLabel(for level: Double, medication: String?) -> String {
    guard let med = medication else { return "" }
    if med == "Estrogen" {
        if level < 50  { return String(localized: "below 50 pg/mL", comment: "Estradiol band label shown beside a journal entry") }
        if level < 100 { return String(localized: "50–100 pg/mL", comment: "Estradiol band label shown beside a journal entry") }
        if level < 200 { return String(localized: "100–200 pg/mL", comment: "Estradiol band label shown beside a journal entry") }
        if level < 500 { return String(localized: "200–500 pg/mL", comment: "Estradiol band label shown beside a journal entry") }
        return String(localized: "above 500 pg/mL", comment: "Estradiol band label shown beside a journal entry")
    }
    if level < 50  { return String(localized: "below 50 ng/dL", comment: "Testosterone band label shown beside a journal entry") }
    if level < 200 { return String(localized: "50–200 ng/dL", comment: "Testosterone band label shown beside a journal entry") }
    if level < 800 { return String(localized: "200–800 ng/dL", comment: "Testosterone band label shown beside a journal entry") }
    return String(localized: "above 800 ng/dL", comment: "Testosterone band label shown beside a journal entry")
}
