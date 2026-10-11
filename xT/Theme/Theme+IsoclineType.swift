//
//  Theme+IsoclineType.swift
//  xT
//
//  Isocline "Paper & Instrument" — the type system (Tier 1 · element F2).
//
//  `Theme.FontFace` names the six bundled OFL faces by their real PostScript name
//  (see xT/Resources/Fonts/README.md). `Theme.Fonts` (in Theme.swift) builds every
//  role from these via `Font.custom(_:size:relativeTo:)` so each role scales with
//  Dynamic Type. The view modifiers below carry what a `Font` can't: letter-tracking,
//  case, the mono-label no-wrap rule, and the Bold-Text face swap.
//

import SwiftUI

extension Theme {

    // MARK: Font faces (tokens: type.families)

    /// The six bundled faces, by PostScript name. `Font.custom` resolves by PS name,
    /// not filename — note IBM Plex Mono's are `IBMPlexMono` (Regular) and
    /// `IBMPlexMono-Medm` (Medium), abbreviated in the font itself.
    /// `xTTests/FontRegistrationTests` asserts every case resolves to a real face.
    enum FontFace: CaseIterable {
        case serifSemibold   // IBM Plex Serif 600 — display
        case serifBold       // IBM Plex Serif 700 — display
        case mono            // IBM Plex Mono 400 — mono
        case monoMedium      // IBM Plex Mono 500 — mono
        case prose           // Atkinson Hyperlegible Next 400 — prose
        case proseBold       // Atkinson Hyperlegible Next 700 — prose

        var postScriptName: String {
            switch self {
            case .serifSemibold: "IBMPlexSerif-SemiBold"
            case .serifBold:     "IBMPlexSerif-Bold"
            case .mono:          "IBMPlexMono"
            case .monoMedium:    "IBMPlexMono-Medm"
            case .prose:         "AtkinsonHyperlegibleNext-Regular"
            case .proseBold:     "AtkinsonHyperlegibleNext-Bold"
            }
        }

        /// A Dynamic-Type-aware font in this face.
        func sized(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
            Font.custom(postScriptName, size: size, relativeTo: style)
        }
    }
}

// MARK: - Supporting view modifiers (spec §2.4)

/// Section eyebrow / page eyebrow — mono 11, uppercased, tracked, muted, one line.
/// Case is applied with `.textCase` (not `.uppercased()`) so translations keep their
/// own casing (localization rule, element S6).
private struct EyebrowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.eyebrow)
            .textCase(.uppercase)
            .tracking(11 * 0.18)
            .foregroundStyle(Theme.Colors.textSecondary)
            .lineLimit(1)
    }
}

/// Fine-print stat label — mono 9, uppercased, tracked. Gridline values, provenance.
private struct StatLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.statLabel)
            .textCase(.uppercase)
            .tracking(9 * 0.14)
    }
}

/// The mono-label no-wrap rule: never break a mono label mid-word (the canonical
/// "HOM/E" bug). One line, shrink to 80% before truncating.
private struct MonoLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.label)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// Bold-Text accessibility: when the system Bold Text setting is on, swap the prose
/// body up to Atkinson Bold and mono up to Mono Medium. Apply to body/mono roles.
struct ThemedFont: ViewModifier {
    @Environment(\.legibilityWeight) private var legibilityWeight

    enum Role { case body, mono }
    let role: Role

    func body(content: Content) -> some View {
        content.font(resolved)
    }

    private var resolved: Font {
        let bold = legibilityWeight == .bold
        switch role {
        case .body:
            return bold ? Theme.FontFace.proseBold.sized(17, relativeTo: .body)
                        : Theme.Fonts.body
        case .mono:
            return bold ? Theme.FontFace.monoMedium.sized(12, relativeTo: .caption)
                        : Theme.Fonts.label
        }
    }
}

extension View {
    /// Section / page eyebrow (mono caps, tracked, muted, one line). Spec §18.
    func eyebrow() -> some View { modifier(EyebrowModifier()) }

    /// Fine-print stat label (mono caps, tracked). Spec §2.4.
    func statLabel() -> some View { modifier(StatLabelModifier()) }

    /// Mono label with the no-wrap rule (one line, min scale 0.8). Spec §2.4.
    func monoLabel() -> some View { modifier(MonoLabelModifier()) }

    /// Bold-Text-aware body or mono font. Spec §2.4.
    func themedFont(_ role: ThemedFont.Role) -> some View { modifier(ThemedFont(role: role)) }
}
