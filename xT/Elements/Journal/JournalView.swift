//
//  JournalView.swift
//  xT
//
//  Flat timeline design — matches Home screen visual language.
//

import SwiftUI

struct JournalView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @State private var showingComposer = false
    @State private var selectedEntry: JournalEntry?
    @State private var selectedDateKey: String?
    @State private var showingDoses = false

    private var doseRouteClass: RouteClass {
        RouteClass.from(method: medicationManager.selectedAdministrationMethod ?? "")
    }

    private var doseButtonIcon: String {
        switch doseRouteClass {
        case .injection: return "syringe"
        case .topical:   return "drop.fill"
        case .patch:     return "rectangle.fill"
        case .oral:      return "pills"
        }
    }

    // Group entries by calendar day, sorted most-recent first
    private var groupedEntries: [(key: String, date: Date, entries: [JournalEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: journalManager.entries) { entry in
            cal.startOfDay(for: entry.date)
        }
        return grouped
            .map { dayStart, entries in
                let key = dayStart.ISO8601Format()
                return (key: key, date: dayStart, entries: entries.sorted { $0.date > $1.date })
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            journalHeroHeader
                                .entrance(delay: 0.04)

                            if !groupedEntries.isEmpty {
                                TimelineScrubber(
                                    groups: groupedEntries.map { ($0.key, $0.date) },
                                    selectedKey: $selectedDateKey,
                                    proxy: proxy
                                )
                                .entrance(delay: 0.10)
                            }

                            if groupedEntries.isEmpty {
                                EmptyJournalView()
                                    .entrance(delay: 0.15)
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(groupedEntries.enumerated()), id: \.element.key) { gi, group in
                                        JournalDateGroup(
                                            group: group,
                                            isFirst: gi == 0,
                                            globalIndex: gi,
                                            onSelect: { selectedEntry = $0 }
                                        )
                                        .id(group.key)
                                    }
                                }
                                .padding(.bottom, 100)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color(.systemBackground))
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

            // Floating compose button
            Button(action: { showingComposer = true }) {
                Image(systemName: "plus")
                    .font(Theme.Fonts.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.pressable)
            .padding(.trailing, 22)
            .padding(.bottom, 32)
            .entrance(delay: 0.2)
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: { showingDoses = true }) {
                Image(systemName: doseButtonIcon)
                    .font(Theme.Fonts.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accentSecondary)
                    .frame(width: 50, height: 50)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.pressable)
            .padding(.leading, 22)
            .padding(.bottom, 32)
            .entrance(delay: 0.25)
        }
        .fullScreenCover(isPresented: $showingDoses) {
            NavigationStack {
                DoseHistoryView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingDoses = false }
                        }
                    }
            }
        }
    }

    // MARK: - Hero Header

    private var journalHeroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Journal")
                .font(.system(size: 52, weight: .bold))
                .tracking(-1.0)
                .foregroundStyle(
                    LinearGradient(
                        colors: Theme.Gradients.brandColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            let count = journalManager.entries.count
            if count > 0 {
                Text(count == 1 ? "1 entry" : "\(count) entries")
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 48)
        .padding(.bottom, 8)
    }
}

// MARK: - Date Group Section

private struct JournalDateGroup: View {
    let group: (key: String, date: Date, entries: [JournalEntry])
    let isFirst: Bool
    let globalIndex: Int
    let onSelect: (JournalEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(group.date.journalDateLabel.uppercased())
                .font(Theme.Fonts.caption2)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, isFirst ? 14 : 24)
                .padding(.bottom, 10)

            Divider()
                .opacity(0.5)

            ForEach(Array(group.entries.enumerated()), id: \.element.id) { ei, entry in
                Button { onSelect(entry) } label: {
                    JournalEntryRow(entry: entry)
                }
                .buttonStyle(.pressable)
                .entrance(index: globalIndex + ei)

                if ei < group.entries.count - 1 {
                    Divider()
                        .opacity(0.5)
                        .padding(.leading, 44)
                }
            }
        }
    }
}

// MARK: - Timeline Scrubber

struct TimelineScrubber: View {
    let groups: [(key: String, date: Date)]
    @Binding var selectedKey: String?
    let proxy: ScrollViewProxy

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(groups, id: \.key) { key, date in
                    let isSelected = selectedKey == key
                    Button {
                        withAnimation(Theme.Motion.snappy) {
                            selectedKey = key
                            proxy.scrollTo(key, anchor: .top)
                        }
                    } label: {
                        Text(scrubberLabel(for: date))
                            .font(Theme.Fonts.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    Capsule().fill(Theme.Gradients.brand)
                                } else {
                                    Capsule().fill(Color(.secondarySystemBackground))
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 10)
    }

    private func scrubberLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

// MARK: - Journal Entry Row (flat)

struct JournalEntryRow: View {
    let entry: JournalEntry

    private var palette: JournalPalette { JournalTheme.palette(for: entry.mood) }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(palette.accent)
                .frame(width: 8, height: 8)
                .padding(.leading, 22)

            VStack(alignment: .leading, spacing: 3) {
                if !entry.text.isEmpty {
                    Text(entry.previewText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    Text(entry.mood.rawValue)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(palette.accent)

                    if let first = entry.symptoms.first {
                        Text("·")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary.opacity(0.5))
                        Text(first.name)
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text(entry.date, style: .time)
                    .font(Theme.Fonts.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.trailing, 22)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty State

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
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Preview

#Preview {
    SpoofPreview {
        JournalView()
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
