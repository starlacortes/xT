//
//  JournalView.swift
//  xT
//
//  Redesigned journaling interface with modern mobile design.
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
                JournalNavigationBar(showingComposer: $showingComposer)

                JournalEntryListView(entries: journalManager.entries, selectedEntry: $selectedEntry)
                    .padding(.top, Theme.Spacing.sm)
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Gradients.brand)
            .sheet(isPresented: $showingComposer) {
                JournalComposerView()
                    .environment(\.journalManager, journalManager)
                    .environment(\.medicationManager, medicationManager)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedEntry) { entry in
                JournalDetailSheet(entry: entry)
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
                .font(Theme.Fonts.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 10) {
                if medicationManager.isFullyConfigured,
                   let streak = medicationManager.currentStreakDays {
                    StreakPill(days: streak)
                }

                Button(action: { showingComposer = true }) {
                    Image(systemName: "plus")
                        .font(Theme.Fonts.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.accent)
                        .clipShape(Circle())
                        .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.pressable)
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
                .foregroundStyle(Theme.Colors.Bloom.body.base)

            AnimatedCounter(value: Double(days), format: { "\(Int($0.rounded())) days" })
                .font(Theme.Fonts.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.Bloom.body.base)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 5)
        .background(Theme.Colors.Bloom.body.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Colors.Bloom.body.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Journal Entry List View

struct JournalEntryListView: View {
    let entries: [JournalEntry]
    @Binding var selectedEntry: JournalEntry?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !entries.isEmpty {
                    SectionHeader(title: "This week")

                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        Button { selectedEntry = entry } label: {
                            JournalEntryCard(entry: entry)
                        }
                        .buttonStyle(.pressable)
                        .padding(.horizontal, Theme.Spacing.card)
                        .padding(.bottom, 10)
                        .entrance(index: index)
                    }

                    if entries.count > 3 {
                        SectionHeader(title: "Earlier")
                            .padding(.top, Theme.Spacing.lg)

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: Theme.Spacing.sm), GridItem(.flexible(), spacing: Theme.Spacing.sm)],
                            spacing: Theme.Spacing.sm
                        ) {
                            ForEach(Array(entries.dropFirst(3).enumerated()), id: \.element.id) { index, entry in
                                Button { selectedEntry = entry } label: {
                                    JournalEntryCard(entry: entry, compact: true)
                                }
                                .buttonStyle(.pressable)
                                .entrance(index: index + 3)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.card)
                        .padding(.bottom, Theme.Spacing.card)
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
            .font(Theme.Fonts.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.card)
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
        if compact { compactCard } else { fullCard }
    }

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(palette.surface)
                        .frame(width: 28, height: 28)
                    Image(systemName: entry.mood.icon)
                        .font(Theme.Fonts.callout)
                        .foregroundStyle(palette.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.date.journalDateLabel)
                            .font(Theme.Fonts.footnote)
                            .fontWeight(.medium)
                            .foregroundStyle(palette.title)

                        Spacer()

                        Text(entry.date, style: .time)
                            .font(Theme.Fonts.caption2)
                            .foregroundStyle(palette.accent)
                    }

                    if !entry.text.isEmpty {
                        Text(entry.previewText)
                            .font(.system(.caption, design: .serif))
                            .foregroundStyle(palette.title)
                            .lineSpacing(2)
                            .padding(.bottom, Theme.Spacing.sm)
                    }

                    if !entry.symptoms.isEmpty {
                        FlowLayout(spacing: 5) {
                            ForEach(Array(entry.symptoms.prefix(2)), id: \.id) { symptom in
                                Text(symptom.name)
                                    .font(Theme.Fonts.micro)
                                    .foregroundStyle(palette.title)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, 2)
                                    .background(palette.border)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .stroke(palette.border, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.card)
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(palette.border, lineWidth: 0.5)
        )
    }

    private var compactCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date, style: .date)
                .font(Theme.Fonts.micro)
                .foregroundStyle(palette.title)

            Image(systemName: entry.mood.icon)
                .font(Theme.Fonts.title3)
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.text.isEmpty {
                Text(entry.previewText)
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(palette.title)
                    .lineLimit(2)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(palette.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Empty Journal View

struct EmptyJournalView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.top, 60)

            Text("No journal entries yet")
                .font(Theme.Fonts.callout)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("Tap the + button to create your first entry")
                .font(Theme.Fonts.footnote)
                .foregroundStyle(.secondary)
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
