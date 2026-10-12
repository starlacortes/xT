//
//  JournalView.swift
//  xT
//
//  The Journal on Isocline paper (elements J1–J8). An ink serif title, a seven-day week
//  strip with dose and entry dots, a top slot that is a "now" card when today carries an
//  entry (otherwise a ghost invitation), and flush day-grouped rows beneath. One centered
//  floating "New entry" pill rests on a paper fade so the rows scroll under it.
//
//  This retires the brand-gradient title, the `TimelineScrubber`, the mood-dot rows, the
//  circular FAB and the material dose-history button (J1, J2, J4, J8). Mood no longer
//  carries a valence color (J7).
//

import SwiftUI

struct JournalView: View {
    @Environment(\.journalManager) private var journalManager
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.appRouter) private var router
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var showingComposer = false
    @State private var editingEntry: JournalEntry?
    @State private var selectedEntry: JournalEntry?
    @State private var entryToDelete: JournalEntry?

    private let hPad: CGFloat = 22
    private static let topAnchor = "journal-top"

    // MARK: - Derived state

    private var topSlot: JournalTopSlot { journalManager.topSlot }

    /// The entry promoted to the top card, if any — excluded from the row list (J3).
    private var cardEntryID: UUID? {
        if case .card(let entry) = topSlot { return entry.id }
        return nil
    }

    /// Row entries (everything except the card entry), grouped by calendar day, newest first.
    private var groupedEntries: [(key: String, date: Date, entries: [JournalEntry])] {
        let cal = Calendar.current
        let rows = journalManager.entries.filter { $0.id != cardEntryID }
        let grouped = Dictionary(grouping: rows) { cal.startOfDay(for: $0.date) }
        return grouped
            .map { dayStart, entries in
                (key: dayStart.ISO8601Format(), date: dayStart, entries: entries.sorted { $0.date > $1.date })
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        journalHeroHeader
                            .id(Self.topAnchor)

                        JournalWeekStrip(
                            journalManager: journalManager,
                            medicationManager: medicationManager,
                            hPad: hPad,
                            onSelectDay: { key in
                                withAnimation(Theme.Motion.snappy) { proxy.scrollTo(key, anchor: .top) }
                            }
                        )

                        topSlotView
                            .padding(.horizontal, hPad)
                            .padding(.top, Theme.Spacing.sm)

                        LazyVStack(spacing: 0) {
                            ForEach(groupedEntries, id: \.key) { group in
                                JournalDayGroup(
                                    group: group,
                                    medicationManager: medicationManager,
                                    hPad: hPad,
                                    onSelect: { selectedEntry = $0 },
                                    onDelete: { entryToDelete = $0 }
                                )
                                .id(group.key)
                            }
                        }
                        .padding(.top, Theme.Spacing.sm)

                        Spacer(minLength: 120)
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: router.journalScrollToTop) { _, scroll in
                    guard scroll else { return }
                    withAnimation(Theme.Motion.snappy) { proxy.scrollTo(Self.topAnchor, anchor: .top) }
                    router.journalScrollToTop = false
                }
            }
            .background(Theme.Colors.appBackground.ignoresSafeArea())
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) { floatingNewEntry }
            .sheet(isPresented: $showingComposer) {
                JournalComposerView()
                    .environment(\.journalManager, journalManager)
                    .environment(\.medicationManager, medicationManager)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $editingEntry) { entry in
                JournalComposerView(entry: entry)
                    .environment(\.journalManager, journalManager)
                    .environment(\.medicationManager, medicationManager)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $selectedEntry) { entry in
                JournalDetailSheet(entry: entry, onEdit: {
                    // Dismiss detail, then present the editor so the two sheets don't collide.
                    selectedEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editingEntry = entry }
                })
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: Binding(get: { entryToDelete != nil },
                                     set: { if !$0 { entryToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete { journalManager.delete(entry) }
                    entryToDelete = nil
                }
                Button("Cancel", role: .cancel) { entryToDelete = nil }
            }
        }
    }

    // MARK: - Hero header (J1)

    private var journalHeroHeader: some View {
        Text("Journal")
            .font(Theme.Fonts.hero)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, hPad)
            .padding(.top, 48)
            .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Top slot (J3)

    @ViewBuilder
    private var topSlotView: some View {
        switch topSlot {
        case .card(let entry):
            JournalTopCard(entry: entry, medicationManager: medicationManager) {
                editingEntry = entry
            }
        case .ghost:
            JournalGhostCard()
        }
    }

    // MARK: - Floating New entry pill (J8)

    private var floatingNewEntry: some View {
        ZStack(alignment: .bottom) {
            Group {
                if reduceTransparency {
                    Theme.Colors.appBackground
                } else {
                    LinearGradient(
                        colors: [Theme.Colors.appBackground.opacity(0), Theme.Colors.appBackground],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
            .frame(height: 96)
            .allowsHitTesting(false)

            ActionPill(title: "New entry", systemImage: "plus", variant: .floating) {
                showingComposer = true
            }
            .padding(.bottom, Theme.Spacing.sm)
        }
    }
}

// MARK: - Week strip (J2)

private struct JournalWeekStrip: View {
    let journalManager: JournalManager
    let medicationManager: MedicationManager
    let hPad: CGFloat
    let onSelectDay: (String) -> Void

    @State private var currentWeek: Int?

    private let cal = Calendar.current

    /// Weeks from the first dose/entry week to the current week, each seven days from the
    /// calendar's `firstWeekday`.
    private var weeks: [[Date]] {
        let today = cal.startOfDay(for: Date())
        let oldestEntry = journalManager.entries.last?.date
        let oldestDose = medicationManager.doseHistory.first?.doseDate
        let earliest = [oldestEntry, oldestDose].compactMap { $0 }.min() ?? today

        guard let firstStart = cal.dateInterval(of: .weekOfYear, for: earliest)?.start,
              let currentStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else {
            return [weekDays(from: today)]
        }

        var result: [[Date]] = []
        var start = firstStart
        while start <= currentStart && result.count < 520 {
            result.append(weekDays(from: start))
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            start = next
        }
        return result.isEmpty ? [weekDays(from: today)] : result
    }

    private func weekDays(from start: Date) -> [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var span: DateInterval {
        let days = weeks.flatMap { $0 }
        let start = days.first ?? Date()
        let end = days.last.flatMap { cal.date(byAdding: .day, value: 1, to: $0) } ?? Date()
        return DateInterval(start: start, end: max(end, start))
    }

    var body: some View {
        let pages = weeks
        let doseDays = medicationManager.doseDays(in: span)
        let entryDays = journalManager.entryDays(in: span)

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            JournalDayColumn(
                                day: day,
                                hasDose: doseDays.contains(cal.startOfDay(for: day)),
                                hasEntry: entryDays.contains(cal.startOfDay(for: day)),
                                onTap: {
                                    guard entryDays.contains(cal.startOfDay(for: day)) else { return }
                                    onSelectDay(cal.startOfDay(for: day).ISO8601Format())
                                }
                            )
                        }
                    }
                    .padding(.horizontal, hPad)
                    .containerRelativeFrame(.horizontal)
                    .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentWeek)
        .frame(height: 64)
        .padding(.vertical, Theme.Spacing.sm)
        .onAppear { currentWeek = pages.indices.last }
    }
}

private struct JournalDayColumn: View {
    let day: Date
    let hasDose: Bool
    let hasEntry: Bool
    let onTap: () -> Void

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: day))"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayNumber)
                .font(Theme.Fonts.label)
                .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle().strokeBorder(
                        isToday ? Theme.Colors.accent : .clear,
                        lineWidth: Theme.Line.hairline
                    )
                )

            HStack(spacing: 4) {
                // Dose dot: filled accent. Entry dot: hollow ink-muted. Shape differs, not
                // only color (F6).
                Circle()
                    .fill(hasDose ? Theme.Colors.accent : .clear)
                    .frame(width: 5, height: 5)
                Circle()
                    .strokeBorder(hasEntry ? Theme.Colors.textTertiary : .clear,
                                  lineWidth: Theme.Line.hairline)
                    .frame(width: 5, height: 5)
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(hasEntry ? .isButton : [])
    }

    private var accessibilityLabel: String {
        var parts = [AppDateFormatters.weekdayShortMonthDay.string(from: day)]
        if hasDose { parts.append(String(localized: "dose recorded", comment: "Week strip day accessibility: a dose was taken")) }
        if hasEntry { parts.append(String(localized: "has an entry", comment: "Week strip day accessibility: a journal entry exists")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Top card (J3, J6)

private struct JournalTopCard: View {
    let entry: JournalEntry
    let medicationManager: MedicationManager
    let onTap: () -> Void

    private var period: DayPeriod { DayPeriod(date: entry.date) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    periodTile

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(AppDateFormatters.weekday.string(from: entry.date))
                                .font(Theme.Fonts.serifTitle)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(period.word)
                                .font(Theme.Fonts.serifBody)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        Text(metaLine)
                            .font(Theme.Fonts.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                            .monoLabel()
                    }

                    Spacer(minLength: 0)
                }

                if !entry.text.isEmpty {
                    Text(entry.previewText)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                chips
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperCard(radius: Theme.Radius.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var periodTile: some View {
        Image(systemName: period.glyph)
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.accent)
            .frame(width: 36, height: 36)
            .background(Theme.Colors.accent.opacity(0.12), in: .rect(cornerRadius: Theme.Radius.sm))
    }

    /// `08:30` alone, or `08:30 · ESTRADIOL VALERATE 2.0 MG` when a dose fell that day (J6).
    private var metaLine: String {
        let time = AppDateFormatters.time.string(from: entry.date)
        if let dose = medicationManager.dose(onSameDayAs: entry.date) {
            return "\(time) · \(MedicationDisplayFormatter.doseMetaLine(for: dose))"
        }
        return time
    }

    @ViewBuilder
    private var chips: some View {
        let symptoms = entry.symptoms
        if !symptoms.isEmpty {
            FlowLayout(spacing: Theme.Spacing.tiny) {
                Pill(text: entry.mood.displayName, style: .active)
                ForEach(symptoms, id: \.id) { symptom in
                    Pill(text: symptom.name)
                }
            }
        } else {
            Pill(text: entry.mood.displayName, style: .active)
        }
    }
}

// MARK: - Ghost card (J3)

private struct JournalGhostCard: View {
    var body: some View {
        Text("Tap \"New entry\" below to write in your journal.")
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .ghostCard(radius: Theme.Radius.lg)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Day group + flush rows (J4)

private struct JournalDayGroup: View {
    let group: (key: String, date: Date, entries: [JournalEntry])
    let medicationManager: MedicationManager
    let hPad: CGFloat
    let onSelect: (JournalEntry) -> Void
    let onDelete: (JournalEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(group.date.journalDateLabel)
                .eyebrow()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, hPad)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xs)

            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                Button { onSelect(entry) } label: {
                    JournalFlushRow(entry: entry)
                        .padding(.horizontal, hPad)
                }
                .buttonStyle(.pressable)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { onDelete(entry) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if index < group.entries.count - 1 {
                    HairlineDivider(inset: hPad)
                }
            }
        }
    }
}

private struct JournalFlushRow: View {
    let entry: JournalEntry

    private var period: DayPeriod { DayPeriod(date: entry.date) }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: period.glyph)
                .font(Theme.Fonts.footnote)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 20)

            Text(entry.text.isEmpty ? entry.mood.displayName : entry.previewText)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: Theme.Spacing.sm)

            Text(AppDateFormatters.time.string(from: entry.date))
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .monoLabel()
        }
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    SpoofPreview {
        JournalView()
            .environment(\.journalManager, JournalManager.shared)
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
