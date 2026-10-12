//
//  Theme+IsoclineSurfaces.swift
//  xT
//
//  Isocline "Paper & Instrument" — the surface primitives (Tier 2 · elements S1, S2).
//
//  Spec §07 names four surfaces: flush (no modifier), paper card, emboss, and glass
//  (system chrome only). This file implements the two card surfaces that content
//  composes from. The rule: depth on paper reads from a hairline, never a shadow.
//
//    • paperCard — opaque raised-paper card, read by its hairline (S1)
//    • ghostCard — same shape + hairline, no fill, not a control (S2)
//    • paperList — the pushed List/Form treatment (S1 · ST6)
//
//  All three draw the border in the `line` ink-alpha (`Theme.Colors.border`) at
//  `Theme.Line.hairline`, and use `strokeBorder` so the stroke stays inside the
//  rounded rect rather than straddling the edge.
//

import SwiftUI

// MARK: - Paper card (S1)

/// Opaque raised-paper card: `card` fill + a `line` hairline, no shadow. Replaces the
/// retired `asGlassCard` / `timeCard` / `settingsCard` surfaces and the hand-written
/// cards across Settings. Padding defaults to `.card` (14), radius to `.lg` (20).
struct PaperCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.card
    var radius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
            )
    }
}

// MARK: - Ghost card (S2)

/// Same shape + hairline as `paperCard` but with **no fill** — an outlined slot, not a
/// control and not a tap target. Used for the Journal ghost slot (J3), the composer
/// text area (J9), and engraved empty states (H15).
struct GhostCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.card
    var radius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.Colors.border, lineWidth: Theme.Line.hairline)
            )
    }
}

// MARK: - View extensions

extension View {
    /// Wrap this content in an opaque paper card (S1). See `PaperCardModifier`.
    func paperCard(padding: CGFloat = Theme.Spacing.card, radius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(PaperCardModifier(padding: padding, radius: radius))
    }

    /// Wrap this content in an outlined ghost card — hairline, no fill (S2).
    func ghostCard(padding: CGFloat = Theme.Spacing.card, radius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(GhostCardModifier(padding: padding, radius: radius))
    }

    /// The Isocline treatment for a pushed `List` / `Form` (S1 · ST6): paper ground,
    /// card row fills, `line` separators. Apply to the `List`/`Form` itself.
    func paperList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.appBackground)
            .listRowBackground(Theme.Colors.cardSurface)
            .listRowSeparatorTint(Theme.Colors.border)
    }
}
