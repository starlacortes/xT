//
//  JournalTheme.swift
//  xT
//
//  Mood-coded color palettes, shared layout helpers, and Date extensions
//  for the redesigned journal UI
//

import SwiftUI

// MARK: - Journal color palette per mood

struct JournalPalette {
    let surface: Color   // card background
    let border: Color    // card stroke
    let accent: Color    // icon, timestamp, tag text
    let title: Color     // headline + body text
    // tag: Color       // symptom tag background - removed as it always equals border
}

enum JournalTheme {
    // Primary rose accent used across composer controls
    static let rose = Theme.accentColor
    static let lavender = Theme.secondaryAccentColor

    static func palette(for mood: Mood) -> JournalPalette {
        switch mood {
        case .happy, .energetic:
            return JournalPalette(
                surface: Color(hex: "#FBEAF0"),
                border:  Color(hex: "#F4C0D1"),
                accent:  Theme.accentColor,
                title:   Color(hex: "#72243E")
            )
        case .calm, .neutral:
            return JournalPalette(
                surface: Color(hex: "#EEEDFE"),
                border:  Color(hex: "#CECBF6"),
                accent:  Theme.secondaryAccentColor,
                title:   Color(hex: "#3C3489")
            )
        case .tired, .sad, .anxious:
            return JournalPalette(
                surface: Color(hex: "#F1EFE8"),
                border:  Color(hex: "#D3D1C7"),
                accent:  Color(hex: "#5F5E5A"),
                title:   Color(hex: "#444441")
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
    /// "Today", "Yesterday", or "Mon, May 26"
    var journalDateLabel: String {
        if Calendar.current.isDateInToday(self) { return "Today" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: self)
    }

    /// "Wednesday, May 28 · 2:34 pm"
    var fullDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · h:mm a"
        return formatter.string(from: self).lowercased()
            .replacingOccurrences(of: "am", with: "am")
            .replacingOccurrences(of: "pm", with: "pm")
    }

    /// "Wednesday, May 28" for the composer header
    var composerDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: self)
    }
}

