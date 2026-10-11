//
//  Theme.swift
//  xT
//
//  Central design-token system. All color, font, spacing, radius,
//  and gradient constants live here.
//

import SwiftUI

// MARK: - Design tokens

struct Theme {

    // MARK: Colors

    @MainActor
    struct Colors {
        // Brand — every color below is derived from the user's chosen theme hue
        // (`ThemeManager.shared.seedHue`) via `ThemePalette`, cached and
        // recomputed once per hue change, not per token access. See
        // `ThemeManager.swift` for the recipe table and contrast-repair passes.
        static var accent: Color           { ThemeManager.shared.palette.accent }
        static var accentSecondary: Color  { ThemeManager.shared.palette.accentSecondary }

        // Text
        static var textPrimary: Color   { ThemeManager.shared.palette.textPrimary }
        static var textSecondary: Color { ThemeManager.shared.palette.textSecondary }
        static var textTertiary: Color  { ThemeManager.shared.palette.textTertiary }

        // Surfaces
        static var cardSurface: Color   { ThemeManager.shared.palette.cardSurface }
        static var border: Color        { ThemeManager.shared.palette.border }
        /// Opaque screen canvas — use instead of raw `Color(.systemBackground)`.
        static var appBackground: Color { ThemeManager.shared.palette.appBackground }
        /// Opaque icon-tile fill — use instead of raw `Color(.systemGray6)`.
        static var neutralSurface: Color { ThemeManager.shared.palette.neutralSurface }

        // Glass tint — deep purple-black in dark mode, subtle white in light mode
        static var glassTint: Color { ThemeManager.shared.palette.glassTint }

        // Semantic — deliberately NOT theme-driven. These carry meaning
        // independent of brand styling. `error`/`safety` is the documented clinical
        // red (decision X10): a fixed, never-themed hue (absolute 27°), contrast-
        // repaired against paper. The accessor name is kept so existing callers
        // (`HormoneLevelPresentation.statusTint`, `PharmacokineticTests`) still hold.
        static let success          = Color.green
        static let warning          = Color.orange
        static var error: Color     { ThemeManager.shared.palette.safety }
        /// Alias for `error` — the Isocline name for the clinical-safety red.
        static var safety: Color    { ThemeManager.shared.palette.safety }
        static let successBrand     = Color(lightHex: "#3B8C6E", darkHex: "#64DC9E")

        // Graph level ramp — deep rose (low) → light lavender (high)
        static var levelLow: Color  { ThemeManager.shared.palette.levelLow }
        static var levelHigh: Color { ThemeManager.shared.palette.levelHigh }

        // Graph background — adaptive canvas rendering constants
        @MainActor
        struct Graph {
            static var baseDark: Color          { ThemeManager.shared.palette.graph.baseDark }
            static var baseMid: Color           { ThemeManager.shared.palette.graph.baseMid }
            static var baseTop: Color           { ThemeManager.shared.palette.graph.baseTop }
            static var topGlow: Color           { ThemeManager.shared.palette.graph.topGlow }
            static var rightGlow: Color         { ThemeManager.shared.palette.graph.rightGlow }
            static var gridLine: Color          { ThemeManager.shared.palette.graph.gridLine }
            static var yAxisLabel: Color        { ThemeManager.shared.palette.graph.yAxisLabel }
            static var curveRose: Color         { ThemeManager.shared.palette.graph.curveRose }
            static var curveMid: Color          { ThemeManager.shared.palette.graph.curveMid }
            static var curveLavender: Color     { ThemeManager.shared.palette.graph.curveLavender }
            static var dotRose: Color           { ThemeManager.shared.palette.graph.dotRose }
            static var dotMagenta: Color        { ThemeManager.shared.palette.graph.dotMagenta }
            static var dotPurple: Color         { ThemeManager.shared.palette.graph.dotPurple }
            static var dotDeepPurple: Color     { ThemeManager.shared.palette.graph.dotDeepPurple }
            static var dotLavenderLight: Color  { ThemeManager.shared.palette.graph.dotLavenderLight }

            // Level overlay text (adaptive)
            static var levelText: Color          { ThemeManager.shared.palette.graph.levelText }
            static var levelTextSecondary: Color { ThemeManager.shared.palette.graph.levelTextSecondary }

            // Unfilled dot track color (adaptive)
            static var dotUnfilled: Color       { ThemeManager.shared.palette.graph.dotUnfilled }
        }

        // MARK: Time category palettes

        struct TimePalette {
            let base: Color     // icon / progress fill
            let surface: Color  // card background
            let border: Color   // card stroke
            let text: Color     // on-surface text / emphasis, readable on `surface`
        }

        @MainActor
        struct Time {
            static var mind: TimePalette  { ThemeManager.shared.palette.time.mind }
            static var skin: TimePalette  { ThemeManager.shared.palette.time.skin }
            static var body: TimePalette  { ThemeManager.shared.palette.time.body }
            static var cycle: TimePalette { ThemeManager.shared.palette.time.cycle }
        }

        // MARK: On-accent

        /// Text and fills that sit on top of the brand gradient or an accent surface —
        /// the Onboarding flow and the app-lock screens. Replaces the raw
        /// `.white.opacity(_:)` literals that previously used six different alphas
        /// for the same semantic role.
        @MainActor
        struct OnAccent {
            static var primary: Color        { ThemeManager.shared.palette.onAccent.primary }
            static var secondary: Color      { ThemeManager.shared.palette.onAccent.secondary }
            static var tertiary: Color       { ThemeManager.shared.palette.onAccent.tertiary }
            static var disabled: Color       { ThemeManager.shared.palette.onAccent.disabled }
            static var fill: Color           { ThemeManager.shared.palette.onAccent.fill }  // chip / control backgrounds
            static var stroke: Color         { ThemeManager.shared.palette.onAccent.stroke }  // chip borders
            static var strokeSelected: Color { ThemeManager.shared.palette.onAccent.strokeSelected }
        }

        /// The de facto hairline stroke width used across the app (27 sites).
        static let hairlineWidth: CGFloat = 0.5
    }

    // MARK: Fonts

    struct Fonts {
        // Isocline Paper & Instrument type (element F2). Every role is built from a
        // bundled OFL face via `Theme.FontFace.sized(_:relativeTo:)`, so it scales with
        // Dynamic Type. Family/weight/size/relativeTo mirror tokens' type.roles & aliases.
        // `Theme.FontFace` and the .eyebrow()/.monoLabel()/.statLabel() modifiers live
        // in Theme+IsoclineType.swift.
        private typealias Face = Theme.FontFace

        // MARK: Role scale (tokens: type.roles)

        /// Reserved display serif. (serif 700 · 64)
        static let display      = Face.serifBold.sized(64, relativeTo: .largeTitle)
        /// Home level readout. (mono 500 · 52)
        static let readout      = Face.monoMedium.sized(52, relativeTo: .largeTitle)
        /// Record figures. (mono 500 · 48)
        static let largeNumber  = Face.monoMedium.sized(48, relativeTo: .largeTitle)
        /// Screen titles — Journal, Settings, Time hero. (serif 700 · 34)
        static let hero         = Face.serifBold.sized(34, relativeTo: .largeTitle)
        /// Secondary figures. (mono 500 · 32)
        static let numeric      = Face.monoMedium.sized(32, relativeTo: .title)
        /// Section titles, profile name, sheet titles. (serif 600 · 22)
        static let serifTitle   = Face.serifSemibold.sized(22, relativeTo: .title2)
        /// Journal prose, body copy. (prose 400 · 17)
        static let body         = Face.prose.sized(17, relativeTo: .body)
        /// Journal day labels, dose-section time. (serif 600 · 17)
        static let serifBody    = Face.serifSemibold.sized(17, relativeTo: .body)
        /// Subtitles, captions. (prose 400 · 13)
        static let detail       = Face.prose.sized(13, relativeTo: .footnote)
        /// Meta lines, provenance, countdown chips. (mono 500 · 12)
        static let label        = Face.monoMedium.sized(12, relativeTo: .caption)
        /// Section-header eyebrow. Use the `.eyebrow()` modifier for tracking+case+muted.
        /// (mono 500 · 11)
        static let eyebrow      = Face.monoMedium.sized(11, relativeTo: .caption2)
        /// Chip label. (mono 500 · 11)
        static let pill         = Face.monoMedium.sized(11, relativeTo: .caption2)
        /// Gridline values, fine-print stat labels. Use `.statLabel()` for tracking+case.
        /// (mono 400 · 9)
        static let statLabel    = Face.mono.sized(9, relativeTo: .caption2)
        /// Small print. (mono 400 · 10)
        static let micro        = Face.mono.sized(10, relativeTo: .caption2)
        /// Stat values. (mono 500 · 18)
        static let statValue    = Face.monoMedium.sized(18, relativeTo: .headline)

        /// Leading SF Symbol in a list row — stays a system font for symbol sizing.
        static let icon         = Font.system(size: 18)

        // MARK: Text-style aliases (tokens: type.aliases)
        //
        // The 11 standard text-style names, re-pointed at the Isocline families so the
        // existing `.font(.<style>)` call sites shift all at once as they migrate to
        // `Theme.Fonts.<style>` (element F2 / X2). Each is relativeTo its own style.

        static let largeTitle   = Face.serifSemibold.sized(34, relativeTo: .largeTitle)
        static let title        = Face.serifSemibold.sized(28, relativeTo: .title)
        static let title2       = Face.serifSemibold.sized(22, relativeTo: .title2)
        static let title3       = Face.serifSemibold.sized(20, relativeTo: .title3)
        static let headline     = Face.proseBold.sized(17, relativeTo: .headline)
        static let callout      = Face.prose.sized(16, relativeTo: .callout)
        static let subheadline  = Face.prose.sized(15, relativeTo: .subheadline)
        static let footnote     = Face.prose.sized(13, relativeTo: .footnote)
        static let caption      = Face.prose.sized(12, relativeTo: .caption)
        static let caption2     = Face.prose.sized(11, relativeTo: .caption2)
    }

    // MARK: Spacing

    struct Spacing {
        static let xs: CGFloat      = 4
        static let sm: CGFloat      = 8
        static let md: CGFloat      = 12
        static let lg: CGFloat      = 16
        static let xl: CGFloat      = 20
        static let xxl: CGFloat     = 24
        static let card: CGFloat    = 14  // dominant card content padding

        // Added from the measured spacing histogram.
        static let xxs: CGFloat     = 2   // 29 stack + 8 padding sites
        static let tiny: CGFloat    = 6   // 29 stack + 8 padding sites
        static let row: CGFloat     = 10  // 19 stack + 10 padding sites
        static let section: CGFloat = 28  // 5 stack + 3 padding sites
        static let jumbo: CGFloat   = 32  // 4 stack + 9 padding sites

        /// Horizontal page gutters. Previously three competing literals (40 / 22 / 20)
        /// applied inconsistently; Home, Settings, Journal and the dose sheet now share
        /// one `screen` value and only Onboarding keeps its wider gradient inset.
        struct Gutter {
            static let screen: CGFloat     = 22
            static let onboarding: CGFloat = 40
        }
    }

    // MARK: Radius

    struct Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24

        // Added from the measured corner-radius histogram.
        static let hairline: CGFloat = 2   // dot tracks / progress rails (7 sites)
        static let xs: CGFloat       = 4   // mini chips, progress bars (2 sites)
        static let chip: CGFloat     = 6   // most common raw radius (12 sites)
        static let control: CGFloat  = 8   // icon tiles, small buttons (6 sites)
        static let tile: CGFloat     = 10  // stat tiles (9 sites)
    }

    // MARK: Gradients

    @MainActor
    struct Gradients {
        // Canonical brand colors — single source of truth for the rose→lavender sweep.
        static var brandColors: [Color] { ThemeManager.shared.palette.brandColors }

        static var brand: LinearGradient {
            LinearGradient(
                colors: brandColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Motion

    /// Shared animation curves so motion feels consistent across the app.
    struct Motion {
        // Legacy curves — kept for existing callers. Prefer the spring-based
        // presets below for new code (WWDC23 recommendation: spring(duration:bounce:)).
        /// Gentle spring for entrances and layout settling.
        static let entrance = Animation.spring(response: 0.55, dampingFraction: 0.82)
        /// Quick, lively spring for taps and toggles.
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.7)
        /// Smooth ease for value changes (counters, opacity, color).
        static let smooth = Animation.easeInOut(duration: 0.4)
        /// Per-card delay used to stagger a vertical stack on appear.
        static let stagger: Double = 0.07

        // Added from the measured duration histogram, which had 12 distinct raw values
        // clustering into four bands plus a repeating pulse.

        /// Near-immediate feedback — field focus, inline toggles. (0.08–0.15 → 8 sites)
        static let instant  = Animation.easeInOut(duration: 0.15)
        /// Standard tap / selection response. (0.2–0.25 → 13 sites)
        static let quick    = Animation.easeInOut(duration: 0.22)
        /// Section expand / collapse. (0.3 → 6 sites)
        static let standard = Animation.easeInOut(duration: 0.3)
        /// Slow reveal for charts and rings drawing themselves in. (1.0–1.5 → 4 sites)
        static let reveal   = Animation.easeOut(duration: 1.0)
        /// Continuous attention pulse — the "dose due" indicator. (2 sites)
        static let pulse    = Animation.easeInOut(duration: 1.3).repeatForever(autoreverses: true)

        // MARK: Spring-based presets (iOS 17+, WWDC23 recommended)
        //
        // Apple recommends spring(duration:bounce:) over the older
        // spring(response:dampingFraction:) API. Bounce values:
        //   0.0   = critically damped — smooth settle, no overshoot
        //   0.15  = subtle playfulness, slightly brisk tail
        //   0.30  = noticeable bounce, feels physical
        //   >0.4  = exaggerated — use sparingly
        //
        // Ref: WWDC23 "Animate with springs"

        /// Cards and sections settling into place on first appear.
        /// Smooth, no bounce — feels like a gentle deceleration.
        static let settle = Animation.spring(duration: 0.55, bounce: 0.0)
        /// Lightly playful pop for interactive elements (buttons, selection).
        static let pop    = Animation.spring(duration: 0.35, bounce: 0.15)
        /// Gentle attention-grab — noticeable but not jarring. Good for
        /// overlays and callouts that should feel warm, not aggressive.
        static let gentle = Animation.spring(duration: 0.45, bounce: 0.08)
        /// Tactile press-down — tighter, lower bounce than pop.
        static let tap    = Animation.spring(duration: 0.25, bounce: 0.05)
        /// Celebration scatter — higher bounce for festive particle bursts.
        static let burst  = Animation.spring(duration: 0.6, bounce: 0.28)
    }

}

// MARK: - View Modifiers

/// Translucent glass card — for Home cards and any surface floating over a gradient.
/// Uses iOS 26 Liquid Glass on iOS 26+, falls back to ultraThinMaterial on older iOS.
struct GlassCardModifier: ViewModifier {
    var tint: Color = Theme.Colors.glassTint
    var tintOpacity: CGFloat = 0.55
    var cornerRadius: CGFloat = Theme.Radius.lg

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(tintOpacity)), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Theme.Colors.border, lineWidth: 0.5)
                )
        }
    }
}

/// Opaque pastel card — for Time category cards and Journal mood cards.
struct TimeCardModifier: ViewModifier {
    let palette: Theme.Colors.TimePalette

    func body(content: Content) -> some View {
        content
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(palette.border.opacity(0.6), lineWidth: 0.5)
            )
    }
}

/// Full-width accent action button.
struct AccentButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.accent)
            .foregroundStyle(Theme.Colors.OnAccent.primary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }
}

// MARK: - View extensions

extension View {
    /// Apply a translucent glass surface with a hairline border.
    /// Uses iOS 26 Liquid Glass with fallback to ultraThinMaterial on older iOS.
    @MainActor
    func asGlassCard(tint: Color? = nil, tintOpacity: CGFloat = 0.55, cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(GlassCardModifier(tint: tint ?? Theme.Colors.glassTint, tintOpacity: tintOpacity, cornerRadius: cornerRadius))
    }

    /// Apply an opaque pastel surface keyed to a Time category palette.
    func timeCard(_ palette: Theme.Colors.TimePalette) -> some View {
        modifier(TimeCardModifier(palette: palette))
    }

    /// Style as a full-width rose accent button.
    func asAccentButton() -> some View {
        modifier(AccentButtonModifier())
    }
}
