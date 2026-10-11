//
//  Theme+Isocline.swift
//  xT
//
//  Isocline "Paper & Instrument" — additive foundation tokens (Tier 1 · element F3).
//
//  Everything here is purely additive: new names that later elements read. Nothing
//  in this file changes an existing call site or an existing resolved color, so it
//  touches neither the look of the app nor `IsoclineTokenParityTests`. The palette
//  re-recipe (paper / card / ink / safety), the font switch, and the paper-ground
//  migration land separately.
//
//  Values mirror docs/design/tokens/isocline.tokens.json (line.* / radius.specimen /
//  spacing.* / curve.*). Edit the tokens first, regenerate, then reconcile here.
//

import SwiftUI

extension Theme {

    // MARK: Line weights (tokens: line.*)

    /// Stroke widths for hairlines, engraving, and the instrument curve. New in the
    /// Paper & Instrument system; depth on paper reads from a hairline, never a shadow.
    /// (The legacy `Theme.Colors.hairlineWidth` = 0.5 is migrated to `Line.hairline`
    /// per element F3; both exist during the transition.)
    enum Line {
        /// Paper-card borders and dividers.
        static let hairline: CGFloat  = 1
        /// Emboss / hairline-mark relief.
        static let engrave: CGFloat   = 0.75
        /// The Home curve stroke.
        static let curve: CGFloat     = 1.8
        /// Specimen / hero curve stroke.
        static let curveHero: CGFloat = 2.5
        /// Hollow measured-lab ring.
        static let labRing: CGFloat   = 1.3
    }

    // MARK: Curve (instrument) drawing constants (tokens: curve.*)

    /// Fixed geometry and alpha values for the Home curve. Colors are resolved from
    /// the palette at the use site (`levelTint`, `accent`, `ink`, `paper`); only the
    /// non-color drawing constants live here.
    enum Curve {
        enum Fill {
            static let topOpacity: CGFloat    = 0.3
            static let bottomOpacity: CGFloat = 0.0
        }
        enum NowPoint {
            static let haloOpacity: CGFloat = 0.15
            static let dotDiameter: CGFloat = 10
            static let haloDiameter: CGFloat = 26
        }
        enum LabPoint {
            /// Hollow ring; stroke width is `Theme.Line.labRing`.
            static let diameter: CGFloat = 9
        }
        enum RangeBand {
            static let opacity: CGFloat      = 0.05
            /// Cap on the band's y-span (the label still reads the true numbers).
            static let maxSpanRatio: CGFloat = 2.5
        }
        enum Glow {
            /// Night paper only, on the stroke; off under Reduce Transparency.
            static let opacity: CGFloat = 0.35
            static let radius: CGFloat  = 6
        }
    }
}

// MARK: - Radius (tokens: radius.specimen)

extension Theme.Radius {
    /// Appearance hue-specimen window (element S11).
    static let specimen: CGFloat = 28
}

// MARK: - Spacing (tokens: spacing.*)

extension Theme.Spacing {
    // Token-named aliases so a token read maps 1:1 to Swift. These equal the existing
    // (call-site-bearing) measured-histogram names rather than renaming them, so no
    // current caller breaks. The legacy names are retired call-site-by-call-site later.
    static let s6: CGFloat     = 6    // == tiny
    static let s10: CGFloat    = 10   // == row
    static let s28: CGFloat    = 28   // == section
    static let xxxl: CGFloat   = 32   // == jumbo
    static let gutter: CGFloat = 22   // == Gutter.screen
}
