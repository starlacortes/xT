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
    @State private var selectedSymptoms: Set<Symptom> = []
    @FocusState private var textFocused: Bool

    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    Spacer()
                    Text("9:41")
                        .font(Theme.Fonts.micro)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(height: 14)
                .padding(.horizontal, Theme.Spacing.lg)

                // Custom navigation bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("New entry")
                        .font(Theme.Fonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(Date.now, formatter: weekdayFormatter)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Mood selector
                        Text("How are you feeling?")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.05)
                            .padding(.leading, Theme.Spacing.card)

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

                        // Text entry
                        Text("Your entry")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.05)
                            .padding(.leading, Theme.Spacing.card)

                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Write how you're feeling…")
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
                                .frame(minHeight: 80)
                                .padding(Theme.Spacing.md)
                        }
                        .background(Theme.Colors.Bloom.cycle.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.md)
                                .stroke(Theme.Colors.Bloom.cycle.border, lineWidth: 0.5)
                        )
                        .padding(.horizontal, Theme.Spacing.card)

                        // Symptoms selector
                        Text("Symptoms")
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.05)
                            .padding(.leading, Theme.Spacing.card)

                        FlowLayout(spacing: 6) {
                            ForEach(Symptom.commonSymptoms) { symptom in
                                let isSelected = selectedSymptoms.contains { $0.id == symptom.id }
                                SymptomTag(symptom: symptom, isSelected: isSelected) {
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        if isSelected {
                                            selectedSymptoms = selectedSymptoms.filter { $0.id != symptom.id }
                                        } else {
                                            selectedSymptoms.insert(symptom)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.card)

                        // Hormone insight card
                        if medicationManager.isFullyConfigured,
                           let level = medicationManager.estimatedRecentLevels(days: 1).last?.value {
                            HormoneInsightCard(level: level)
                                .padding(.horizontal, Theme.Spacing.card)
                        }

                        // Save button
                        Button(action: saveAndDismiss) {
                            HStack {
                                Spacer()
                                Text("Save entry ↗")
                                    .font(Theme.Fonts.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 13)
                            .background(Theme.Colors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, Theme.Spacing.card)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .onAppear {
                textFocused = true
            }
        }
    }

    private static let journalText = Color(lightHex: "#72243E", darkHex: "#F4A8C0")

    private func saveAndDismiss() {
        let entry = JournalEntry(
            date: Date(),
            mood: selectedMood,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            symptoms: selectedSymptoms
        )
        journalManager.addEntry(entry)
        dismiss()
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
                    .foregroundStyle(isSelected ? Theme.Colors.Bloom.cycle.base : .secondary)
            }
            .frame(minWidth: 52)
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.Bloom.cycle.surface : Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(
                        isSelected ? Theme.Colors.Bloom.cycle.border : Color(UIColor.separator).opacity(0.4),
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
                .foregroundStyle(isSelected ? Theme.Colors.Bloom.cycle.base : .secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 7)
                .background(isSelected ? Theme.Colors.Bloom.cycle.surface : Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .stroke(
                            isSelected ? Theme.Colors.Bloom.cycle.border : Color(UIColor.separator).opacity(0.3),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hormone Insight Card

struct HormoneInsightCard: View {
    @Environment(\.medicationManager) private var medicationManager
    let level: Double

    // Dark lavender — readable on mind surface in both modes
    private static let mindText = Color(lightHex: "#3C3489", darkHex: "#ABA7F0")

    private var rangeName: String {
        guard let med = medicationManager.selectedMedication else { return "" }
        if med == "Estrogen" {
            if level < 50 { return "Very low" }
            if level < 100 { return "Low" }
            if level < 200 { return "Optimal" }
            if level < 500 { return "High" }
            return "Very high"
        } else {
            if level < 50 { return "Suppressed" }
            if level < 200 { return "Low male" }
            if level < 800 { return "Male range" }
            return "High male"
        }
    }

    private var rangeColor: Color {
        switch rangeName {
        case "Optimal", "Suppressed": return Theme.Colors.success
        case "Low", "Low male":       return Theme.Colors.Bloom.body.base
        default:                       return Theme.Colors.Bloom.cycle.base
        }
    }

    private var rangeBg: Color {
        switch rangeName {
        case "Optimal", "Suppressed": return Theme.Colors.success.opacity(0.12)
        case "Low", "Low male":       return Theme.Colors.Bloom.body.surface
        default:                       return Theme.Colors.Bloom.cycle.surface
        }
    }

    private var unit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.Bloom.mind.base)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.Bloom.mind.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's level")
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(Theme.Colors.Bloom.mind.base)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(level)) \(unit)")
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
        .background(Theme.Colors.Bloom.mind.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.Bloom.mind.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

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
