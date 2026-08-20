//
//  JournalTheme.swift
//  xT
//
//  Mood-coded color palettes, shared layout helpers, and Date extensions
//  for the redesigned journal UI.
//

import SwiftUI

// MARK: - Journal color palette per mood

struct JournalPalette {
    let surface: Color   // card background
    let border: Color    // card stroke
    let accent: Color    // icon, timestamp, tag text
    let title: Color     // headline + body text
}

@MainActor
enum JournalTheme {
    static func palette(for mood: Mood) -> JournalPalette {
        switch mood {
        case .happy, .energetic:
            // Surface/border/title mirror Theme.Colors.Time.cycle exactly (were
            // independently duplicated hex before) — deriving from it keeps
            // Journal mood colors in sync as the theme rotates instead of
            // silently freezing at today's hues.
            return JournalPalette(
                surface: Theme.Colors.Time.cycle.surface,
                border:  Theme.Colors.Time.cycle.border,
                accent:  Theme.Colors.accent,
                title:   Theme.Colors.Time.cycle.text
            )
        case .calm, .neutral:
            return JournalPalette(
                surface: Theme.Colors.Time.mind.surface,
                border:  Theme.Colors.Time.mind.border,
                accent:  Theme.Colors.accentSecondary,
                title:   Theme.Colors.Time.mind.text
            )
        case .tired, .sad, .anxious:
            return JournalPalette(
                surface: Color(lightHex: "#F1EFE8", darkHex: "#1E1D18"),
                border:  Color(lightHex: "#D3D1C7", darkHex: "#4A4840"),
                accent:  Color(lightHex: "#5F5E5A", darkHex: "#A8A7A2"),
                title:   Color(lightHex: "#444441", darkHex: "#C8C7C2")
            )
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
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
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
