//
//  PhaseStripView.swift
//  xT
//
//  The phase strip under the curve (element H9). Four mono chips — DOSE, PEAK, TODAY,
//  TROUGH — each prefixed with a weekday (or a date, for long intervals). Today's chip
//  carries the accent hairline ring; the rest are neutral.
//
//  The strip is deliberately NOT x-aligned to the chart: the visible window is ~3 days
//  while the interval can be 1–70, so aligning would be a lie (X11). It is hidden entirely
//  for daily routes, where `cyclePhaseMarkers()` returns empty, and PEAK is omitted when
//  the ester's t_max isn't calibrated — both decisions live in `cyclePhaseMarkers` (H-D2).
//

import SwiftUI

struct PhaseStripView: View {
    @Environment(\.medicationManager) private var medicationManager

    var now: Date = .now

    private var markers: [MedicationManager.PhaseMarker] {
        medicationManager.cyclePhaseMarkers(now: now)
    }

    /// Weekdays read cleanly up to a fortnight; past that the chips carry a date.
    private var usesWeekday: Bool {
        medicationManager.effectiveDueIntervalDays <= PhaseStrip.weekdayMaxIntervalDays
    }

    var body: some View {
        let markers = self.markers
        if !markers.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(markers) { marker in
                        Pill(text: label(for: marker),
                             style: marker.kind == .today ? .active : .neutral)
                    }
                }
                .padding(.horizontal, Theme.Spacing.tiny)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Labels

    /// "WED · PEAK" style: a date prefix then the positional word. The `Pill` renders mono
    /// caps, so the words here are natural case.
    private func label(for marker: MedicationManager.PhaseMarker) -> String {
        let prefix = usesWeekday
            ? AppDateFormatters.weekdayShort.string(from: marker.date)
            : AppDateFormatters.monthDay.string(from: marker.date)
        return "\(prefix) \(word(for: marker.kind))"
    }

    private func word(for kind: MedicationManager.PhaseMarker.Kind) -> String {
        switch kind {
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
