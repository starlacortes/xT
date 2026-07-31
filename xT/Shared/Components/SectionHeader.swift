//
//  SectionHeader.swift
//  xT
//
//  The uppercase section eyebrow used above cards and lists.
//
//  This label was previously hand-rolled in 26 places across Settings, Home, Journal
//  and the Time detail screens, with sizes drifting between 9 and 13pt, three different
//  weights and five different tracking values. `SectionHeader` fixes the typography so
//  the label reads identically everywhere.
//

import SwiftUI

struct SectionHeader: View {

    enum Emphasis {
        /// Small accent-colored eyebrow directly above a card group. The Settings default.
        case accent
        /// Neutral secondary label — for groups that shouldn't compete with content.
        case secondary
        /// Tinted to a Time category or other contextual color.
        case tinted(Color)

        var color: Color {
            switch self {
            case .accent:            return Theme.Colors.accent
            case .secondary:         return Theme.Colors.textSecondary
            case .tinted(let color): return color
            }
        }
    }

    let text: String
    var emphasis: Emphasis = .secondary

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Fonts.eyebrow)
            .foregroundStyle(emphasis.color)
            .tracking(0.5)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        SectionHeader(text: "Medication", emphasis: .accent)
        SectionHeader(text: "Body zones")
        SectionHeader(text: "Body systems", emphasis: .tinted(Theme.Colors.Time.body.base))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.Gutter.screen)
}
