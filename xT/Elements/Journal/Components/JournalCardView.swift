//
//  JournalCardView.swift
//  xT
//
//  Created by Starla Cortes on 6/10/26.
//  Journal card component
//

import SwiftUI

struct JournalCardView: View {
    let entry: JournalEntry

    var body: some View {
        NavigationLink(destination: JournalView()) {
            HStack(spacing: 10) {
                Text("🌸")
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's journal")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .foregroundColor(Theme.accentColor)

                    HStack(spacing: 4) {
                        Text(entry.date, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        Text(entry.mood.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))

                        if !entry.symptoms.isEmpty {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Text("\(entry.symptoms.count) symptom\(entry.symptoms.count == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !entry.text.isEmpty {
                        Text(entry.previewText)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accentColor.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accentColor)
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(Theme.mediumCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.mediumCornerRadius)
                    .stroke(Theme.bloomCycleBorderColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    JournalCardView(entry: JournalEntry(
        id: UUID(),
        date: Date(),
        mood: .happy,
        text: "This is a sample journal entry for preview purposes.",
        symptoms: [Symptom(name: "headache", icon: "brain.head.profile"), Symptom(name: "fatigue", icon: "bed.double")]
    ))
}
