//
//  PhaseStripView.swift
//  xT
//
//  The phase strip under the curve (element H9). Up to four stationary text columns —
//  a weekday (or a date, for long intervals) over a positional word:
//  `MON / Dose · WED / Peak · FRI / Today · SUN / Trough`. Only the Today column is
//  dressed, with an accent hairline ring — the same motif as the Journal week strip's
//  today circle. The rest are bare muted type: they are labels, not chips.
//
//  The strip is deliberately NOT x-aligned to the chart: the visible window is ~3 days
//  while the interval can be 1–70, so aligning would be a lie (X11). Even column spacing
//  reads as a cycle summary, never an axis. It is hidden entirely for daily routes, where
//  `cyclePhaseMarkers()` returns empty, and PEAK is omitted when the ester's t_max isn't
//  calibrated — both decisions live in `cyclePhaseMarkers` (H-D2).
//

import SwiftUI

struct PhaseStripView: View {
    @Environment(\.medicationManager) private var medicationManager

    var now: Date = .now

    private var markers: [MedicationManager.PhaseMarker] {
        medicationManager.cyclePhaseMarkers(now: now)
    }

    /// Weekdays read cleanly up to a fortnight; past that the columns carry a date.
    private var usesWeekday: Bool {
        medicationManager.effectiveDueIntervalDays <= PhaseStrip.weekdayMaxIntervalDays
    }

    var body: some View {
        let markers = self.markers
        if !markers.isEmpty {
            // Stationary: two to four equal columns, never a scroll view.
            HStack(spacing: 0) {
                ForEach(markers) { marker in
                    PhaseColumn(marker: marker, usesWeekday: usesWeekday)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - One column

/// Weekday (or date) over the positional word. Today is accent with its hairline ring;
/// every other column is bare muted type.
private struct PhaseColumn: View {
    let marker: MedicationManager.PhaseMarker
    let usesWeekday: Bool

    private var isToday: Bool { marker.kind == .today }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(dayText)
                .statLabel()
                .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.textTertiary)

            Text(wordText)
                .monoLabel()
                .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.s6)
        .padding(.vertical, Theme.Spacing.xs)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .strokeBorder(Theme.Colors.accent, lineWidth: Theme.Line.hairline)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Copy

    /// "MON" style (`.statLabel` uppercases it), or "MAR 4" past a fortnight.
    private var dayText: String {
        usesWeekday
            ? AppDateFormatters.weekdayShort.string(from: marker.date)
            : AppDateFormatters.monthDay.string(from: marker.date)
    }

    /// The positional word, natural case — the mono role renders caps.
    private var wordText: String {
        switch marker.kind {
        case .dose:
            return String(localized: "Dose", comment: "Phase-strip chip: the last dose")
        case .peak:
            return String(localized: "Peak", comment: "Phase-strip chip: the modeled peak of the cycle")
        case .trough:
            return String(localized: "Trough", comment: "Phase-strip chip: the modeled trough of the cycle")
        case .today:
            return String(localized: "Today", comment: "Phase-strip chip: today")
        }
    }

    /// "Fri Mar 4, today" — one spoken label per column.
    private var accessibilityLabel: String {
        let day = AppDateFormatters.weekdayShortMonthDay.string(from: marker.date)
        return "\(day), \(wordText)"
    }
}

#if DEBUG
#Preview {
    ZStack {
        Theme.Colors.appBackground.ignoresSafeArea()
        PhaseStripView()
            .environment(\.medicationManager, MedicationManager.shared)
    }
}
#endif
