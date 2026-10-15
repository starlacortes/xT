//
//  PhaseStripView.swift
//  xT
//
//  The phase strip under the curve (element H9). Up to four stationary text columns —
//  one positional word each: `DOSE · PEAK · TODAY · TROUGH`. Only the Today column is
//  dressed, with an accent hairline ring — the same motif as the Journal week strip's
//  today circle. The rest are bare muted type: they are labels, not chips.
//
//  The calendar lives on the chart itself: FlatGraphView labels the day-boundary
//  gridlines, aligned to the actual days on the curve. The strip is deliberately NOT
//  x-aligned to the chart — the visible window is ~3 days while the interval can be
//  1–70, so aligning would be a lie (X11). Even column spacing reads as a cycle
//  summary, never an axis. It is hidden entirely for daily routes, where
//  `cyclePhaseMarkers()` returns empty, and PEAK is omitted when the ester's t_max
//  isn't calibrated — both decisions live in `cyclePhaseMarkers` (H-D2).
//

import SwiftUI

struct PhaseStripView: View {
    @Environment(\.medicationManager) private var medicationManager

    var now: Date = .now

    private var markers: [MedicationManager.PhaseMarker] {
        medicationManager.cyclePhaseMarkers(now: now)
    }

    var body: some View {
        let markers = self.markers
        if !markers.isEmpty {
            // Stationary: two to four equal columns, never a scroll view.
            HStack(spacing: 0) {
                ForEach(markers) { marker in
                    PhaseColumn(marker: marker)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - One column

/// The positional word alone — the day labels live on the chart's time axis, under
/// the day-boundary gridlines. Today is accent with its hairline ring; every other
/// column is bare muted type.
private struct PhaseColumn: View {
    let marker: MedicationManager.PhaseMarker

    private var isToday: Bool { marker.kind == .today }

    var body: some View {
        Text(wordText)
            .monoLabel()
            .foregroundStyle(isToday ? Theme.Colors.accent : Theme.Colors.textSecondary)
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
