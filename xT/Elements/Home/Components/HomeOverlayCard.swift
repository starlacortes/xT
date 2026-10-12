//
//  HomeOverlayCard.swift
//  xT
//
//  The single paper card docked above the tab bar on Home (element H10). It holds two
//  sections split by a hairline: the dose section (H11) and the latest-journal section
//  (H12). It is only as tall as its content, and it animates its height with `settle`
//  when the dose state changes (crossfade under Reduce Motion).
//
//  This retires `UnifiedStackView` and its four rows (InsightRow / MoodRow / NextDoseRow /
//  ActionBar). The "is" facts — the level, its provenance — moved up to `HomeReadout`,
//  flush on the paper; what you *adjust* (logging a dose, writing a note) lives here in the
//  card. Depth reads from the card's hairline, never a shadow.
//

import SwiftUI

struct HomeOverlayCard: View {
    @Environment(\.medicationManager) private var medicationManager
    @Environment(\.journalManager) private var journalManager
    @Environment(\.appRouter) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingComposer = false

    private var doseState: MedicationManager.DoseDayState {
        medicationManager.doseDayState()
    }

    var body: some View {
        VStack(spacing: 0) {
            doseSection
                .frame(maxWidth: .infinity, alignment: .leading)

            HairlineDivider()
                .padding(.vertical, Theme.Spacing.sm)

            journalSection
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .paperCard(radius: Theme.Radius.lg)
        .animation(reduceMotion ? nil : Theme.Motion.settle, value: doseState)
        // The record-dose sheet is owned by HomeView, raised through the router (H13/N2).
        .sheet(isPresented: $showingComposer) {
            JournalComposerView()
                .environment(\.journalManager, journalManager)
                .environment(\.medicationManager, medicationManager)
        }
    }

    // MARK: - Dose section (H11)

    @ViewBuilder
    private var doseSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(doseHeader).eyebrow()
                Spacer(minLength: Theme.Spacing.sm)
                if let chip = pastTenseChip {
                    // X14: overdue reads as a neutral past-tense chip, never red.
                    Pill(text: chip, style: .neutral)
                }
            }

            if let medLine = MedicationDisplayFormatter.medicationLine(medicationManager) {
                Text(medLine)
                    .monoLabel()
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            switch doseState {
            case .upcoming(let next):
                // One quiet line; no action — the dose isn't due yet.
                Text(upcomingValue(next))
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textPrimary)

            case .dueToday, .overdue:
                ActionPill(title: "Log Dose", systemImage: "syringe") {
                    router.presentRecordDose = true
                }

            case .unscheduled:
                // Configured but no next date yet — a gentle prompt, not an alarm.
                Text("Set a dose schedule to track your levels.")
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var doseHeader: String {
        switch doseState {
        case .upcoming:    return String(localized: "Next dose", comment: "Dose card header: a dose is coming up")
        case .dueToday:    return String(localized: "Due today", comment: "Dose card header: a dose is due today")
        case .overdue:     return String(localized: "Dose", comment: "Dose card header when a dose is overdue")
        case .unscheduled: return String(localized: "Next dose", comment: "Dose card header when no schedule is set")
        }
    }

    /// "2d ago" neutral chip for the overdue state — X14's past-tense framing.
    private var pastTenseChip: String? {
        guard case .overdue(let due) = doseState else { return nil }
        let days = max(0, Calendar.current.dateComponents([.day],
                                                          from: due, to: .now).day ?? 0)
        if days <= 0 {
            return String(localized: "Today", comment: "Overdue chip when the dose was due earlier today")
        }
        return String(localized: "\(days)d ago",
                      comment: "Overdue chip: how long ago the dose was due, e.g. '2d ago'")
    }

    /// "Fri 6:00 PM · in 2d" for an upcoming dose.
    private func upcomingValue(_ next: Date) -> String {
        let day = AppDateFormatters.weekdayShort.string(from: next)
        let time = AppDateFormatters.time.string(from: next)
        let days = max(0, Calendar.current.dateComponents([.day],
                                                          from: Calendar.current.startOfDay(for: .now),
                                                          to: Calendar.current.startOfDay(for: next)).day ?? 0)
        if days <= 0 {
            return "\(day) \(time)"
        }
        let countdown = String(localized: "in \(days)d",
                               comment: "Countdown to the next dose, e.g. 'in 2d'")
        return "\(day) \(time) · \(countdown)"
    }

    // MARK: - Journal section (H12)

    private var todayEntry: JournalEntry? {
        guard let last = journalManager.lastEntry,
              Calendar.current.isDateInToday(last.date) else { return nil }
        return last
    }

    @ViewBuilder
    private var journalSection: some View {
        Button {
            showingComposer = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: todayEntry?.mood.icon ?? "square.and.pencil")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(moodTint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(todayEntry?.mood.displayName ?? String(localized: "Add a note", comment: "Journal row placeholder title on Home"))
                        .font(Theme.Fonts.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(todayEntry?.previewText ?? String(localized: "Tap to journal", comment: "Journal row placeholder subtitle on Home"))
                        .font(Theme.Fonts.caption2)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var moodTint: Color {
        // J7: mood carries no valence color. The glyph is accent when an entry exists,
        // muted when the row is a prompt — a presence cue, not a verdict.
        todayEntry == nil ? Theme.Colors.textTertiary : Theme.Colors.accent
    }
}

#if DEBUG
#Preview {
    ZStack {
        Theme.Colors.appBackground.ignoresSafeArea()
        HomeOverlayCard()
            .environment(\.medicationManager, MedicationManager.shared)
            .environment(\.journalManager, JournalManager.shared)
            .padding()
    }
}
#endif
