//
//  SectionHeader.swift
//  xT
//
//  The uppercase section eyebrow used above cards and lists (element S6).
//
//  This label was previously hand-rolled across Settings, Journal, Onboarding and the
//  Time detail screens, with sizes drifting between 9 and 13pt, three different
//  weights and five different tracking values (including one `.tracking(0.05)` typo).
//  `SectionHeader` fixes the typography so the label reads identically everywhere.
//
//  Tier 4d (S6): the text parameter is a `LocalizedStringResource` (X31) and the
//  casing is applied with `.textCase(.uppercase)`, so translations keep their
//  own casing. An optional serif title renders beneath the eyebrow.
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

    let text: LocalizedStringResource
    var emphasis: Emphasis = .secondary
    /// Optional serif title rendered beneath the eyebrow.
    var serifTitle: LocalizedStringResource? = nil
    /// Optional leading SF Symbol — the journal detail-sheet eyebrows pair the label
    /// with an icon.
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            // The `.eyebrow()` modifier carries font + case + tracking; only the
            // color is per-`Emphasis`, so it's re-applied after.
            label
                .eyebrow()
                .foregroundStyle(emphasis.color)
            if let serifTitle {
                Text(serifTitle)
                    .font(Theme.Fonts.serifTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if let icon {
            Label(text, systemImage: icon)
        } else {
            Text(text)
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
        SectionHeader(text: "Your range", serifTitle: "Reference")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Theme.Spacing.Gutter.screen)
}
#endif
