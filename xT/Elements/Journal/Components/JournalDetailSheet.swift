//
//  JournalDetailSheet.swift
//  xT
//
//  A past journal entry on sheet glass (elements J4, J10). Flush content — no inner cards,
//  no mood valence color. The level always carries its unit. Edit opens the composer.
//

import SwiftUI

struct JournalDetailSheet: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry
    /// Opens the composer in edit mode (J10). The host clears this sheet first.
    var onEdit: () -> Void = {}

    private var period: DayPeriod { DayPeriod(date: entry.date) }
    private var unit: String {
        medicationManager.selectedMedication == "Estrogen" ? "pg/mL" : "ng/dL"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    if let level = entry.hormoneLevel {
                        section("Current level") {
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("\(AppNumberFormatters.hormoneLevel.string(level)) \(unit)")
                                    .font(Theme.Fonts.statValue)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Pill(text: levelBandLabel(for: level, medication: medicationManager.selectedMedication))
                            }
                        }
                    }

                    if !entry.text.isEmpty {
                        section("Entry") {
                            Text(entry.text)
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !entry.symptoms.isEmpty {
                        section("Symptoms") {
                            FlowLayout(spacing: Theme.Spacing.tiny) {
                                ForEach(entry.symptoms, id: \.id) { symptom in
                                    Pill(text: symptom.name)
                                }
                            }
                        }
                    }

                    Spacer(minLength: Theme.Spacing.lg)
                }
                .padding(Theme.Spacing.card)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(entry.date.journalDateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { onEdit() }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: period.glyph)
                .font(Theme.Fonts.title3)
                .foregroundStyle(Theme.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(AppDateFormatters.weekday.string(from: entry.date))
                        .font(Theme.Fonts.serifTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(period.word)
                        .font(Theme.Fonts.serifBody)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Text(AppDateFormatters.time.string(from: entry.date))
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monoLabel()
            }

            Spacer()

            Pill(text: entry.mood.displayName, style: .active)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title).eyebrow()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    JournalDetailSheet(entry: JournalEntry(
        date: Date(),
        mood: .happy,
        text: "Skin has been really soft this week. Noticed my mood staying really level throughout the day too.",
        symptoms: Array(Symptom.commonSymptoms.prefix(2)),
        hormoneLevel: 180
    ))
    .environment(\.medicationManager, MedicationManager.shared)
}
#endif
