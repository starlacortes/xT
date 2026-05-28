//
//  JournalView.swift
//  xT
//
//  Created by Cline on 4/6/2026.
//  Redesigned journaling interface with modern mobile design
//

import SwiftUI

struct JournalView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingComposer = false
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    Spacer()
                    Text("9:41")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .frame(height: 14)
                .padding(.horizontal, 16)

                // Navigation bar with streak and FAB
                JournalNavigationBar(showingComposer: $showingComposer)

                // Journal entries list
                JournalEntryListView(entries: journalManager.entries)
                    .padding(.top, 8)
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
            .sheet(isPresented: $showingComposer) {
                JournalComposerView()
                    .environment(\.journalManager, journalManager)
                    .environment(\.medicationManager, medicationManager)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Journal Navigation Bar
struct JournalNavigationBar: View {
    @Environment(\.medicationManager) private var medicationManager
    @Binding var showingComposer: Bool

    var body: some View {
        HStack {
            Text("Journal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 10) {
                // Streak pill
                if medicationManager.isFullyConfigured,
                   let streak = medicationManager.currentStreakDays {
                    StreakPill(days: streak)
                }

                // FAB button
                Button(action: { showingComposer = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.accentColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

// MARK: - Streak Pill
struct StreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#854F0B"))

            Text("\(days) days")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#854F0B"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(hex: "#FAEEDA"))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#E5C89D"), lineWidth: 0.5)
        )
    }
}

// MARK: - Journal Entry List View
struct JournalEntryListView: View {
    let entries: [JournalEntry]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // This week section
                if !entries.isEmpty {
                    SectionHeader(title: "This week")

                    ForEach(entries.prefix(3)) { entry in
                        JournalEntryCard(entry: entry)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }

                    // Earlier section
                    if entries.count > 3 {
                        SectionHeader(title: "Earlier")
                            .padding(.top, 14)

                        // Grid layout for earlier entries
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(entries.dropFirst(3)) { entry in
                                JournalEntryCard(entry: entry, compact: true)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                } else {
                    EmptyJournalView()
                }
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }
}

// MARK: - Journal Entry Card
struct JournalEntryCard: View {
    let entry: JournalEntry
    let compact: Bool

    init(entry: JournalEntry, compact: Bool = false) {
        self.entry = entry
        self.compact = compact
    }

    private var palette: JournalPalette { JournalTheme.palette(for: entry.mood) }

    var body: some View {
        if compact {
            compactCard
        } else {
            fullCard
        }
    }

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // Mood dot
                ZStack {
                    Circle()
                        .fill(palette.surface)
                        .frame(width: 28, height: 28)

                    Image(systemName: entry.mood.icon)
                        .font(.system(size: 16))
                        .foregroundColor(palette.accent)
                }

                // Entry content
                VStack(alignment: .leading, spacing: 4) {
                    // Date and time
                    HStack {
                        Text(entry.date.journalDateLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(palette.title)

                        Spacer()

                        Text(entry.date, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(palette.accent)
                    }

                    // Entry text
                    if !entry.text.isEmpty {
                        Text(entry.previewText)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(palette.title)
                            .lineSpacing(2)
                            .padding(.bottom, 8)
                    }

                    // Symptoms tags
                    if !entry.symptoms.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(Array(entry.symptoms.prefix(2)), id: \.id) { symptom in
                                Text(symptom.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(palette.title)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(palette.border)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(palette.border, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
        .background(palette.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(palette.border, lineWidth: 0.5)
        )
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date, style: .date)
                .font(.system(size: 10))
                .foregroundColor(palette.title)

            // Mood icon
            Image(systemName: entry.mood.icon)
                .font(.system(size: 22))
                .foregroundColor(palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.text.isEmpty {
                Text(entry.previewText)
                    .font(.system(size: 11, design: .serif))
                    .foregroundColor(palette.title)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Empty Journal View
struct EmptyJournalView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .padding(.top, 60)

            Text("No journal entries yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            Text("Tap the + button to create your first entry")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        JournalView()
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}