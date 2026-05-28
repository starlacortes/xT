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
    let tag: Color       // symptom tag background
}

enum JournalTheme {
    // Primary rose accent used across composer controls
    static let rose = Color(hex: "#D4537E")
    static let lavender = Color(hex: "#534AB7")

    static func palette(for mood: Mood) -> JournalPalette {
        switch mood {
        case .happy, .energetic:
            return JournalPalette(
                surface: Color(hex: "#FBEAF0"),
                border:  Color(hex: "#F4C0D1"),
                accent:  Color(hex: "#D4537E"),
                title:   Color(hex: "#72243E"),
                tag:     Color(hex: "#F4C0D1")
            )
        case .neutral:
            return JournalPalette(
                surface: Color(hex: "#EEEDFE"),
                border:  Color(hex: "#CECBF6"),
                accent:  Color(hex: "#534AB7"),
                title:   Color(hex: "#3C3489"),
                tag:     Color(hex: "#CECBF6")
            )
        case .sad, .anxious:
            return JournalPalette(
                surface: Color(hex: "#F1EFE8"),
                border:  Color(hex: "#D3D1C7"),
                accent:  Color(hex: "#5F5E5A"),
                title:   Color(hex: "#444441"),
                tag:     Color(hex: "#D3D1C7")
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

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}