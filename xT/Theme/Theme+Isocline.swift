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
//  Values read from the generated IsoclineTokens.swift (X7): edit
//  docs/design/tokens/isocline.tokens.json, run the generator, and Theme —
//  with the web and print outputs — moves together. The parity test pins it.
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
        static let hairline: CGFloat  = IsoclineTokens.Line.hairline
        /// Emboss / hairline-mark relief.
        static let engrave: CGFloat   = IsoclineTokens.Line.engrave
        /// The Home curve stroke.
        static let curve: CGFloat     = IsoclineTokens.Line.curve
        /// Specimen / hero curve stroke.
        static let curveHero: CGFloat = IsoclineTokens.Line.curveHero
        /// Hollow measured-lab ring.
        static let labRing: CGFloat   = IsoclineTokens.Line.labRing
    }

    // MARK: Curve (instrument) drawing constants (tokens: curve.*)

    /// Fixed geometry and alpha values for the Home curve. Colors are resolved from
    /// the palette at the use site (`levelTint`, `accent`, `ink`, `paper`); only the
    /// non-color drawing constants live here.
    enum Curve {
        enum Fill {
            static let topOpacity: CGFloat    = IsoclineTokens.Curve.Fill.topOpacity
            static let bottomOpacity: CGFloat = IsoclineTokens.Curve.Fill.bottomOpacity
        }
        enum NowPoint {
            static let haloOpacity: CGFloat = IsoclineTokens.Curve.NowPoint.haloOpacity
            static let dotDiameter: CGFloat = IsoclineTokens.Curve.NowPoint.dotDiameter
            static let haloDiameter: CGFloat = IsoclineTokens.Curve.NowPoint.haloDiameter
        }
        enum LabPoint {
            /// Hollow ring; stroke width is `Theme.Line.labRing`.
            static let diameter: CGFloat = IsoclineTokens.Curve.LabPoint.diameter
        }
        enum RangeBand {
            static let opacity: CGFloat      = IsoclineTokens.Curve.RangeBand.opacity
            /// Cap on the band's y-span (the label still reads the true numbers).
            static let maxSpanRatio: CGFloat = IsoclineTokens.Curve.RangeBand.maxSpanRatio
        }
        enum Glow {
            /// Night paper only, on the stroke; off under Reduce Transparency.
            static let opacity: CGFloat = IsoclineTokens.Curve.Glow.opacity
            static let radius: CGFloat  = IsoclineTokens.Curve.Glow.radius
        }
    }
}

// MARK: - Radius (tokens: radius.specimen)

extension Theme.Radius {
    /// Appearance hue-specimen window (element S11).
    static let specimen: CGFloat = IsoclineTokens.Radius.specimen
}

// MARK: - Spacing (tokens: spacing.*)

extension Theme.Spacing {
    // Token-named aliases so a token read maps 1:1 to Swift. These equal the existing
    // (call-site-bearing) measured-histogram names rather than renaming them, so no
    // current caller breaks. The legacy names are retired call-site-by-call-site later.
    static let s6: CGFloat     = IsoclineTokens.Spacing.s6    // == tiny
    static let s10: CGFloat    = IsoclineTokens.Spacing.s10   // == row
    static let s28: CGFloat    = IsoclineTokens.Spacing.s28   // == section
    static let xxxl: CGFloat   = IsoclineTokens.Spacing.xxxl // == jumbo
    static let gutter: CGFloat = IsoclineTokens.Spacing.gutter // == Gutter.screen
}
