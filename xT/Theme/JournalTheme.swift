//
//  JournalTheme.swift
//  xT
//
//  Mood-coded color palettes, shared layout helpers, and Date extensions
//  for the redesigned journal UI.
//

import SwiftUI

// MARK: - Mood presentation (J7)

extension Mood {
    /// The mood's display name, localized. The raw value stays the storage key; this is
    /// what the user reads on a chip. Mood never carries a valence color (X23) — coloring
    /// "sad" grey and "happy" accent is a quiet verdict the journal shouldn't pass.
    var displayName: String {
        switch self {
        case .happy:     return String(localized: "Happy", comment: "Mood name")
        case .calm:      return String(localized: "Calm", comment: "Mood name")
        case .neutral:   return String(localized: "Neutral", comment: "Mood name")
        case .tired:     return String(localized: "Tired", comment: "Mood name")
        case .anxious:   return String(localized: "Anxious", comment: "Mood name")
        case .sad:       return String(localized: "Sad", comment: "Mood name")
        case .energetic: return String(localized: "Energetic", comment: "Mood name")
        }
    }
}

// MARK: - Time of day (J5)

extension DayPeriod {
    /// SF Symbol for the period, drawn at the time-of-day glyph on cards and rows.
    var glyph: String {
        switch self {
        case .morning:   return "sunrise"
        case .afternoon: return "sun.max"
        case .evening:   return "sunset"
        case .night:     return "moon"
        }
    }

    /// Localized period word, e.g. "morning". Assembled with the day name via the
    /// `"%1$@ %2$@"` format so locales can reorder "Sunday morning" (U9).
    var word: String {
        switch self {
        case .morning:   return String(localized: "morning", comment: "Time of day")
        case .afternoon: return String(localized: "afternoon", comment: "Time of day")
        case .evening:   return String(localized: "evening", comment: "Time of day")
        case .night:     return String(localized: "night", comment: "Time of day")
        }
    }
}

// MARK: - FlowLayout (wrapping HStack for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Date helpers

extension Date {
    // These were fixed `dateFormat` patterns, which pin US field order in every
    // locale. AppDateFormatters builds them from templates instead, so a French
    // build reads "mer. 4 mars" rather than "Wed, Mar 4".
    private static let journalDateFormatter = AppDateFormatters.weekdayShortMonthDay
    private static let composerDateFormatter = AppDateFormatters.weekdayLongMonthDay

    var journalDateLabel: String {
        if Calendar.current.isDateInToday(self) {
            return String(localized: "Today", comment: "Journal day-group header for today")
        }
        if Calendar.current.isDateInYesterday(self) {
            return String(localized: "Yesterday", comment: "Journal day-group header for yesterday")
        }
        return Self.journalDateFormatter.string(from: self)
    }

    /// "wednesday, mar 4 · 9:00 am"
    ///
    /// Composed from two templated formatters rather than one fixed pattern, so
    /// each half follows the locale's own field order while the "·" separator —
    /// which is a design choice, not a date convention — stays put. The two
    /// `replacingOccurrences(of: "am", with: "am")` calls this replaces were
    /// no-ops left over from the fixed-pattern version.
    var fullDateLabel: String {
        let day = AppDateFormatters.weekdayMonthDay.string(from: self)
        let time = AppDateFormatters.time.string(from: self)
        return "\(day) · \(time)".lowercased(with: .current)
    }

    var composerDateLabel: String {
        Self.composerDateFormatter.string(from: self)
    }
}
