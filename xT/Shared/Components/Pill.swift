//
//  Pill.swift
//  xT
//
//  The flat, hairline-bordered chip (element S5). Used for phase-strip chips, mood
//  chips, quick tags, preset selectors, and count-down chips.
//
//  Isocline collapses the old three surface treatments (`.tinted` / `.material` /
//  `.gradient`) to two states: `.neutral` and `.active`. There is no fill — the chip
//  is a `line` hairline capsule; the active state is an **accent border**, never an
//  accent fill (spec §17). The mono `pill` role carries the text.
//

import SwiftUI

struct Pill: View {

    enum Style {
        /// Resting chip — `line` hairline, muted text.
        case neutral
        /// Selected / current chip — accent border and accent text, no fill.
        case active
    }

    let text: String
    var style: Style = .neutral

    var body: some View {
        Text(text)
            .font(Theme.Fonts.pill)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Spacing.row)
            .padding(.vertical, Theme.Spacing.tiny)
            .overlay(
                Capsule().strokeBorder(border, lineWidth: Theme.Line.hairline)
            )
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .neutral: Theme.Colors.textSecondary
        case .active:  Theme.Colors.accent
        }
    }

    private var border: Color {
        switch style {
        case .neutral: Theme.Colors.border
        case .active:  Theme.Colors.accent
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: Theme.Spacing.md) {
        Pill(text: "Within set trough")
        Pill(text: "Next dose in 2d", style: .active)
        Pill(text: "Hippocampus")
        Pill(text: "March", style: .active)
    }
    .padding(Theme.Spacing.Gutter.screen)
}
#endif
