//
//  ColorExtensions.swift
//  xT
//
//  Hex and adaptive Color initializers used throughout the design system.
//

import SwiftUI

extension Color {
    /// Initialize a Color from a hex string (#RRGGBB, RRGGBB, or 8-digit AARRGGBB).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// A color that resolves differently in light vs. dark mode.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    /// Convenience: construct an adaptive color from two hex strings.
    init(lightHex: String, darkHex: String) {
        self.init(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }

    /// Linearly interpolates between two colors in RGB space.
    /// `t = 0` returns `from`, `t = 1` returns `to`. Values outside 0...1 are clamped.
    ///
    /// Used to drive the hormone-level color ramp (deeper rose → lighter lavender)
    /// on the home graph without needing a lookup table of discrete states.
    static func lerp(_ from: Color, _ to: Color, _ t: Double) -> Color {
        let clamped = min(max(t, 0), 1)
        let uFrom = UIColor(from)
        let uTo = UIColor(to)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uFrom.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uTo.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(
            red: Double(r1 + (r2 - r1) * CGFloat(clamped)),
            green: Double(g1 + (g2 - g1) * CGFloat(clamped)),
            blue: Double(b1 + (b2 - b1) * CGFloat(clamped)),
            opacity: Double(a1 + (a2 - a1) * CGFloat(clamped))
        )
    }
}
