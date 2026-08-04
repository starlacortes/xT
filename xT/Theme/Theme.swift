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

    struct Colors {
        // Brand
        static let accent           = Color(lightHex: "#D4537E", darkHex: "#E8709A")
        static let accentSecondary  = Color(lightHex: "#534AB7", darkHex: "#7E74D8")

        // Text
        static let textPrimary      = Color.primary
        static let textSecondary    = Color.secondary
        static let textTertiary     = Color(uiColor: .tertiaryLabel)

        // Surfaces
        static let cardSurface      = Color(.systemBackground).opacity(0.8)
        static let glassSurface     = Color(.systemBackground).opacity(0.6)
        static let border           = Color.white.opacity(0.2)

        // Glass tint — deep purple-black in dark mode, subtle white in light mode
        static let glassTint        = Color(lightHex: "#F0ECF8", darkHex: "#0A0814")

        // Semantic
        static let success          = Color.green
        static let warning          = Color.orange
        static let error            = Color.red
        static let info             = Color.blue
        static let successBrand     = Color(lightHex: "#3B8C6E", darkHex: "#64DC9E")

        // Graph level ramp — deep rose (low) → light lavender (high)
        static let levelLow         = Color(lightHex: "#99345A", darkHex: "#C2557E")
        static let levelHigh        = Color(lightHex: "#8875D4", darkHex: "#B0A4EA")

        // Graph background — adaptive canvas rendering constants
        struct Graph {
            static let baseDark          = Color(lightHex: "#F2EDF8", darkHex: "#08060F")
            static let baseMid           = Color(lightHex: "#EBE2F4", darkHex: "#0F0B1C")
            static let baseTop           = Color(lightHex: "#E4D8F0", darkHex: "#1A0D1A")
            static let topGlow           = Color(lightHex: "#E898B2", darkHex: "#C0306A")
            static let rightGlow         = Color(lightHex: "#9B8FE0", darkHex: "#7060D0")
            static let gridLine          = Color(light: .black.opacity(0.05), dark: .white.opacity(0.035))
            static let yAxisLabel        = Color(light: .black.opacity(0.10), dark: .white.opacity(0.15))
            static let curveRose         = Color(lightHex: "#C0486E", darkHex: "#D4537E")
            static let curveMid          = Color(lightHex: "#9B50B8", darkHex: "#B060C0")
            static let curveLavender     = Color(lightHex: "#6B58C8", darkHex: "#8875D4")
            static let dotRose           = Color(lightHex: "#C0486E", darkHex: "#D4537E")
            static let dotMagenta        = Color(lightHex: "#A838A2", darkHex: "#B446B4")
            static let dotPurple         = Color(lightHex: "#8D40B8", darkHex: "#A050C8")
            static let dotDeepPurple     = Color(lightHex: "#7F48C4", darkHex: "#9458D4")
            static let dotLavenderLight  = Color(lightHex: "#6E48C0", darkHex: "#8C5CDA")

            // Level overlay text (adaptive)
            static let levelText         = Color(light: .black, dark: .white)
            static let levelTextSecondary = Color(light: .black.opacity(0.55), dark: .white.opacity(0.55))

            // Unfilled dot track color (adaptive)
            static let dotUnfilled       = Color(light: .black.opacity(0.08), dark: .white.opacity(0.12))
        }

        // MARK: Time category palettes

        struct TimePalette {
            let base: Color     // icon / progress fill
            let surface: Color  // card background
            let border: Color   // card stroke
            let text: Color     // on-surface text / emphasis, readable on `surface`
        }

        struct Time {
            static let mind = TimePalette(
                base:    Color(lightHex: "#534AB7", darkHex: "#7E74D8"),
                surface: Color(lightHex: "#EEEDFE", darkHex: "#1E1C3A"),
                border:  Color(lightHex: "#CECBF6", darkHex: "#3D3880"),
                text:    Color(lightHex: "#3C3489", darkHex: "#ABA7F0")
            )
            static let skin = TimePalette(
                base:    Color(lightHex: "#0F6E56", darkHex: "#2DB88E"),
                surface: Color(lightHex: "#E1F5EE", darkHex: "#0C2420"),
                border:  Color(lightHex: "#9FE1CB", darkHex: "#1A5C46"),
                text:    Color(lightHex: "#0A4F3E", darkHex: "#7FE0C4")
            )
            static let body = TimePalette(
                base:    Color(lightHex: "#854F0B", darkHex: "#D4862B"),
                surface: Color(lightHex: "#FAEEDA", darkHex: "#2E1C05"),
                border:  Color(lightHex: "#FAC775", darkHex: "#6B3D08"),
                text:    Color(lightHex: "#5C360A", darkHex: "#EFB25F")
            )
            static let cycle = TimePalette(
                base:    Color(lightHex: "#D4537E", darkHex: "#E8709A"),
                surface: Color(lightHex: "#FBEAF0", darkHex: "#2E1018"),
                border:  Color(lightHex: "#F4C0D1", darkHex: "#7A2846"),
                text:    Color(lightHex: "#993554", darkHex: "#F4A8C0")
            )
        }

        // MARK: On-accent

        /// Text and fills that sit on top of the brand gradient or an accent surface —
        /// the Onboarding flow and the app-lock screens. Replaces the raw
        /// `.white.opacity(_:)` literals that previously used six different alphas
        /// for the same semantic role.
        struct OnAccent {
            static let primary        = Color.white
            static let secondary      = Color.white.opacity(0.9)
            static let tertiary       = Color.white.opacity(0.7)
            static let disabled       = Color.white.opacity(0.5)
            static let fill           = Color.white.opacity(0.15)  // chip / control backgrounds
            static let stroke         = Color.white.opacity(0.3)   // chip borders
            static let strokeSelected = Color.white.opacity(0.5)
        }

        /// The de facto hairline stroke width used across the app (27 sites).
        static let hairlineWidth: CGFloat = 0.5
    }

    // MARK: Fonts

    struct Fonts {
        // Non-standard sizes
        static let display      = Font.system(size: 64, weight: .bold)
        static let largeNumber  = Font.system(size: 48, weight: .bold)
        static let micro        = Font.system(size: 10, weight: .regular)

        // Standard Dynamic Type scale
        static let largeTitle   = Font.largeTitle
        static let title        = Font.title
        static let title2       = Font.title2
        static let title3       = Font.title3
        static let headline     = Font.headline
        static let body         = Font.body
        static let callout      = Font.callout
        static let subheadline  = Font.subheadline
        static let footnote     = Font.footnote
        static let caption      = Font.caption
        static let caption2     = Font.caption2

        // Journal serif flourishes
        static let serifTitle   = Font.system(.title2, design: .serif)
        static let serifBody    = Font.system(.body, design: .serif)

        // MARK: Role tokens
        //
        // These name the fixed sizes that recur across the app. Each was derived from a
        // frequency count of raw `.system(size:)` literals — the number in the comment is
        // how many hand-written sites the token replaces.

        /// Uppercase section eyebrow — "TIME · BODY SYSTEMS", card captions. (23 sites)
        static let eyebrow    = Font.system(size: 11, weight: .semibold)
        /// Pill / chip label. (part of the 23 at size 11)
        static let pill       = Font.system(size: 11, weight: .medium)
        /// Row detail text and disclosure chevrons. (23 sites)
        static let detail     = Font.system(size: 13)
        /// Dense secondary label. (16 sites)
        static let label      = Font.system(size: 12)
        /// Caption under a floating stat. (10 sites)
        static let statLabel  = Font.system(size: 9, weight: .medium)
        /// Leading icon in a list row. (10 sites)
        static let icon       = Font.system(size: 18)
        /// Value of a floating stat. (MoodMind / BodyArchitecture overlays)
        static let statValue  = Font.system(size: 18, weight: .bold, design: .rounded)
        /// Detail-screen title. (3 sites)
        static let hero       = Font.system(size: 34, weight: .bold)
        /// Dose steppers and other editable numerics. (6 sites)
        static let numeric    = Font.system(size: 32, weight: .medium, design: .rounded)
        /// Large single-value readout — level overlay, journal streak. (2 sites)
        static let readout    = Font.system(size: 52, weight: .regular)
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

    struct Gradients {
        // Canonical brand colors — single source of truth for the rose→lavender sweep.
        static let brandColors: [Color] = [Color(hex: "#D4537E"), Color(hex: "#8875D4")]

        static let brand = LinearGradient(
            colors: brandColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    // MARK: Shadows

    /// Named elevation styles. Previously 16 hand-written `.shadow(...)` calls with no
    /// shared vocabulary, several of which were byte-identical across files.
    struct Shadows {
        struct Style {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        /// Neutral lift for a floating control over content.
        static let floating = Style(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        /// Accent-tinted glow under a primary floating action button.
        static let accentFab = Style(color: Colors.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        /// Soft tinted halo under a constellation node or body marker.
        static func nodeGlow(_ tint: Color, selected: Bool) -> Style {
            Style(color: tint.opacity(selected ? 0.5 : 0.25),
                  radius: selected ? 6 : 3, x: 0, y: 1)
        }
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
                .glassEffect(.regular.tint(tint.opacity(tintOpacity)).interactive(), in: .rect(cornerRadius: cornerRadius))
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
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }
}

// MARK: - View extensions

extension View {
    /// Apply a translucent glass surface with a hairline border.
    /// Uses iOS 26 Liquid Glass with fallback to ultraThinMaterial on older iOS.
    func asGlassCard(tint: Color = Theme.Colors.glassTint, tintOpacity: CGFloat = 0.55, cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        modifier(GlassCardModifier(tint: tint, tintOpacity: tintOpacity, cornerRadius: cornerRadius))
    }

    /// Apply an opaque pastel surface keyed to a Time category palette.
    func timeCard(_ palette: Theme.Colors.TimePalette) -> some View {
        modifier(TimeCardModifier(palette: palette))
    }

    /// Style as a full-width rose accent button.
    func asAccentButton() -> some View {
        modifier(AccentButtonModifier())
    }

    /// Apply a named elevation style from `Theme.Shadows`.
    func themeShadow(_ style: Theme.Shadows.Style) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
