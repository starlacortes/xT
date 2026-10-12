//
//  IsoclineTokenParityTests.swift
//  xTTests
//
//  Drift guard between the live theme engine and the canonical Isocline
//  tokens (docs/design/tokens/isocline.tokens.json). Web pages and Isocline
//  Research print use values resolved by tools/scripts/gen_isocline_tokens.py;
//  this pins that those values are still what `ThemePalette` produces at the
//  default seed. If it fails, either re-run the generator (the engine changed
//  on purpose) or fix the engine (it changed by accident).
//

import XCTest
import SwiftUI
import UIKit
@testable import xT

final class IsoclineTokenParityTests: XCTestCase {

    private func components(of color: Color, style: UIUserInterfaceStyle) -> (r: Double, g: Double, b: Double) {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func color(for field: String, in p: ThemePalette) -> Color? {
        switch field {
        case "appBackground": return p.appBackground
        case "cardSurface": return p.cardSurface
        case "safety": return p.safety
        case "textPrimary": return p.textPrimary
        case "accent": return p.accent
        case "accentSecondary": return p.accentSecondary
        case "levelLow": return p.levelLow
        case "levelHigh": return p.levelHigh
        default: return nil
        }
    }

    @MainActor
    func testDefaultSeedPaletteMatchesGeneratedTokens() {
        let p = ThemePalette.resolve(seedHue: ThemeManager.defaultSeedHue, increasedContrast: false)
        XCTAssertFalse(IsoclineTokenExpectations.palette.isEmpty)

        for expectation in IsoclineTokenExpectations.palette {
            guard let live = color(for: expectation.field, in: p) else {
                XCTFail("Token '\(expectation.field)' has no ThemePalette mapping — add it to color(for:in:)")
                continue
            }
            for (style, hex) in [(UIUserInterfaceStyle.light, expectation.light), (.dark, expectation.dark)] {
                let actual = components(of: live, style: style)
                let expected = components(of: Color(hex: hex), style: style)
                let label = "\(expectation.field) \(style == .light ? "light" : "dark")"
                XCTAssertEqual(actual.r, expected.r, accuracy: 0.01, "\(label) — red")
                XCTAssertEqual(actual.g, expected.g, accuracy: 0.01, "\(label) — green")
                XCTAssertEqual(actual.b, expected.b, accuracy: 0.01, "\(label) — blue")
            }
        }
    }

    // MARK: - Numeric tokens (X7)

    /// Resolves a generated Theme-constant path to its live value. Mirrors
    /// `color(for:in:)`: a newly added numeric token fails here until mapped.
    @MainActor
    private func numeric(_ path: String) -> CGFloat? {
        if path.hasPrefix("Theme.Seed.stops.") {
            let index = Int(path.dropFirst("Theme.Seed.stops.".count)) ?? -1
            guard (0..<Theme.Seed.stops.count).contains(index) else { return nil }
            return Theme.Seed.stops[index]
        }
        switch path {
        case "Theme.Radius.hairline": return Theme.Radius.hairline
        case "Theme.Radius.xs": return Theme.Radius.xs
        case "Theme.Radius.chip": return Theme.Radius.chip
        case "Theme.Radius.control": return Theme.Radius.control
        case "Theme.Radius.tile": return Theme.Radius.tile
        case "Theme.Radius.sm": return Theme.Radius.sm
        case "Theme.Radius.md": return Theme.Radius.md
        case "Theme.Radius.lg": return Theme.Radius.lg
        case "Theme.Radius.xl": return Theme.Radius.xl
        case "Theme.Radius.specimen": return Theme.Radius.specimen
        case "Theme.Spacing.xxs": return Theme.Spacing.xxs
        case "Theme.Spacing.xs": return Theme.Spacing.xs
        case "Theme.Spacing.s6": return Theme.Spacing.s6
        case "Theme.Spacing.tiny": return Theme.Spacing.tiny
        case "Theme.Spacing.sm": return Theme.Spacing.sm
        case "Theme.Spacing.s10": return Theme.Spacing.s10
        case "Theme.Spacing.row": return Theme.Spacing.row
        case "Theme.Spacing.md": return Theme.Spacing.md
        case "Theme.Spacing.card": return Theme.Spacing.card
        case "Theme.Spacing.lg": return Theme.Spacing.lg
        case "Theme.Spacing.xl": return Theme.Spacing.xl
        case "Theme.Spacing.xxl": return Theme.Spacing.xxl
        case "Theme.Spacing.s28": return Theme.Spacing.s28
        case "Theme.Spacing.section": return Theme.Spacing.section
        case "Theme.Spacing.xxxl": return Theme.Spacing.xxxl
        case "Theme.Spacing.jumbo": return Theme.Spacing.jumbo
        case "Theme.Spacing.gutter": return Theme.Spacing.gutter
        case "Theme.Spacing.Gutter.screen": return Theme.Spacing.Gutter.screen
        case "Theme.Line.hairline": return Theme.Line.hairline
        case "Theme.Line.engrave": return Theme.Line.engrave
        case "Theme.Line.curve": return Theme.Line.curve
        case "Theme.Line.curveHero": return Theme.Line.curveHero
        case "Theme.Line.labRing": return Theme.Line.labRing
        case "Theme.Curve.Fill.topOpacity": return Theme.Curve.Fill.topOpacity
        case "Theme.Curve.Fill.bottomOpacity": return Theme.Curve.Fill.bottomOpacity
        case "Theme.Curve.NowPoint.haloOpacity": return Theme.Curve.NowPoint.haloOpacity
        case "Theme.Curve.NowPoint.dotDiameter": return Theme.Curve.NowPoint.dotDiameter
        case "Theme.Curve.NowPoint.haloDiameter": return Theme.Curve.NowPoint.haloDiameter
        case "Theme.Curve.LabPoint.diameter": return Theme.Curve.LabPoint.diameter
        case "Theme.Curve.RangeBand.opacity": return Theme.Curve.RangeBand.opacity
        case "Theme.Curve.RangeBand.maxSpanRatio": return Theme.Curve.RangeBand.maxSpanRatio
        case "Theme.Curve.Glow.opacity": return Theme.Curve.Glow.opacity
        case "Theme.Curve.Glow.radius": return Theme.Curve.Glow.radius
        default: return nil
        }
    }

    /// X7: Theme's numeric constants read the generated `IsoclineTokens`, which
    /// the generator writes from the same JSON as the web and print outputs.
    /// This pins that neither was hand-edited away from the tokens.
    @MainActor
    func testNumericTokensMatchTheme() {
        XCTAssertFalse(IsoclineTokenExpectations.numeric.isEmpty)

        for expectation in IsoclineTokenExpectations.numeric {
            guard let live = numeric(expectation.theme) else {
                XCTFail("Token '\(expectation.theme)' has no Theme mapping — add it to numeric(_:)")
                continue
            }
            XCTAssertEqual(live, CGFloat(expectation.value), accuracy: 0.0001, expectation.theme)
        }
    }
}
