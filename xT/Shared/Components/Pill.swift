//
//  Pill.swift
//  xT
//
//  A small capsule-shaped label.
//
//  Five near-identical capsules existed across the app — the level-overlay range pill,
//  the missed-days badge, the constellation region tag, the journal scrubber chip and the
//  journal detail tags. They shared a shape and metrics but each re-derived its own fill
//  and stroke. `Pill` keeps the three genuinely different surface treatments as `Style`.
//

import SwiftUI

struct Pill: View {

    enum Style {
        /// Tinted fill with a matching hairline stroke — status and range pills.
        case tinted(Color)
        /// Translucent material with a soft shadow — labels floating over artwork.
        case material(Color)
        /// Brand gradient with knocked-out text — the selected state of a chip row.
        case gradient
    }

    let text: String
    var style: Style = .tinted(Theme.Colors.accent)

    var body: some View {
        Text(text)
            .font(Theme.Fonts.pill)
            .foregroundStyle(foreground)
            .padding(.horizontal, Theme.Spacing.row)
            .padding(.vertical, Theme.Spacing.tiny)
            .background(background)
            .overlay(strokeOverlay)
            .clipShape(Capsule())
    }

    // MARK: - Style resolution

    private var foreground: Color {
        switch style {
        case .tinted(let tint):   return tint
        case .material(let tint): return tint
        case .gradient:           return Theme.Colors.OnAccent.primary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .tinted(let tint):
            Capsule().fill(tint.opacity(0.15))
        case .material:
            Capsule().fill(.ultraThinMaterial)
        case .gradient:
            Capsule().fill(Theme.Gradients.brand)
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        switch style {
        case .tinted(let tint):
            Capsule().stroke(tint.opacity(0.3), lineWidth: Theme.Colors.hairlineWidth)
        case .material(let tint):
            Capsule().stroke(tint.opacity(0.25), lineWidth: Theme.Colors.hairlineWidth)
        case .gradient:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        Pill(text: "optimal", style: .tinted(Theme.Colors.success))
        Pill(text: "3 days late", style: .tinted(Theme.Colors.error))
        Pill(text: "Hippocampus", style: .material(Theme.Colors.Time.mind.text))
        Pill(text: "March", style: .gradient)
    }
    .padding(Theme.Spacing.Gutter.screen)
}
