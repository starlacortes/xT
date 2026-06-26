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

        // Semantic
        static let success          = Color.green
        static let warning          = Color.orange
        static let error            = Color.red
        static let info             = Color.blue

        // MARK: Bloom category palettes

        struct BloomPalette {
            let base: Color     // icon / progress fill
            let surface: Color  // card background
            let border: Color   // card stroke
        }

        struct Bloom {
            static let mind = BloomPalette(
                base:    Color(lightHex: "#534AB7", darkHex: "#7E74D8"),
                surface: Color(lightHex: "#EEEDFE", darkHex: "#1E1C3A"),
                border:  Color(lightHex: "#CECBF6", darkHex: "#3D3880")
            )
            static let skin = BloomPalette(
                base:    Color(lightHex: "#0F6E56", darkHex: "#2DB88E"),
                surface: Color(lightHex: "#E1F5EE", darkHex: "#0C2420"),
                border:  Color(lightHex: "#9FE1CB", darkHex: "#1A5C46")
            )
            static let body = BloomPalette(
                base:    Color(lightHex: "#854F0B", darkHex: "#D4862B"),
                surface: Color(lightHex: "#FAEEDA", darkHex: "#2E1C05"),
                border:  Color(lightHex: "#FAC775", darkHex: "#6B3D08")
            )
            static let cycle = BloomPalette(
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
struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.border, lineWidth: 0.5)
            )
    }
}

/// Opaque pastel card — for Bloom category cards and Journal mood cards.
struct BloomCardModifier: ViewModifier {
    let palette: Theme.Colors.BloomPalette

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
    func asGlassCard() -> some View {
        modifier(GlassCardModifier())
    }

    /// Apply an opaque pastel surface keyed to a Bloom category palette.
    func bloomCard(_ palette: Theme.Colors.BloomPalette) -> some View {
        modifier(BloomCardModifier(palette: palette))
    }

    /// Style as a full-width rose accent button.
    func asAccentButton() -> some View {
        modifier(AccentButtonModifier())
    }
}
