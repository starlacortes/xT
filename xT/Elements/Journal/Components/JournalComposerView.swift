//
//  JournalComposerView.swift
//  xT
//
//  Full-screen composer sheet for new journal entries.
//

import SwiftUI

struct JournalComposerView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var selectedMood: Mood = .neutral
    @State private var selectedSymptoms: [Symptom] = []
    @State private var showingDiscardDialog = false
    @FocusState private var textFocused: Bool

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasEnteredText: Bool { canSave }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("New Entry.")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.top, 12)
                        .padding(.leading, Theme.Spacing.card)

                    // "Your Entry" text box — taller
                    Text("Your entry")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.05)
                        .padding(.leading, Theme.Spacing.card)

                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Write how you're feeling\u{2026}")
                                .font(.system(.footnote, design: .serif))
                                .foregroundStyle(Theme.Colors.accent.opacity(0.7))
                                .padding(.top, Theme.Spacing.card)
                                .padding(.leading, Theme.Spacing.lg)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $text)
                            .focused($textFocused)
                            .font(.system(.footnote, design: .serif))
                            .foregroundStyle(JournalComposerView.journalText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .padding(Theme.Spacing.md)
                    }
                    .background(Theme.Colors.Time.cycle.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.md)
                            .stroke(Theme.Colors.Time.cycle.border, lineWidth: 0.5)
                    )
                    .padding(.horizontal, Theme.Spacing.card)

                    // "Current level" — compact row
                    if medicationManager.isFullyConfigured,
                       let level = medicationManager.currentHormoneLevel?.value {
                        Text("Current level")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.05)
                            .padding(.leading, Theme.Spacing.card)

                        compactLevelRow(level: level)
                            .padding(.horizontal, Theme.Spacing.card)
                    }

                    // Symptoms — horizontally scrollable
                    Text("Symptoms")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.05)
                        .padding(.leading, Theme.Spacing.card)

                    ZStack(alignment: .trailing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(Symptom.commonSymptoms) { symptom in
                                    let isSelected = selectedSymptoms.contains(where: { $0.id == symptom.id })
                                    SymptomTag(symptom: symptom, isSelected: isSelected) {
                                        withAnimation(.easeInOut(duration: 0.12)) {
                                            if isSelected {
                                                selectedSymptoms.removeAll(where: { $0.id == symptom.id })
                                            } else {
                                                selectedSymptoms.append(symptom)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.card)
                            .padding(.vertical, 2)
                        }

                        edgeFadeGradient
                    }

                    // "How are you feeling"
                    Text("How are you feeling?")
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.05)
                        .padding(.leading, Theme.Spacing.card)

                    ZStack(alignment: .trailing) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Mood.allCases, id: \.self) { mood in
                                    MoodChip(mood: mood, isSelected: selectedMood == mood) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedMood = mood
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.card)
                            .padding(.vertical, 2)
                        }

                        edgeFadeGradient
                    }

                    Spacer(minLength: 80)
                }
            }
            .scrollIndicators(.hidden)

            Spacer()

            // Liquid glass buttons above keyboard
            HStack(spacing: 16) {
                Button {
                    if hasEnteredText {
                        showingDiscardDialog = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.Fonts.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }

                Button { saveAndDismiss() } label: {
                    Image(systemName: "checkmark")
                        .font(Theme.Fonts.title3.weight(.semibold))
                        .foregroundStyle(canSave ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .fill(canSave ? Theme.Colors.accent : Color(.tertiarySystemFill))
                        )
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .background(Theme.Colors.appBackground)
        .onAppear {
            textFocused = true
        }
        .confirmationDialog(
            "Discard entry?",
            isPresented: $showingDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Yes", role: .destructive) { dismiss() }
            Button("No", role: .cancel) {}
        } message: {
            Text("Your entry will not be saved.")
        }
        .interactiveDismissDisabled(hasEnteredText)
        .background(SheetDismissAttemptObserver {
            showingDiscardDialog = true
        })
    }

    private var edgeFadeGradient: some View {
        LinearGradient(
            colors: [Theme.Colors.appBackground.opacity(0), Theme.Colors.appBackground],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 24)
        .allowsHitTesting(false)
    }

    private func compactLevelRow(level: Double) -> some View {
        let name = rangeName(for: level)
        let unit = medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
        return HStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.Time.mind.base)
            Text("\(AppNumberFormatters.hormoneLevel.string(level)) \(unit)")
                .font(Theme.Fonts.subheadline.weight(.medium))
                .foregroundStyle(Color(lightHex: "#3C3489", darkHex: "#ABA7F0"))
            Text(name)
                .font(Theme.Fonts.caption2.weight(.medium))
                .foregroundStyle(rangeColor(for: name))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(rangeBg(for: name))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            Spacer()
        }
        .padding(10)
        .background(Theme.Colors.Time.mind.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.Time.mind.border, lineWidth: 0.5)
        )
    }

    private func rangeName(for level: Double) -> String {
        levelBandLabel(for: level, medication: medicationManager.selectedMedication)
    }

    private func rangeColor(for name: String) -> Color { Theme.Colors.Time.cycle.base }

    private func rangeBg(for name: String) -> Color { Theme.Colors.Time.cycle.surface }

    private static let journalText = Color(lightHex: "#72243E", darkHex: "#F4A8C0")

    private func saveAndDismiss() {
        let entry = JournalEntry(
            date: Date(),
            mood: selectedMood,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            symptoms: selectedSymptoms,
            hormoneLevel: medicationManager.currentHormoneLevel?.value
        )
        journalManager.addEntry(entry)
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

// MARK: - Mood Chip

struct MoodChip: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: mood.icon)
                    .font(Theme.Fonts.title3)
                    .foregroundStyle(isSelected ? Theme.Colors.accent : .secondary)

                Text(mood.rawValue)
                    .font(Theme.Fonts.micro)
                    .foregroundStyle(isSelected ? Theme.Colors.Time.cycle.base : .secondary)
            }
            .frame(minWidth: 52)
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.Time.cycle.surface : Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        isSelected ? Theme.Colors.Time.cycle.border : Color(UIColor.separator).opacity(0.4),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symptom Tag

struct SymptomTag: View {
    let symptom: Symptom
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symptom.name)
                .font(Theme.Fonts.caption)
                .foregroundStyle(isSelected ? Theme.Colors.Time.cycle.base : .secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.Colors.Time.cycle.surface : Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(
                            isSelected ? Theme.Colors.Time.cycle.border : Color(UIColor.separator).opacity(0.3),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hormone Insight Card (legacy; kept for previews)

struct HormoneInsightCard: View {
    @Environment(\.medicationManager) private var medicationManager
    let level: Double

    private static let mindText = Color(lightHex: "#3C3489", darkHex: "#ABA7F0")

    private var rangeName: String {
        levelBandLabel(for: level, medication: medicationManager.selectedMedication)
    }

    private var rangeColor: Color { Theme.Colors.Time.cycle.base }

    private var rangeBg: Color { Theme.Colors.Time.cycle.surface }

    private var unit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.Time.mind.base)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.Time.mind.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text("Current level")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Theme.Colors.Time.mind.base)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(AppNumberFormatters.hormoneLevel.string(level)) \(unit)")
                        .font(Theme.Fonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Self.mindText)

                    Text(rangeName)
                        .font(Theme.Fonts.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(rangeColor)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(rangeBg)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
            }

            Spacer()
        }
        .padding(10)
        .background(Theme.Colors.Time.mind.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.Time.mind.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    JournalComposerView()
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}

#Preview("MoodChip") {
    MoodChip(mood: .happy, isSelected: true, action: {})
}

#Preview("SymptomTag") {
    SymptomTag(symptom: Symptom(name: "Headache", icon: "brain.head.profile"), isSelected: false, action: {})
}

#Preview("HormoneInsightCard") {
    HormoneInsightCard(level: 150.0)
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
private func levelBandLabel(for level: Double, medication: String?) -> String {
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
