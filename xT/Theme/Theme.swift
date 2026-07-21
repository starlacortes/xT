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
        }

        struct Time {
            static let mind = TimePalette(
                base:    Color(lightHex: "#534AB7", darkHex: "#7E74D8"),
                surface: Color(lightHex: "#EEEDFE", darkHex: "#1E1C3A"),
                border:  Color(lightHex: "#CECBF6", darkHex: "#3D3880")
            )
            static let skin = TimePalette(
                base:    Color(lightHex: "#0F6E56", darkHex: "#2DB88E"),
                surface: Color(lightHex: "#E1F5EE", darkHex: "#0C2420"),
                border:  Color(lightHex: "#9FE1CB", darkHex: "#1A5C46")
            )
            static let body = TimePalette(
                base:    Color(lightHex: "#854F0B", darkHex: "#D4862B"),
                surface: Color(lightHex: "#FAEEDA", darkHex: "#2E1C05"),
                border:  Color(lightHex: "#FAC775", darkHex: "#6B3D08")
            )
            static let cycle = TimePalette(
                base:    Color(lightHex: "#D4537E", darkHex: "#E8709A"),
                surface: Color(lightHex: "#FBEAF0", darkHex: "#2E1018"),
                border:  Color(lightHex: "#F4C0D1", darkHex: "#7A2846")
            )
        }
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
    }

    // MARK: Spacing

    struct Spacing {
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 20
        static let xxl: CGFloat  = 24
        static let card: CGFloat = 14  // dominant card content padding
    }

    // MARK: Radius

    struct Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
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
        /// Gentle spring for entrances and layout settling.
        static let entrance = Animation.spring(response: 0.55, dampingFraction: 0.82)
        /// Quick, lively spring for taps and toggles.
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.7)
        /// Smooth ease for value changes (counters, opacity, color).
        static let smooth = Animation.easeInOut(duration: 0.4)
        /// Per-card delay used to stagger a vertical stack on appear.
        static let stagger: Double = 0.07
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
}
