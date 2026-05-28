//
//  JournalHistoryComponents.swift
//  xT
//
//  Created by Cline on 5/25/2026.
//  Journal history components for browsing past entries
//

import SwiftUI

// MARK: - Journal History View Content
struct JournalHistoryViewContent: View {
    @Environment(\.journalManager) private var journalManager
    @Binding var journalEntry: String
    @Binding var selectedMood: Mood
    @State private var showingEntryDetail = false
    @State private var selectedEntry: JournalEntry?
    @State private var showingNewEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal")
                .font(.title)
                .foregroundColor(.purple)
                .padding(.horizontal)
            

            if journalManager.entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundColor(Theme.tertiaryTextColor)

                    Text("No entries yet")
                        .font(.headline)
                        .foregroundColor(Theme.tertiaryTextColor)

                    Text("Start your journaling journey by creating your first entry!")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Theme.tertiaryTextColor)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .aspectRatio(contentMode: .fit)
            } else {
                // Grid layout for square cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 16)], spacing: 16) {
                    // Add new entry card
                    Button(action: {
                        showingNewEntry = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.purple)
                            Text("Add Entry")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        .frame(width: 120, height: 120)
                        .asGlassCard()
                    }

                    // Journal entry cards
                    ForEach(journalManager.entries) { entry in
                        JournalEntryCard(entry: entry)
                            .onTapGesture {
                                selectedEntry = entry
                                showingEntryDetail = true
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationDestination(isPresented: $showingEntryDetail) {
            if let entry = selectedEntry {
                JournalDetailView(entry: entry)
            }
        }
        .navigationDestination(isPresented: $showingNewEntry) {
            JournalLogViewContent(journalEntry: $journalEntry, selectedMood: $selectedMood)
        }
    }
}

// MARK: - Journal Entry Card
struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(spacing: 8) {
            // Prominent mood emoji
            Image(systemName: entry.mood.icon)
                .font(.largeTitle)
                .foregroundColor(Theme.accentColor)

            // Date under the emoji
            Text(entry.date, style: .date)
                .font(.caption)
                .foregroundColor(Theme.secondaryTextColor)
        }
        .frame(width: 120, height: 120)
        .asGlassCard()
    }
}

// MARK: - Journal Detail View
struct JournalDetailView: View {
    let entry: JournalEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Date and mood
                HStack {
                    Text(entry.date, style: .date)
                        .font(.title3)
                        .fontWeight(.bold)

                    Spacer()

                    Image(systemName: entry.mood.icon)
                        .foregroundColor(Theme.accentColor)
                        .font(.title2)
                }
                .padding(.horizontal)

                // Symptoms
                if !entry.symptoms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Symptoms")
                            .font(.headline)

                        HStack {
                            ForEach(Array(entry.symptoms), id: \.id) { symptom in
                                HStack(spacing: 4) {
                                    Image(systemName: symptom.icon)
                                        .font(.caption)
                                    Text(symptom.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.tertiaryTextColor.opacity(0.1))
                                .cornerRadius(Theme.smallCornerRadius)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Full text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entry")
                        .font(.headline)

                    Text(entry.text)
                        .font(.body)
                        .foregroundColor(Theme.secondaryTextColor)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}
