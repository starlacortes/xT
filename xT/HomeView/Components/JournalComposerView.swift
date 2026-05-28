//
//  JournalComposerView.swift
//  xT
//
//  Full-screen composer sheet for new journal entries
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Date header
                    Text(Date.now.composerDateLabel)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    // Mood selector
                    ComposerSection(label: "How are you feeling?") {
                        MoodChipRow(selectedMood: $selectedMood)
                    }

                    // Text entry
                    ComposerSection(label: "Your entry") {
                        SerialTextEditor(text: $text, focused: $textFocused)
                    }

                    // Symptom tags
                    ComposerSection(label: "Symptoms") {
                        SymptomTagCloud(selectedSymptoms: $selectedSymptoms)
                    }

                    // Hormone insight card (auto-populated)
                    if medicationManager.isFullyConfigured,
                       let level = medicationManager.estimatedRecentLevels(days: 1).last?.value {
                        HormoneInsightCard(level: level)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(JournalTheme.rose)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { textFocused = true }
        }
    }

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

// MARK: - Composer Section wrapper

struct ComposerSection<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}

// MARK: - Mood Chip Row

struct MoodChipRow: View {
    @Binding var selectedMood: Mood

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Mood.allCases, id: \.self) { mood in
                    MoodChip(mood: mood, isSelected: selectedMood == mood) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMood = mood
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct MoodChip: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: mood.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? JournalTheme.rose : .secondary)
                Text(mood.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Color(hex: "#993556") : .secondary)
            }
            .frame(minWidth: 56)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(isSelected ? Color(hex: "#FBEAF0") : Color(UIColor.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? Color(hex: "#ED93B1") : Color(UIColor.separator).opacity(0.4),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Serif Text Editor

struct SerialTextEditor: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Write how you're feeling…")
                    .font(.system(size: 14).italic())
                    .foregroundColor(Color(hex: "#ED93B1").opacity(0.7))
                    .padding(.top, 14)
                    .padding(.leading, 16)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused(focused)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(Color(hex: "#72243E"))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
        }
        .background(Color(hex: "#FBEAF0"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#F4C0D1"), lineWidth: 0.5)
        )
    }
}

// MARK: - Symptom Tag Cloud

struct SymptomTagCloud: View {
    @Binding var selectedSymptoms: Set<Symptom>

    var body: some View {
        FlowLayout(spacing: 7) {
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
    }
}

struct SymptomTag: View {
    let symptom: Symptom
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symptom.name)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? Color(hex: "#993556") : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color(hex: "#FBEAF0") : Color(UIColor.secondarySystemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isSelected ? Color(hex: "#ED93B1") : Color(UIColor.separator).opacity(0.3),
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
        case "Optimal", "Suppressed": return Color(hex: "#3B6D11")
        case "Low", "Low male": return Color(hex: "#854F0B")
        default: return Color(hex: "#993556")
        }
    }

    private var rangeBg: Color {
        switch rangeName {
        case "Optimal", "Suppressed": return Color(hex: "#EAF3DE")
        case "Low", "Low male": return Color(hex: "#FAEEDA")
        default: return Color(hex: "#FBEAF0")
        }
    }

    private var unit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#534AB7"))
                .frame(width: 36, height: 36)
                .background(Color(hex: "#EEEDFE"))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's level")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#534AB7"))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(level)) \(unit)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#3C3489"))

                    Text(rangeName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(rangeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(rangeBg)
                        .cornerRadius(10)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: "#EEEDFE"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#CECBF6"), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    JournalComposerView()
        .environment(\.journalManager, JournalManager.shared)
        .environment(\.medicationManager, MedicationManager.shared)
}