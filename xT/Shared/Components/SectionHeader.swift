//
//  SectionHeader.swift
//  xT
//
//  The uppercase section eyebrow used above cards and lists.
//
//  This label was previously hand-rolled across Settings, Journal, Onboarding and the
//  Time detail screens, with sizes drifting between 9 and 13pt, three different
//  weights and five different tracking values (including one `.tracking(0.05)` typo).
//  `SectionHeader` fixes the typography so the label reads identically everywhere.
//
//  The canonical treatment is the dominant one measured at the adoption sites:
//  caption2-sized uppercase text with 0.5 tracking, tinted by `Emphasis`. The older
//  13pt semibold sheet labels and the 11pt detail-sheet labels were normalized onto it.
//

import SwiftUI

struct SectionHeader: View {

    @MainActor
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
    /// Optional leading SF Symbol — the journal detail-sheet eyebrows pair the label
    /// with an icon.
    var icon: String? = nil

    var body: some View {
        label
            .font(Theme.Fonts.caption2)
            .foregroundStyle(emphasis.color)
            .tracking(0.5)
    }

    @ViewBuilder
    private var label: some View {
        if let icon {
            Label(text.uppercased(), systemImage: icon)
        } else {
            Text(text.uppercased())
        }
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        SectionHeader(text: "Medication", emphasis: .accent)
        SectionHeader(text: "Body zones")
        SectionHeader(text: "Current level", icon: "chart.line.uptrend.xyaxis")
        SectionHeader(text: "Body systems", emphasis: .tinted(Theme.Colors.Time.body.base))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.Gutter.screen)
}
#endif
