//
//  HomeConstants.swift
//  xT
//
//  Named behavioral constants for the Home instrument and its supports (element
//  H-D0). These are *product behavior*, not visual tokens: how far back a lab is
//  "recent", when the phase strip switches from weekday labels to dates, when a
//  schedule is old enough to offer an adjustment. They live here so the code and the
//  tests reference a name, never a bare literal.
//
//  Safety thresholds are deliberately absent — `SafetyFlag` and `PKConstants` in
//  `PharmacokineticConstants.swift` are their only source.
//

import Foundation

/// Phase-strip thresholds (H-D2, H9).
enum PhaseStrip {
    /// At or below this dosing interval the strip labels chips by weekday
    /// (`MON Dose · WED Peak`); above it, by date (`MAR 4 Dose · APR 2 Peak`).
    static let weekdayMaxIntervalDays = 14

    /// Below this interval the strip is not produced at all — daily routes have no
    /// cycle to chart (X11).
    static let minIntervalDays = 2
}

/// Provenance line age bucketing (H-D3).
///
/// A lab's age is reported in the coarsest unit that still reads as recent:
/// days under `daysMaxExclusive`, then weeks under `weeksMaxExclusive`, then months.
enum Provenance {
    static let daysMaxExclusive = 14
    static let weeksMaxExclusive = 60
}

/// Dose-section behavior for the overlay card (H11).
enum DoseSection {
    /// Days past the due date after which the overdue card offers to adjust the
    /// schedule. Was a bare `3` in `NextDoseRowView`.
    static let adjustScheduleAfterDays = 3

    /// How often the live countdown chip re-renders. `refreshState()` is not
    /// time-driven, so the chip wraps a `TimelineView` on this cadence.
    static let countdownRefresh: TimeInterval = 60
}

/// Home layout behavior (H1).
enum HomeLayout {
    /// Fraction of the scroll height the curve keeps when Dynamic Type reaches an
    /// accessibility size and the layout switches to a scrolling arrangement.
    static let accessibilityCurveFraction = 0.4
}

/// Time of day a timestamp falls in, by the hour ranges in H-D0 (J5).
///
/// morning 5–11 · afternoon 12–16 · evening 17–20 · night 21–4.
enum DayPeriod: Equatable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    /// Classifies an hour-of-day (0–23) into its period. Night wraps midnight, so it
    /// covers both the late evening (21–23) and the small hours (0–4).
    init(hour: Int) {
        switch hour {
        case 5...11:  self = .morning
        case 12...16: self = .afternoon
        case 17...20: self = .evening
        default:      self = .night   // 21–23 and 0–4
        }
    }

    /// Classifies a date by its local hour.
    init(date: Date, calendar: Calendar = .current) {
        self.init(hour: calendar.component(.hour, from: date))
    }
}
