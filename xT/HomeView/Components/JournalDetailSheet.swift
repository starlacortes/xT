//
//  JournalDetailSheet.swift
//  xT
//
//  Read-only detail view for a past journal entry, presented as a sheet
//

import SwiftUI

struct JournalDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry

    private var palette: JournalPalette { JournalTheme.palette(for: entry.mood) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header: mood + date
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(palette.surface)
                                .frame(width: 52, height: 52)
                            Image(systemName: entry.mood.icon)
                                .font(.system(size: 24))
                                .foregroundColor(palette.accent)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.mood.rawValue)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(palette.title)
                            Text(entry.date.fullDateLabel)
                                .font(.system(size: 13))
                                .foregroundColor(palette.accent)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(palette.surface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(palette.border, lineWidth: 0.5)
                    )

                    // Entry text
                    if !entry.text.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Entry", systemImage: "pencil")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            Text(entry.text)
                                .font(.system(size: 15, design: .serif))
                                .foregroundColor(palette.title)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(palette.surface)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(palette.border, lineWidth: 0.5)
                                )
                        }
                    }

                    // Symptoms
                    if !entry.symptoms.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Symptoms", systemImage: "list.bullet")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            FlowLayout(spacing: 7) {
                                ForEach(Array(entry.symptoms), id: \.id) { symptom in
                                    HStack(spacing: 5) {
                                        Image(systemName: symptom.icon)
                                            .font(.system(size: 11))
                                        Text(symptom.name)
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(palette.title)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(palette.tag)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(palette.border, lineWidth: 0.5)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(entry.date.journalDateLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(JournalTheme.rose)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    JournalDetailSheet(entry: JournalEntry(
        date: Date(),
        mood: .happy,
        text: "Skin has been really soft this week. Noticed my mood staying really level throughout the day too.",
        symptoms: Set(Symptom.commonSymptoms.prefix(2))
    ))
    .environment(\.journalManager, JournalManager.shared)
}